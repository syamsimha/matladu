import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:matladu_ai/data/models/audio_recording_state.dart';
import 'package:matladu_ai/data/repositories/audio_repository.dart';
import 'package:matladu_ai/data/repositories/settings_repository.dart';
import 'package:matladu_ai/data/repositories/translation_repository.dart';
import 'package:matladu_ai/data/services/audio_capture_service.dart';
import 'package:matladu_ai/data/services/audio_permission_service.dart';
import 'package:matladu_ai/data/services/local_storage_service.dart';
import 'package:matladu_ai/data/services/mock_translation_service.dart';
import 'package:matladu_ai/ui/features/home/view_models/home_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test double for IAudioPermissionService.
class FakeAudioPermissionService implements IAudioPermissionService {
  AudioPermissionStatus currentStatus;
  bool openSettingsCalled = false;

  FakeAudioPermissionService({this.currentStatus = AudioPermissionStatus.granted});

  @override
  Future<AudioPermissionStatus> checkPermission() async => currentStatus;

  @override
  Future<AudioPermissionStatus> requestPermission() async => currentStatus;

  @override
  Future<bool> hasPermission() async => currentStatus == AudioPermissionStatus.granted;

  @override
  Future<bool> openSettings() async {
    openSettingsCalled = true;
    return true;
  }
}

/// Test double for IAudioCaptureService.
class FakeAudioCaptureService implements IAudioCaptureService {
  AudioCaptureState _state = AudioCaptureState.idle;
  AudioCaptureConfig _config = const AudioCaptureConfig();
  final BytesBuilder _buffer = BytesBuilder();
  DateTime? _startTime;

  final StreamController<Uint8List> _audioController = StreamController<Uint8List>.broadcast();
  final StreamController<double> _amplitudeController = StreamController<double>.broadcast();
  final StreamController<AudioCaptureState> _stateController = StreamController<AudioCaptureState>.broadcast();

  bool simulateErrorOnStart = false;

  @override
  Stream<Uint8List> get audioStream => _audioController.stream;

  @override
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  @override
  Stream<AudioCaptureState> get stateStream => _stateController.stream;

  @override
  AudioCaptureState get currentState => _state;

  @override
  bool get isRecording => _state == AudioCaptureState.recording;

  @override
  AudioCaptureConfig get config => _config;

  @override
  Uint8List get capturedAudioBytes => _buffer.toBytes();

  @override
  int get totalBytesCaptured => _buffer.length;

  @override
  Duration get recordingDuration => _startTime != null
      ? DateTime.now().difference(_startTime!)
      : Duration.zero;

  void emitChunk(Uint8List chunk, {double level = 0.5}) {
    if (_state != AudioCaptureState.recording) return;
    _buffer.add(chunk);
    _audioController.add(chunk);
    _amplitudeController.add(level);
  }

  void emitError(Object error) {
    _state = AudioCaptureState.error;
    _stateController.add(_state);
  }

  @override
  Future<bool> startCapture({AudioCaptureConfig? config}) async {
    if (_state != AudioCaptureState.idle && _state != AudioCaptureState.error) {
      return false; // Prevent duplicate start
    }

    if (simulateErrorOnStart) {
      _state = AudioCaptureState.error;
      _stateController.add(_state);
      return false;
    }

    _config = config ?? const AudioCaptureConfig();
    _buffer.clear();
    _startTime = DateTime.now();
    _state = AudioCaptureState.recording;
    _stateController.add(_state);
    return true;
  }

  @override
  Future<Uint8List?> stopCapture() async {
    if (_state != AudioCaptureState.recording) {
      return _buffer.length > 0 ? _buffer.toBytes() : null;
    }
    _state = AudioCaptureState.idle;
    _stateController.add(_state);
    _amplitudeController.add(0.0);
    return _buffer.toBytes();
  }

  @override
  Future<void> cancelCapture() async {
    _buffer.clear();
    _startTime = null;
    _state = AudioCaptureState.idle;
    _stateController.add(_state);
    _amplitudeController.add(0.0);
  }

  @override
  void resetBuffer() {
    _buffer.clear();
  }

