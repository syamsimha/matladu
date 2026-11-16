import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matladu_ai/core/theme/app_theme.dart';
import 'package:matladu_ai/data/models/audio_recording_state.dart';
import 'package:matladu_ai/data/models/connection_mode_model.dart';
import 'package:matladu_ai/data/models/language_model.dart';
import 'package:matladu_ai/data/models/translation_result.dart';
import 'package:matladu_ai/data/models/tts_result.dart';
import 'package:matladu_ai/data/models/tts_voice.dart';
import 'package:matladu_ai/data/repositories/asr_repository.dart';
import 'package:matladu_ai/data/repositories/audio_repository.dart';
import 'package:matladu_ai/data/repositories/settings_repository.dart';
import 'package:matladu_ai/data/repositories/translation_repository.dart';
import 'package:matladu_ai/data/repositories/tts_repository.dart';
import 'package:matladu_ai/data/services/asr/mock_asr_service.dart';
import 'package:matladu_ai/data/services/audio_capture_service.dart';
import 'package:matladu_ai/data/services/audio_permission_service.dart';
import 'package:matladu_ai/data/services/local_storage_service.dart';
import 'package:matladu_ai/data/services/translation/i_translation_service.dart';
import 'package:matladu_ai/data/services/tts/i_tts_service.dart';
import 'package:matladu_ai/ui/features/home/view_models/home_view_model.dart';
import 'package:matladu_ai/ui/features/live_translation/view_models/live_translation_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTranslationService implements ITranslationService {
  String? lastSourceCode;
  String? lastTargetCode;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> isModelDownloaded(String languageCode) async => true;

  @override
  Future<bool> downloadModel(String languageCode, {void Function(double progress)? onProgress}) async => true;

  @override
  Future<bool> deleteModel(String languageCode) async => true;

  @override
  Future<TranslationResult> translate({
    required String text,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) async {
    lastSourceCode = sourceLanguageCode;
    lastTargetCode = targetLanguageCode;
    final translated = (sourceLanguageCode == 'en' && targetLanguageCode == 'te')
        ? 'నమస్తే, మీరు ఎలా ఉన్నారు?'
        : 'Hello, how are you?';

    return TranslationResult(
      originalText: text,
      translatedText: translated,
      sourceLanguageCode: sourceLanguageCode,
      targetLanguageCode: targetLanguageCode,
      status: TranslationStatus.completed,
      timestamp: DateTime.now(),
      isMock: false,
    );
  }

  @override
  bool isLanguageSupported(String languageCode) => true;

  @override
  bool isPairSupported(String sourceCode, String targetCode) => true;

  @override
  Stream<TranslationResult> get resultStream => const Stream.empty();

  @override
  Future<void> dispose() async {}
}

class _FakeTtsService implements ITtsService {
  final StreamController<TtsResult> _controller = StreamController<TtsResult>.broadcast();
  TtsPlaybackState _state = TtsPlaybackState.idle;
  String? _currentRequestId;
  String? lastSpokenText;
  String? lastSpokenLangCode;

  final List<TtsVoice> offlineVoices = const [
    TtsVoice(
      name: 'en-us-local',
      locale: 'en-US',
      languageCode: 'en',
      isNetworkRequired: false,
      quality: 400,
    ),
    TtsVoice(
      name: 'te-in-local',
      locale: 'te-IN',
      languageCode: 'te',
      isNetworkRequired: false,
      quality: 400,
    ),
  ];

  @override
  Stream<TtsResult> get stateStream => _controller.stream;

  @override
  TtsPlaybackState get currentState => _state;

  @override
  String? get currentRequestId => _currentRequestId;

  @override
  Future<void> initialize() async {}

  @override
  Future<List<TtsVoice>> getAvailableVoices() async => offlineVoices;

  @override
  Future<List<TtsVoice>> getOfflineVoices() async => offlineVoices;

  @override
  Future<bool> isLanguageSupported(String languageCode) async => true;

  @override
  Future<bool> isOfflineVoiceAvailable(String languageCode) async => true;

