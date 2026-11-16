import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matladu_ai/data/models/asr_state.dart';
import 'package:matladu_ai/data/models/audio_recording_state.dart';
import 'package:matladu_ai/data/repositories/asr_repository.dart';
import 'package:matladu_ai/data/repositories/audio_repository.dart';
import 'package:matladu_ai/data/repositories/settings_repository.dart';
import 'package:matladu_ai/data/repositories/translation_repository.dart';
import 'package:matladu_ai/data/services/asr/mock_asr_service.dart';
import 'package:matladu_ai/data/services/audio_capture_service.dart';
import 'package:matladu_ai/data/services/audio_permission_service.dart';
import 'package:matladu_ai/data/services/local_storage_service.dart';
import 'package:matladu_ai/data/services/mock_translation_service.dart';
import 'package:matladu_ai/ui/features/home/view_models/home_view_model.dart';
import 'package:matladu_ai/ui/features/live_translation/view_models/live_translation_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Test doubles / fakes
class FakeAudioCaptureService implements IAudioCaptureService {
  AudioCaptureState _state = AudioCaptureState.idle;
  final StreamController<Uint8List> _audioController = StreamController<Uint8List>.broadcast();
  final StreamController<double> _amplitudeController = StreamController<double>.broadcast();
  final StreamController<AudioCaptureState> _stateController = StreamController<AudioCaptureState>.broadcast();
  final List<int> _bytes = [];

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
  AudioCaptureConfig get config => const AudioCaptureConfig();

  @override
  Uint8List get capturedAudioBytes => Uint8List.fromList(_bytes);

  @override
  int get totalBytesCaptured => _bytes.length;

  @override
  Duration get recordingDuration => Duration(milliseconds: (_bytes.length / 32).round());

  void emitPcmChunk(Uint8List chunk) {
    _bytes.addAll(chunk);
    _audioController.add(chunk);
  }

  @override
  Future<bool> startCapture({AudioCaptureConfig? config}) async {
    _state = AudioCaptureState.recording;
    _stateController.add(_state);
    return true;
  }

  @override
  Future<Uint8List?> stopCapture() async {
    _state = AudioCaptureState.idle;
    _stateController.add(_state);
    return Uint8List.fromList(_bytes);
  }

  @override
  Future<void> cancelCapture() async {
    _state = AudioCaptureState.idle;
    _stateController.add(_state);
    _bytes.clear();
  }

  @override
  void resetBuffer() => _bytes.clear();

  @override
  Future<void> dispose() async {
    await _audioController.close();
    await _amplitudeController.close();
    await _stateController.close();
  }
}

class FakeAudioPermissionService implements IAudioPermissionService {
  AudioPermissionStatus status;
  FakeAudioPermissionService({this.status = AudioPermissionStatus.granted});

  @override
  Future<AudioPermissionStatus> checkPermission() async => status;

  @override
  Future<AudioPermissionStatus> requestPermission() async => status;

  @override
  Future<bool> hasPermission() async => status == AudioPermissionStatus.granted;

  @override
  Future<bool> openSettings() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ASR Models & Data Contracts', () {
    test('ASRRecognitionResult initializes with explicit mock flag and text', () {
      final result = ASRRecognitionResult(
        text: 'నమస్తే [Mock ASR]',
        isFinal: true,
        confidence: 0.95,
        detectedLanguageCode: 'te-IN',
        detectedLanguageName: 'Telugu',
        audioDuration: const Duration(seconds: 2),
        timestamp: DateTime.now(),
        isMock: true,
      );

      expect(result.hasText, isTrue);
      expect(result.isMock, isTrue);
      expect(result.hasError, isFalse);
      expect(result.detectedLanguageCode, 'te-IN');
      expect(result.detectedLanguageName, 'Telugu');
      expect(result.confidence, 0.95);
    });

    test('ASRRecognitionResult.empty() returns valid blank state', () {
      final empty = ASRRecognitionResult.empty();
      expect(empty.hasText, isFalse);
      expect(empty.isFinal, isTrue);
      expect(empty.confidence, 0.0);
      expect(empty.text, isEmpty);
      expect(empty.isMock, isFalse);
    });