  @override
  Future<void> dispose() async {
    await _audioController.close();
    await _amplitudeController.close();
    await _stateController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioPermissionService fakePermissionService;
  late FakeAudioCaptureService fakeCaptureService;
  late AudioRepository audioRepository;
  late SettingsRepository settingsRepo;
  late TranslationRepository transRepo;
  late HomeViewModel homeViewModel;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    final mockService = MockTranslationService();

    settingsRepo = SettingsRepository(storageService: storage);
    transRepo = TranslationRepository(
      translationService: mockService,
      storageService: storage,
    );

    fakePermissionService = FakeAudioPermissionService();
    fakeCaptureService = FakeAudioCaptureService();
    audioRepository = AudioRepository(
      captureService: fakeCaptureService,
      permissionService: fakePermissionService,
    );

    homeViewModel = HomeViewModel(
      translationRepository: transRepo,
      settingsRepository: settingsRepo,
      audioRepository: audioRepository,
    );
  });

  group('AudioCaptureConfig & Model Tests', () {
    test('Default AudioCaptureConfig conforms to 16 kHz Mono 16-bit PCM', () {
      const config = AudioCaptureConfig();
      expect(config.sampleRate, 16000);
      expect(config.numChannels, 1);
      expect(config.bitDepth, 16);
      expect(config.bytesPerSecond, 32000);
      expect(config.autoGain, isTrue);
      // AEC and Noise Suppression disabled by default so ASR speech phonemes are not attenuated
      expect(config.echoCancellation, isFalse);
      expect(config.noiseSuppression, isFalse);
    });

    test('AudioChunk duration computes accurately from PCM byte length', () {
      final chunkBytes = Uint8List(3200); // 3200 bytes / 32 bytes per ms = 100 ms
      final chunk = AudioChunk(
        bytes: chunkBytes,
        timestamp: DateTime.now(),
        normalizedLevel: 0.65,
        decibels: -12.4,
      );
      expect(chunk.duration.inMilliseconds, 100);
      expect(chunk.normalizedLevel, 0.65);
    });
  });

  group('Microphone Service & Duplicate Start Prevention', () {
    test('Initializes in idle state with empty buffer', () {
      expect(fakeCaptureService.currentState, AudioCaptureState.idle);
      expect(fakeCaptureService.isRecording, isFalse);
      expect(fakeCaptureService.totalBytesCaptured, 0);
    });

    test('startCapture transitions to recording and records audio chunks', () async {
      final started = await fakeCaptureService.startCapture();
      expect(started, isTrue);
      expect(fakeCaptureService.currentState, AudioCaptureState.recording);
      expect(fakeCaptureService.isRecording, isTrue);

      // Emit simulated 16-bit PCM chunk
      final chunk = Uint8List.fromList([0, 10, 0, 20, 0, 30, 0, 40]);
      fakeCaptureService.emitChunk(chunk, level: 0.42);

      expect(fakeCaptureService.totalBytesCaptured, 8);
      expect(fakeCaptureService.capturedAudioBytes.length, 8);
    });

    test('Duplicate startCapture calls while already recording are safely rejected', () async {
      final firstStart = await fakeCaptureService.startCapture();
      expect(firstStart, isTrue);
      expect(fakeCaptureService.isRecording, isTrue);

      // Attempt second start while still recording
      final duplicateStart = await fakeCaptureService.startCapture();
      expect(duplicateStart, isFalse);
      expect(fakeCaptureService.isRecording, isTrue);
    });

    test('stopCapture stops recording and returns captured byte buffer', () async {
      await fakeCaptureService.startCapture();
      fakeCaptureService.emitChunk(Uint8List.fromList([1, 2, 3, 4]));

      final result = await fakeCaptureService.stopCapture();
      expect(result, isNotNull);
      expect(result!.length, 4);
      expect(fakeCaptureService.isRecording, isFalse);
      expect(fakeCaptureService.currentState, AudioCaptureState.idle);
    });

    test('cancelCapture clears buffer and resets state to idle', () async {
      await fakeCaptureService.startCapture();
      fakeCaptureService.emitChunk(Uint8List.fromList([1, 2, 3, 4, 5, 6]));

      await fakeCaptureService.cancelCapture();
      expect(fakeCaptureService.isRecording, isFalse);
      expect(fakeCaptureService.totalBytesCaptured, 0);
      expect(fakeCaptureService.currentState, AudioCaptureState.idle);
    });

    test('Handles capture start errors cleanly without crashing', () async {
      fakeCaptureService.simulateErrorOnStart = true;
      final started = await fakeCaptureService.startCapture();
      expect(started, isFalse);
      expect(fakeCaptureService.currentState, AudioCaptureState.error);
    });
  });

  group('AudioRepository & Permission Enforcement', () {
    test('Refuses to start recording when permission is denied', () async {
      fakePermissionService.currentStatus = AudioPermissionStatus.denied;

      final success = await audioRepository.startRecording();
      expect(success, isFalse);
      expect(audioRepository.isRecording, isFalse);
      expect(audioRepository.state, AudioCaptureState.idle);
    });

    test('Starts recording when permission is granted', () async {
      fakePermissionService.currentStatus = AudioPermissionStatus.granted;

      final success = await audioRepository.startRecording();
      expect(success, isTrue);
      expect(audioRepository.isRecording, isTrue);
      expect(audioRepository.state, AudioCaptureState.recording);
    });

    test('openAppSettings delegates to permission service', () async {
      final opened = await audioRepository.openAppSettings();
      expect(opened, isTrue);
      expect(fakePermissionService.openSettingsCalled, isTrue);
    });
  });

  group('HomeViewModel Real Microphone Audio Integration', () {
    test('Initializes with resting microphone state', () {
      expect(homeViewModel.isRecording, isFalse);
      expect(homeViewModel.currentAudioLevel, 0.0);
      expect(homeViewModel.recordingDuration, Duration.zero);
      expect(homeViewModel.audioErrorMessage, isNull);
    });

    test('toggleRecording starts recording when permission is granted', () async {
      fakePermissionService.currentStatus = AudioPermissionStatus.granted;

      final started = await homeViewModel.toggleRecording();
      expect(started, isTrue);
      expect(homeViewModel.isRecording, isTrue);

      // Simulate live incoming microphone audio chunk
      final samplePcm = Uint8List(64);
      fakeCaptureService.emitChunk(samplePcm, level: 0.78);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(homeViewModel.currentAudioLevel, 0.78);

      // Toggle again to stop recording
      final secondToggle = await homeViewModel.toggleRecording();
      expect(secondToggle, isFalse);
      expect(homeViewModel.isRecording, isFalse);
      expect(homeViewModel.currentAudioLevel, 0.0);
    });

    test('toggleRecording triggers onPermanentlyDenied when permission is permanently denied', () async {
      fakePermissionService.currentStatus = AudioPermissionStatus.permanentlyDenied;

      bool permanentlyDeniedCalled = false;
      final started = await homeViewModel.toggleRecording(
        onPermanentlyDenied: () => permanentlyDeniedCalled = true,
      );

      expect(started, isFalse);
      expect(permanentlyDeniedCalled, isTrue);
      expect(homeViewModel.isRecording, isFalse);
      expect(homeViewModel.audioErrorMessage, isNotNull);
    });

    test('toggleRecording triggers onPermissionDenied when permission is denied', () async {
      fakePermissionService.currentStatus = AudioPermissionStatus.denied;

      bool deniedCalled = false;
      final started = await homeViewModel.toggleRecording(
        onPermissionDenied: () => deniedCalled = true,
      );

      expect(started, isFalse);
      expect(deniedCalled, isTrue);
      expect(homeViewModel.isRecording, isFalse);
    });

    test('handleAppPaused stops active recording when app is backgrounded', () async {
      fakePermissionService.currentStatus = AudioPermissionStatus.granted;

      await homeViewModel.toggleRecording();
      expect(homeViewModel.isRecording, isTrue);

      // App is paused / minimized
      homeViewModel.handleAppPaused();
      expect(homeViewModel.isRecording, isFalse);
      expect(homeViewModel.currentAudioLevel, 0.0);
    });
  });
}