  @override
  Future<TtsVoice?> getBestOfflineVoice(String languageCode) async {
    try {
      return offlineVoices.firstWhere((v) => v.languageCode == languageCode);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> speak({
    required String text,
    required String languageCode,
    String? voiceName,
    String? requestId,
  }) async {
    lastSpokenText = text;
    lastSpokenLangCode = languageCode;
    _currentRequestId = requestId;
    _state = TtsPlaybackState.speaking;
    _controller.add(TtsResult(
      requestId: requestId ?? '',
      state: TtsPlaybackState.speaking,
      text: text,
      languageCode: languageCode,
    ));
    return true;
  }

  @override
  Future<bool> stop() async {
    _state = TtsPlaybackState.stopped;
    return true;
  }

  @override
  Future<bool> pause() async => true;

  @override
  Future<bool> resume() async => true;

  @override
  Future<void> setSpeechRate(double rate) async {}

  @override
  Future<void> setPitch(double pitch) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<String?> getDefaultEngine() async => 'mock';

  @override
  Future<List<String>> getEngines() async => ['mock'];

  @override
  Future<bool> openTtsSettings() async => true;

  @override
  Future<bool> openInstallTtsData() async => true;

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

class _FakeAudioCaptureService implements IAudioCaptureService {
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
    return Uint8List.fromList(_bytes.isEmpty ? List.filled(3200, 100) : _bytes);
  }

  @override
  Future<void> cancelCapture() async {
    _state = AudioCaptureState.idle;
    _stateController.add(_state);
  }

  @override
  void resetBuffer() {
    _bytes.clear();
  }

  @override
  Future<void> dispose() async {
    await _audioController.close();
    await _amplitudeController.close();
    await _stateController.close();
  }
}

class _FakeAudioPermissionService extends AudioPermissionService {
  const _FakeAudioPermissionService();

  @override
  Future<AudioPermissionStatus> checkPermission() async => AudioPermissionStatus.granted;

  @override
  Future<AudioPermissionStatus> requestPermission() async => AudioPermissionStatus.granted;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Matladu Root-Cause Audit and Stabilization Tests', () {
    late LocalStorageService storageService;
    late SettingsRepository settingsRepo;
    late TranslationRepository translationRepo;
    late _FakeTranslationService translationService;
    late AudioRepository audioRepo;
    late _FakeTtsService ttsService;
    late TtsRepository ttsRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storageService = LocalStorageService(prefs);
      settingsRepo = SettingsRepository(storageService: storageService);

      translationService = _FakeTranslationService();
      translationRepo = TranslationRepository(
        translationService: translationService,
        storageService: storageService,
      );

      final audioCapture = _FakeAudioCaptureService();
      const audioPermission = _FakeAudioPermissionService();
      audioRepo = AudioRepository(
        captureService: audioCapture,
        permissionService: audioPermission,
      );

      ttsService = _FakeTtsService();
      ttsRepo = TtsRepository(
        ttsService: ttsService,
        storageService: storageService,
      );
      await ttsRepo.initialize();
    });

    test('1. Shared Session Controller: startSessionFromHome begins listening cleanly', () async {
      final asrRepo = ASRRepository(
        audioRepository: audioRepo,
        asrService: MockASRService(),
      );

      final liveVm = LiveTranslationViewModel(
        translationRepository: translationRepo,
        ttsRepository: ttsRepo,
        asrRepository: asrRepo,
        settingsRepository: settingsRepo,
      );

      const source = LanguageModel(code: 'en', name: 'English', nativeName: 'English');
      const target = LanguageModel(code: 'te', name: 'Telugu', nativeName: 'తెలుగు');

      final success = await liveVm.startSessionFromHome(
        sourceLanguage: source,
        targetLanguage: target,
      );

      expect(success, isTrue);
      expect(liveVm.isListening, isTrue);
      expect(liveVm.sourceLanguageCode, equals('en'));
      expect(liveVm.targetLanguageCode, equals('te'));
      expect(liveVm.errorMessage, isNull);

      // Clean up when leaving session
      await liveVm.handleAppPaused();
      expect(liveVm.isListening, isFalse);
    });