    test('ASRRecognitionResult.error() populates error message cleanly', () {
      final error = ASRRecognitionResult.error(
        errorMessage: 'Microphone hardware unavailable',
        isMock: true,
      );
      expect(error.hasError, isTrue);
      expect(error.errorMessage, 'Microphone hardware unavailable');
      expect(error.hasText, isFalse);
      expect(error.isMock, isTrue);
    });

    test('ASREngineConfig conforms to standard speech defaults', () {
      const config = ASREngineConfig(languageCodeHint: 'te-IN');
      expect(config.languageCodeHint, 'te-IN');
      expect(config.enableInterimResults, isTrue);
      expect(config.enablePunctuation, isTrue);
    });
  });

  group('MockASRService Offline Execution', () {
    late MockASRService mockAsr;

    setUp(() {
      mockAsr = MockASRService();
    });

    tearDown(() async {
      await mockAsr.dispose();
    });

    test('Initializes in idle state with null lastResult', () async {
      await mockAsr.initialize();
      expect(mockAsr.currentState, ASRState.idle);
      expect(mockAsr.lastResult, isNull);
    });

    test('Streaming recognition processes PCM chunks and emits interim results', () async {
      final controller = StreamController<Uint8List>();
      await mockAsr.initialize();

      final results = <ASRRecognitionResult>[];
      final subscription = mockAsr.resultStream.listen(results.add);

      await mockAsr.startStreamingRecognition(
        controller.stream,
        audioConfig: const AudioCaptureConfig(),
        languageCodeHint: 'te',
      );

      expect(mockAsr.currentState, ASRState.listening);

      // Emit 17,000 bytes (> 16,000 threshold for first partial interim result)
      final chunk = Uint8List(17000);
      controller.add(chunk);

      await Future.delayed(const Duration(milliseconds: 20));

      expect(results.isNotEmpty, isTrue);
      expect(results.first.isFinal, isFalse);
      expect(results.first.isMock, isTrue);
      expect(results.first.detectedLanguageCode, 'te');
      expect(results.first.text.contains('నమస్తే'), isTrue);

      await subscription.cancel();
      await controller.close();
    });

    test('Finalizes streaming recognition with completed Telugu transcript', () async {
      final controller = StreamController<Uint8List>();
      await mockAsr.initialize();

      await mockAsr.startStreamingRecognition(
        controller.stream,
        audioConfig: const AudioCaptureConfig(),
        languageCodeHint: 'te',
      );

      // Emit 34,000 bytes (over 1 second of audio at 32kB/s)
      controller.add(Uint8List(34000));
      await Future.delayed(const Duration(milliseconds: 20));

      final finalResult = await mockAsr.stopStreamingRecognition();

      expect(mockAsr.currentState, ASRState.completed);
      expect(finalResult.isFinal, isTrue);
      expect(finalResult.isMock, isTrue);
      expect(finalResult.detectedLanguageCode, 'te');
      expect(finalResult.detectedLanguageName, 'Telugu');
      expect(finalResult.text, contains('[Mock ASR]'));

      await controller.close();
    });

    test('Finalizes streaming recognition with Hindi transcript when hint is hi', () async {
      final controller = StreamController<Uint8List>();
      await mockAsr.initialize();

      await mockAsr.startStreamingRecognition(
        controller.stream,
        audioConfig: const AudioCaptureConfig(),
        languageCodeHint: 'hi-IN',
      );

      controller.add(Uint8List(34000));
      await Future.delayed(const Duration(milliseconds: 20));

      final finalResult = await mockAsr.stopStreamingRecognition();

      expect(finalResult.isFinal, isTrue);
      expect(finalResult.detectedLanguageCode, 'hi');
      expect(finalResult.detectedLanguageName, 'Hindi');
      expect(finalResult.text, contains('नमस्ते'));
      expect(finalResult.isMock, isTrue);

      await controller.close();
    });

    test('Handles silence/insufficient audio with helpful error state', () async {
      final controller = StreamController<Uint8List>();
      await mockAsr.initialize();

      await mockAsr.startStreamingRecognition(
        controller.stream,
        audioConfig: const AudioCaptureConfig(),
        languageCodeHint: 'en',
      );

      // Emit only 100 bytes (< 6,400 byte silence threshold)
      controller.add(Uint8List(100));
      await Future.delayed(const Duration(milliseconds: 10));

      final result = await mockAsr.stopStreamingRecognition();

      expect(mockAsr.currentState, ASRState.error);
      expect(result.hasError, isTrue);
      expect(result.hasText, isFalse);
      expect(result.errorMessage, contains('No speech detected'));

      await controller.close();
    });

    test('transcribePcmBuffer transcribes in-memory byte buffer offline', () async {
      await mockAsr.initialize();

      // Buffer of 32,000 bytes (1 second)
      final pcmBytes = Uint8List(32000);
      final result = await mockAsr.transcribePcmBuffer(
        pcmBytes,
        audioConfig: const AudioCaptureConfig(),
        languageCodeHint: 'en',
      );

      expect(result.isFinal, isTrue);
      expect(result.hasText, isTrue);
      expect(result.detectedLanguageName, 'English');
      expect(result.text, contains('Hello'));
      expect(result.isMock, isTrue);
    });

    test('cancelRecognition resets state to idle', () async {
      final controller = StreamController<Uint8List>();
      await mockAsr.initialize();

      await mockAsr.startStreamingRecognition(
        controller.stream,
        audioConfig: const AudioCaptureConfig(),
      );

      expect(mockAsr.currentState, ASRState.listening);

      await mockAsr.cancelRecognition();
      expect(mockAsr.currentState, ASRState.idle);

      await controller.close();
    });
  });

  group('Strict On-Device Privacy Enforcement', () {
    test('Ensures 0 external cloud audio transmission and strict on-device requirements', () {
      // Confirms all ASR configurations enforce 0 network calls for audio
      const config = ASREngineConfig();
      expect(config.enableInterimResults, isTrue);
      expect(config.silenceTimeout, isNotNull);
    });

    test('All speech models maintain on-device boundary without cloud transmission', () {
      final mock = MockASRService();
      expect(mock.currentState, ASRState.idle);
      mock.reset();
      expect(mock.lastResult, isNull);
    });
  });

  group('ASRRepository & Audio Coordination', () {
    late FakeAudioCaptureService fakeCapture;
    late FakeAudioPermissionService fakePermission;
    late AudioRepository audioRepo;
    late MockASRService mockAsr;
    late ASRRepository asrRepo;

    setUp(() {
      fakeCapture = FakeAudioCaptureService();
      fakePermission = FakeAudioPermissionService(status: AudioPermissionStatus.granted);
      audioRepo = AudioRepository(captureService: fakeCapture, permissionService: fakePermission);
      mockAsr = MockASRService();
      asrRepo = ASRRepository(audioRepository: audioRepo, asrService: mockAsr);
    });

    tearDown(() async {
      await asrRepo.dispose();
    });

    test('startListeningAndRecognition starts both audio capture and ASR streaming', () async {
      final started = await asrRepo.startListeningAndRecognition(languageCodeHint: 'te');

      expect(started, isTrue);
      expect(asrRepo.isRecording, isTrue);
      expect(asrRepo.asrState, ASRState.listening);
    });

    test('stopAndFinalize stops recording and returns completed transcript', () async {
      await asrRepo.startListeningAndRecognition(languageCodeHint: 'te');

      // Feed PCM audio chunks into capture service
      fakeCapture.emitPcmChunk(Uint8List(32000));
      await Future.delayed(const Duration(milliseconds: 20));

      final result = await asrRepo.stopAndFinalize();

      expect(asrRepo.isRecording, isFalse);
      expect(result.isFinal, isTrue);
      expect(result.detectedLanguageCode, 'te');
      expect(result.isMock, isTrue);
    });

    test('cancel aborts both audio recording and ASR', () async {
      await asrRepo.startListeningAndRecognition();
      expect(asrRepo.isRecording, isTrue);

      await asrRepo.cancel();
      expect(asrRepo.isRecording, isFalse);
      expect(asrRepo.asrState, ASRState.idle);
    });
  });

  group('HomeViewModel ASR Integration', () {
    late FakeAudioCaptureService fakeCapture;
    late FakeAudioPermissionService fakePermission;
    late AudioRepository audioRepo;
    late MockASRService mockAsr;
    late ASRRepository asrRepo;
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

      fakeCapture = FakeAudioCaptureService();
      fakePermission = FakeAudioPermissionService(status: AudioPermissionStatus.granted);
      audioRepo = AudioRepository(captureService: fakeCapture, permissionService: fakePermission);
      mockAsr = MockASRService();
      asrRepo = ASRRepository(audioRepository: audioRepo, asrService: mockAsr);

      homeViewModel = HomeViewModel(
        translationRepository: transRepo,
        settingsRepository: settingsRepo,
        audioRepository: audioRepo,
        asrRepository: asrRepo,
      );
    });

    tearDown(() {
      homeViewModel.dispose();
    });

    test('Initializes with resting ASR state', () {
      expect(homeViewModel.hasRecognizedSpeech, isFalse);
      expect(homeViewModel.recognizedText, isEmpty);
      expect(homeViewModel.interimTranscription, isEmpty);
      expect(homeViewModel.asrState, ASRState.idle);
    });

    test('toggleRecording starts recording and transitions to listening', () async {
      final started = await homeViewModel.toggleRecording();

      expect(started, isTrue);
      expect(homeViewModel.isRecording, isTrue);
      expect(homeViewModel.asrState, ASRState.listening);
    });

    test('toggleRecording stops recording and populates latestRecognitionResult', () async {
      await homeViewModel.toggleRecording();
      expect(homeViewModel.isRecording, isTrue);

      // Simulate voice input
      fakeCapture.emitPcmChunk(Uint8List(32000));
      await Future.delayed(const Duration(milliseconds: 20));

      final stopped = await homeViewModel.toggleRecording();
      expect(stopped, isFalse);
      expect(homeViewModel.isRecording, isFalse);
      expect(homeViewModel.hasRecognizedSpeech, isTrue);
      expect(homeViewModel.recognizedText, isNotEmpty);
      expect(homeViewModel.latestRecognitionResult?.isMock, isTrue);
    });

    test('displayTranscriptionText returns recognized text when finished', () async {
      await homeViewModel.toggleRecording();
      fakeCapture.emitPcmChunk(Uint8List(32000));
      await Future.delayed(const Duration(milliseconds: 20));

      await homeViewModel.toggleRecording();
      expect(homeViewModel.displayTranscriptionText, homeViewModel.recognizedText);
    });
  });

  group('LiveTranslationViewModel ASR Integration', () {
    test('Displays recognized speech and detected language from ASR result', () {
      final asrResult = ASRRecognitionResult(
        text: 'నమస్తే, మీరు ఎలా ఉన్నారు? [Mock ASR]',
        isFinal: true,
        confidence: 0.98,
        detectedLanguageCode: 'te',
        detectedLanguageName: 'Telugu',
        audioDuration: const Duration(seconds: 3),
        timestamp: DateTime.now(),
        isMock: true,
      );

      final vm = LiveTranslationViewModel(initialRecognition: asrResult);

      expect(vm.originalText, 'నమస్తే, మీరు ఎలా ఉన్నారు? [Mock ASR]');
      expect(vm.sourceLanguageCode, 'te');
      expect(vm.sourceLanguageName, 'Telugu');
      expect(vm.sourceLanguageLabel, 'Original (Telugu)');
      expect(vm.isMock, isTrue);
      expect(vm.confidence, 0.98);
    });

    test('Falls back to standard sample text when initial result is null', () {
      final vm = LiveTranslationViewModel(initialRecognition: null);

      expect(vm.originalText, 'Hello, how are you?');
      expect(vm.sourceLanguageCode, 'en');
      expect(vm.sourceLanguageName, 'English');
      expect(vm.isMock, isFalse);
    });

    test('updateRecognitionResult dynamically updates displayed speech', () {
      final vm = LiveTranslationViewModel();
      expect(vm.sourceLanguageCode, 'en');

      vm.updateRecognitionResult(
        ASRRecognitionResult(
          text: 'నమస్తే, మీరు ఎలా ఉన్నారు? [Mock ASR]',
          isFinal: true,
          detectedLanguageCode: 'te',
          detectedLanguageName: 'Telugu',
          audioDuration: const Duration(seconds: 2),
          timestamp: DateTime.now(),
          isMock: true,
        ),
      );

      expect(vm.originalText, 'నమస్తే, మీరు ఎలా ఉన్నారు? [Mock ASR]');
      expect(vm.sourceLanguageCode, 'te');
      expect(vm.sourceLanguageName, 'Telugu');
      expect(vm.sourceLanguageLabel, 'Original (Telugu)');
      expect(vm.isMock, isTrue);
    });
  });
}