    test('2. Two-Way Spoken Conversation & Auto TTS Language Routing', () async {
      final asrRepo = ASRRepository(
        audioRepository: audioRepo,
        asrService: MockASRService(),
      );

      final liveVm = LiveTranslationViewModel(
        translationRepository: translationRepo,
        ttsRepository: ttsRepo,
        asrRepository: asrRepo,
        settingsRepository: settingsRepo,
        initialSourceLanguageCode: 'en',
        initialTargetLanguageCode: 'te',
      );

      // Turn 1: Speaker speaks English -> Translated to Telugu -> TTS plays Telugu
      await liveVm.executeTranslation(
        text: 'Hello, how are you?',
        sourceCode: 'en',
        targetCode: 'te',
        isAutoFlow: true,
      );
      await Future.delayed(const Duration(milliseconds: 50));

      expect(translationService.lastSourceCode, equals('en'));
      expect(translationService.lastTargetCode, equals('te'));
      expect(ttsService.lastSpokenLangCode, equals('te'), reason: 'TTS must speak translated Telugu');
      expect(ttsService.lastSpokenText, contains('ఎలా ఉన్నారు'));

      // Turn 2: Speaker responds in Telugu -> Translated to English -> TTS plays English
      await liveVm.executeTranslation(
        text: 'నమస్తే, నేను బాగున్నాను.',
        sourceCode: 'te',
        targetCode: 'en',
        isAutoFlow: true,
      );
      await Future.delayed(const Duration(milliseconds: 50));

      expect(translationService.lastSourceCode, equals('te'));
      expect(translationService.lastTargetCode, equals('en'));
      expect(ttsService.lastSpokenLangCode, equals('en'), reason: 'TTS must speak translated English');
      expect(ttsService.lastSpokenText, contains('Hello'));
    });

    test('3. Cloud Speech Consent is explicitly enforced in Settings', () async {
      expect(settingsRepo.getCloudSpeechConsent(), isFalse, reason: 'Consent must be false by default');

      await settingsRepo.setCloudSpeechConsent(true);
      expect(settingsRepo.getCloudSpeechConsent(), isTrue);

      await settingsRepo.setCloudSpeechConsent(false);
      expect(settingsRepo.getCloudSpeechConsent(), isFalse);
    });

    test('4. Status Indicator: Clean ASCII without tofu characters, never shows Online when offline', () {
      final homeVm = HomeViewModel(
        translationRepository: translationRepo,
        settingsRepository: settingsRepo,
        audioRepository: audioRepo,
      );

      // Verify no tofu symbols in status text
      expect(homeVm.statusPillText, isNot(contains('•')));
      expect(homeVm.statusPillText, isNot(contains('⇄')));
      expect(homeVm.statusPillText, isNot(contains('→')));

      // In strictly Offline mode, must never say Online
      settingsRepo.setConnectionMode(ConnectionModeType.onDevice);
      homeVm.refreshFromSettings();
      expect(homeVm.statusPillText.toLowerCase(), isNot(contains('online')));
    });

    test('5. Dark Mode System Overlay Style Contrast on Android 16', () {
      final lightAppBar = AppTheme.lightTheme.appBarTheme;
      final darkAppBar = AppTheme.darkTheme.appBarTheme;

      expect(lightAppBar.systemOverlayStyle, isNotNull);
      expect(lightAppBar.systemOverlayStyle!.statusBarIconBrightness, equals(Brightness.dark),
          reason: 'Light theme must use dark status bar icons');

      expect(darkAppBar.systemOverlayStyle, isNotNull);
      expect(darkAppBar.systemOverlayStyle!.statusBarIconBrightness, equals(Brightness.light),
          reason: 'Dark theme must use light status bar icons');
    });

    test('6. Self-Translation Protection: Disallows translating a language into itself', () async {
      final liveVm = LiveTranslationViewModel(
        translationRepository: translationRepo,
        ttsRepository: ttsRepo,
        settingsRepository: settingsRepo,
      );

      await liveVm.executeTranslation(
        text: 'Hello world',
        sourceCode: 'en',
        targetCode: 'en',
      );

      expect(liveVm.translationStatus, equals(TranslationStatus.error));
      expect(liveVm.translatedText, isEmpty);
      expect(liveVm.errorMessage, contains('identical'));
    });
  });
}
