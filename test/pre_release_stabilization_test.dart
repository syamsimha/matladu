import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:matladu_ai/core/constants/app_strings.dart';
import 'package:matladu_ai/data/models/app_settings_model.dart';
import 'package:matladu_ai/data/models/asr_state.dart';
import 'package:matladu_ai/data/models/audio_recording_state.dart';
import 'package:matladu_ai/data/models/connection_mode_model.dart';
import 'package:matladu_ai/data/models/language_model.dart';
import 'package:matladu_ai/data/models/offline_pack_model.dart';
import 'package:matladu_ai/data/models/translation_result.dart';
import 'package:matladu_ai/data/models/tts_result.dart';
import 'package:matladu_ai/data/models/tts_voice.dart';
import 'package:matladu_ai/data/repositories/asr_repository.dart';
import 'package:matladu_ai/data/repositories/audio_repository.dart';
import 'package:matladu_ai/data/repositories/settings_repository.dart';
import 'package:matladu_ai/data/repositories/translation_repository.dart';
import 'package:matladu_ai/data/repositories/tts_repository.dart';
import 'package:matladu_ai/data/services/asr/mock_asr_service.dart';
import 'package:matladu_ai/data/services/asr/transcript_validator.dart';
import 'package:matladu_ai/data/services/audio_capture_service.dart';
import 'package:matladu_ai/data/services/audio_permission_service.dart';
import 'package:matladu_ai/data/services/engine/engine_selection_manager.dart';
import 'package:matladu_ai/data/services/local_storage_service.dart';
import 'package:matladu_ai/data/services/network_connectivity_service.dart';
import 'package:matladu_ai/data/services/translation/i_translation_service.dart';
import 'package:matladu_ai/data/services/translation/on_device_translation_service.dart';
import 'package:matladu_ai/data/services/tts/i_tts_service.dart';
import 'package:matladu_ai/ui/features/home/view_models/home_view_model.dart';
import 'package:matladu_ai/ui/features/language_selection/view_models/language_selection_view_model.dart';
import 'package:matladu_ai/ui/features/offline_packs/view_models/offline_packs_view_model.dart';
import 'package:matladu_ai/ui/features/settings/view_models/settings_view_model.dart';

class _FakeTranslationService implements ITranslationService {
  final Set<String> downloadedCodes = {'en'};
  final Map<String, String> responses = {
    'en_to_te:Hello': 'నమస్కారం',
    'te_to_en:నమస్కారం': 'Hello',
    'hi_to_en:नमस्ते': 'Hello',
    'ta_to_en:வணக்கம்': 'Hello',
    'kn_to_en:ನಮಸ್ಕಾರ': 'Hello',
    'en_to_hi:Hello': 'नमस्ते',
  };

  @override
  Future<void> initialize() async {}

  @override
  bool isLanguageSupported(String languageCode) => true;

  @override
  bool isPairSupported(String src, String tgt) => true;

  @override
  Future<bool> isModelDownloaded(String languageCode) async {
    return downloadedCodes.contains(languageCode);
  }

  @override
  Future<bool> downloadModel(String languageCode,
      {void Function(double progress)? onProgress}) async {
    downloadedCodes.add(languageCode);
    onProgress?.call(1.0);
    return true;
  }

  @override
  Future<bool> deleteModel(String languageCode) async {
    downloadedCodes.remove(languageCode);
    return true;
  }

  @override
  Stream<TranslationResult> get resultStream => const Stream.empty();

  @override
  Future<TranslationResult> translate({
    required String text,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) async {
    final key = '${sourceLanguageCode}_to_$targetLanguageCode:$text';
    final translated = responses[key] ?? 'Translated ($targetLanguageCode): $text';
    return TranslationResult(
      originalText: text,
      translatedText: translated,
      sourceLanguageCode: sourceLanguageCode,
      targetLanguageCode: targetLanguageCode,
      status: TranslationStatus.completed,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<void> dispose() async {}
}

class _FakeTtsService implements ITtsService {
  String? lastSpokenVoice;
  double? lastSpokenRate;
  final StreamController<TtsResult> _controller = StreamController<TtsResult>.broadcast();
  TtsPlaybackState _state = TtsPlaybackState.idle;
  String? _currentRequestId;

  final List<TtsVoice> offlineVoices = const [
    TtsVoice(
      name: 'te-in-x-female',
      locale: 'te-IN',
      languageCode: 'te',
      isNetworkRequired: false,
    ),
    TtsVoice(
      name: 'en-us-x-male',
      locale: 'en-US',
      languageCode: 'en',
      isNetworkRequired: false,
    ),
    TtsVoice(
      name: 'hi-in-x-female',
      locale: 'hi-IN',
      languageCode: 'hi',
      isNetworkRequired: false,
    ),
  ];

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
    lastSpokenVoice = voiceName;
    _currentRequestId = requestId;
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
  Future<void> setSpeechRate(double rate) async {
    lastSpokenRate = rate;
  }

  @override
  Future<void> setPitch(double pitch) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<String?> getDefaultEngine() async => 'com.google.android.tts';

  @override
  Future<List<String>> getEngines() async => ['com.google.android.tts'];

  @override
  Future<bool> openTtsSettings() async => true;

  @override
  Future<bool> openInstallTtsData() async => true;

  @override
  Stream<TtsResult> get stateStream => _controller.stream;

  @override
  TtsPlaybackState get currentState => _state;

  @override
  String? get currentRequestId => _currentRequestId;

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

class _SettableMockAsrService extends MockASRService {
  ASRRecognitionResult? _overrideResult;

  void setNextResult(ASRRecognitionResult result) {
    _overrideResult = result;
  }

  @override
  Future<ASRRecognitionResult> stopStreamingRecognition({Uint8List? recordedPcm}) async {
    if (_overrideResult != null) {
      final res = _overrideResult!;
      _overrideResult = null;
      return res;
    }
    return super.stopStreamingRecognition(recordedPcm: recordedPcm);
  }
}

class _FakeAudioCaptureService implements IAudioCaptureService {
  AudioCaptureState _state = AudioCaptureState.idle;
  final StreamController<Uint8List> _audioController = StreamController<Uint8List>.broadcast();
  final StreamController<double> _amplitudeController = StreamController<double>.broadcast();
  final StreamController<AudioCaptureState> _stateController = StreamController<AudioCaptureState>.broadcast();

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
  Uint8List get capturedAudioBytes => Uint8List(0);

  @override
  int get totalBytesCaptured => 0;

  @override
  Duration get recordingDuration => Duration.zero;

  @override
  Future<bool> startCapture({AudioCaptureConfig? config}) async {
    _state = AudioCaptureState.recording;
    return true;
  }

  @override
  Future<Uint8List?> stopCapture() async {
    _state = AudioCaptureState.idle;
    return Uint8List(0);
  }

  @override
  Future<void> cancelCapture() async {
    _state = AudioCaptureState.idle;
  }

  @override
  void resetBuffer() {}

  @override
  Future<void> dispose() async {
    await _audioController.close();
    await _amplitudeController.close();
    await _stateController.close();
  }
}

class _FakeAudioPermissionService implements IAudioPermissionService {
  const _FakeAudioPermissionService();

  @override
  Future<AudioPermissionStatus> checkPermission() async => AudioPermissionStatus.granted;

  @override
  Future<AudioPermissionStatus> requestPermission() async => AudioPermissionStatus.granted;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> openSettings() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late LocalStorageService storageService;
  late SettingsRepository settingsRepo;
  late _FakeTranslationService fakeTranslationService;
  late TranslationRepository translationRepo;
  late _FakeTtsService fakeTtsService;
  late TtsRepository ttsRepo;
  late NetworkConnectivityService connectivityService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storageService = LocalStorageService(prefs);
    settingsRepo = SettingsRepository(storageService: storageService);
    fakeTranslationService = _FakeTranslationService();
    translationRepo = TranslationRepository(
      translationService: fakeTranslationService,
      storageService: storageService,
    );
    fakeTtsService = _FakeTtsService();
    ttsRepo = TtsRepository(
      ttsService: fakeTtsService,
      storageService: storageService,
    );
    connectivityService = NetworkConnectivityService();
  });

  group('1. Source-Language Detection & Auto-Detect', () {
    test('LanguageModel.autoDetect is configured correctly', () {
      expect(LanguageModel.autoDetect.code, 'auto');
      expect(LanguageModel.autoDetect.name, 'Auto Detect');
      expect(LanguageModel.fromCode('auto'), LanguageModel.autoDetect);
      expect(LanguageModel.fromCode('autodetect'), LanguageModel.autoDetect);
    });

    test('Fresh install defaults source language to Auto Detect', () {
      expect(storageService.getSourceLanguageCode(), 'auto');
      expect(settingsRepo.getSourceLanguage(), LanguageModel.autoDetect);
    });

    test('LanguageSelectionViewModel shows Auto Detect ONLY for source', () {
      // 1. Source selection -> Auto Detect at index 0
      final sourceVm = LanguageSelectionViewModel(
        isSelectingSource: true,
      );
      expect(sourceVm.filteredLanguages.first.code, 'auto');
      expect(sourceVm.filteredLanguages.first.name, 'Auto Detect');

      // 2. Target selection -> Auto Detect strictly NOT present
      final targetVm = LanguageSelectionViewModel(
        isSelectingSource: false,
      );
      final hasAutoInTarget = targetVm.filteredLanguages.any((l) => l.code == 'auto');
      expect(hasAutoInTarget, isFalse);

      // Attempting to select auto for target must be rejected
      targetVm.selectLanguage(LanguageModel.autoDetect);
      expect(targetVm.selectedLanguage.code, isNot('auto'));
    });

    test('HomeViewModel protects target language from becoming Auto Detect', () async {
      final audioRepo = AudioRepository(
        captureService: _FakeAudioCaptureService(),
        permissionService: const _FakeAudioPermissionService(),
      );
      final mockAsr = _SettableMockAsrService();
      final asrRepo = ASRRepository(
        audioRepository: audioRepo,
        asrService: mockAsr,
      );

      final homeVm = HomeViewModel(
        translationRepository: translationRepo,
        settingsRepository: settingsRepo,
        audioRepository: audioRepo,
        asrRepository: asrRepo,
        ttsRepository: ttsRepo,
      );

      // Default source is Auto Detect
      expect(homeVm.sourceLanguage.code, 'auto');

      // Setting target to Auto Detect must be rejected
      await homeVm.setTargetLanguage(LanguageModel.autoDetect);
      expect(homeVm.targetLanguage.code, isNot('auto'));

      // Swapping languages when source is Auto Detect moves target to source and assigns a non-auto target
      final originalTarget = homeVm.targetLanguage;
      homeVm.swapLanguages();
      expect(homeVm.sourceLanguage.code, originalTarget.code);
      expect(homeVm.targetLanguage.code, isNot('auto'));
    });

    test('Auto-Detect preserves source language state without session contamination', () async {
      final audioRepo = AudioRepository(
        captureService: _FakeAudioCaptureService(),
        permissionService: const _FakeAudioPermissionService(),
      );
      final mockAsr = _SettableMockAsrService();
      final asrRepo = ASRRepository(
        audioRepository: audioRepo,
        asrService: mockAsr,
      );

      final homeVm = HomeViewModel(
        translationRepository: translationRepo,
        settingsRepository: settingsRepo,
        audioRepository: audioRepo,
        asrRepository: asrRepo,
        ttsRepository: ttsRepo,
      );

      expect(homeVm.sourceLanguage.code, 'auto');

      // Simulate Turn 1: Speaker speaks Telugu
      mockAsr.setNextResult(ASRRecognitionResult(
        text: 'నమస్కారం',
        isFinal: true,
        confidence: 0.95,
        detectedLanguageCode: 'te',
        audioDuration: const Duration(seconds: 1),
        timestamp: DateTime.now(),
      ));
      await homeVm.toggleRecording(); // Start recording
      await Future.delayed(const Duration(milliseconds: 50));
      await homeVm.toggleRecording(); // Stop & finalize
      await Future.delayed(const Duration(milliseconds: 200));

      // After turn 1 finalized, source language in HomeViewModel MUST remain Auto Detect!
      expect(homeVm.sourceLanguage.code, 'auto');
      expect(settingsRepo.getSourceLanguage().code, 'auto');

      // Simulate Turn 2: Speaker speaks English
      mockAsr.setNextResult(ASRRecognitionResult(
        text: 'Hello',
        isFinal: true,
        confidence: 0.95,
        detectedLanguageCode: 'en',
        audioDuration: const Duration(seconds: 1),
        timestamp: DateTime.now(),
      ));
      await homeVm.toggleRecording(); // Start recording
      await Future.delayed(const Duration(milliseconds: 50));
      await homeVm.toggleRecording(); // Stop & finalize
      await Future.delayed(const Duration(milliseconds: 200));

      // Source language MUST STILL remain Auto Detect!
      expect(homeVm.sourceLanguage.code, 'auto');
      expect(settingsRepo.getSourceLanguage().code, 'auto');
    });
  });

  group('2. Connection Mode Single Source of Truth', () {
    test('Fresh install defaults connection mode to automatic', () {
      expect(storageService.getConnectionMode(), ConnectionModeType.automatic);
      expect(settingsRepo.getConnectionMode().type, ConnectionModeType.automatic);
    });

    test('EngineSelectionManager updates and persists across listeners', () async {
      final engineMgr = EngineSelectionManager(
        connectivityService: connectivityService,
        settingsRepository: settingsRepo,
      );
      int listenerFiredCount = 0;
      engineMgr.addListener(() {
        listenerFiredCount++;
      });

      // Switch to Offline mode
      engineMgr.setUserMode(ConnectionModeType.onDevice);
      expect(engineMgr.activeMode, ConnectionModeType.onDevice);
      expect(settingsRepo.getConnectionMode().type, ConnectionModeType.onDevice);
      expect(listenerFiredCount >= 1, isTrue);

      final countAfterOffline = listenerFiredCount;
      // Switch to Online mode
      engineMgr.setUserMode(ConnectionModeType.cloudAi);
      expect(engineMgr.activeMode, ConnectionModeType.cloudAi);
      expect(settingsRepo.getConnectionMode().type, ConnectionModeType.cloudAi);
      expect(listenerFiredCount > countAfterOffline, isTrue);

      final countAfterOnline = listenerFiredCount;
      // Switch back to Automatic mode
      engineMgr.setUserMode(ConnectionModeType.automatic);
      expect(engineMgr.activeMode, ConnectionModeType.automatic);
      expect(settingsRepo.getConnectionMode().type, ConnectionModeType.automatic);
      expect(listenerFiredCount > countAfterOnline, isTrue);
    });
  });

  group('3. App Preferences — Voice and Speed', () {
    test('AppStrings subtitle reflects Voice, Speed without Theme', () {
      expect(AppStrings.themeVoiceSpeed, 'Voice, Speed');
      expect(AppStrings.themeVoiceSpeed.contains('Theme'), isFalse);
    });

    test('AppSettingsModel serializes and deserializes selectedVoiceName', () {
      const initial = AppSettingsModel(
        speechSpeed: 1.2,
        selectedVoiceName: 'te-in-x-female',
      );
      final json = initial.toJson();
      expect(json['selectedVoiceName'], 'te-in-x-female');
      expect(json['speechSpeed'], 1.2);

      final restored = AppSettingsModel.fromJson(json);
      expect(restored.selectedVoiceName, 'te-in-x-female');
      expect(restored.speechSpeed, 1.2);
    });

    test('SettingsViewModel loads voices, updates voice selection and speech speed', () async {
      final settingsVm = SettingsViewModel(
        settingsRepository: settingsRepo,
        ttsRepository: ttsRepo,
      );

      await settingsVm.loadVoices();
      expect(settingsVm.availableVoices.length, 3);

      // Select Telugu voice
      await settingsVm.updateSelectedVoice('te-in-x-female');
      expect(settingsVm.selectedVoiceName, 'te-in-x-female');
      expect(settingsRepo.getAppSettings().selectedVoiceName, 'te-in-x-female');

      // Update speech speed
      await settingsVm.updateSpeechSpeed(1.25);
      expect(settingsVm.speechSpeed, 1.25);
      expect(settingsRepo.getAppSettings().speechSpeed, 1.25);

      // Test preview voice
      await settingsVm.previewVoice();
      expect(fakeTtsService.lastSpokenVoice, 'te-in-x-female');
    });

    test('TtsRepository uses selectedVoiceName when speaking', () async {
      await settingsRepo.saveAppSettings(
        const AppSettingsModel(selectedVoiceName: 'hi-in-x-female', speechSpeed: 0.9),
      );

      await ttsRepo.speakTranslation(text: 'Hello', targetLanguageCode: 'hi');
      expect(fakeTtsService.lastSpokenVoice, 'hi-in-x-female');
    });
  });

  group('4. Offline Language Packs', () {
    test('On fresh install, optional translation packs are NOT downloaded', () {
      final downloadedCodes = storageService.getDownloadedPackCodes();
      expect(downloadedCodes, isEmpty);
      expect(downloadedCodes.contains('en'), isFalse);
      expect(downloadedCodes.contains('te'), isFalse);
      expect(downloadedCodes.contains('hi'), isFalse);
      expect(downloadedCodes.contains('ta'), isFalse);
      expect(downloadedCodes.contains('kn'), isFalse);
    });

    test('OnDeviceTranslationService simulated set defaults to en only and handles download/delete', () async {
      final onDevice = OnDeviceTranslationService(simulatedDownloadedCodes: {'en'});
      // On desktop / non-native, isModelDownloaded delegates to simulated set
      expect(await onDevice.isModelDownloaded('en'), isTrue);
      expect(await onDevice.isModelDownloaded('te'), isFalse);
      expect(await onDevice.isModelDownloaded('hi'), isFalse);

      // Explicit download adds to downloaded models
      final downloaded = await onDevice.downloadModel('te');
      expect(downloaded, isTrue);
      expect(await onDevice.isModelDownloaded('te'), isTrue);

      // Explicit delete removes model
      final deleted = await onDevice.deleteModel('te');
      expect(deleted, isTrue);
      expect(await onDevice.isModelDownloaded('te'), isFalse);
    });

    test('OfflinePacksViewModel verifies disk and manages download and deletion', () async {
      final packsVm = OfflinePacksViewModel(
        settingsRepository: settingsRepo,
        translationRepository: translationRepo,
      );

      // Let initial async verification complete
      await Future.delayed(const Duration(milliseconds: 50));

      // Initially, Telugu is not downloaded
      final tePackBefore = packsVm.availablePacks.firstWhere((p) => p.languageCode == 'te');
      expect(tePackBefore.installState, PackInstallState.notDownloaded);

      // Download Telugu
      await packsVm.downloadPack(tePackBefore);
      final tePackAfter = packsVm.downloadedPacks.firstWhere((p) => p.languageCode == 'te');
      expect(tePackAfter.installState, PackInstallState.installedAndReady);
      expect(settingsRepo.getDownloadedPackCodes().contains('te'), isTrue);

      // Delete Telugu
      await packsVm.deletePack('te');
      expect(packsVm.downloadedPacks.any((p) => p.languageCode == 'te'), isFalse);
      expect(settingsRepo.getDownloadedPackCodes().contains('te'), isFalse);
      expect(fakeTranslationService.downloadedCodes.contains('te'), isFalse);
    });
  });

  group('5. Multilingual Script Validator', () {
    test('Validates Telugu, Hindi, Tamil, Kannada, and English scripts correctly', () {
      expect(TranscriptValidator.teluguScriptRegex.hasMatch('నమస్కారం'), isTrue);
      expect(TranscriptValidator.devanagariScriptRegex.hasMatch('नमस्ते'), isTrue);
      expect(TranscriptValidator.tamilScriptRegex.hasMatch('வணக்கம்'), isTrue);
      expect(TranscriptValidator.kannadaScriptRegex.hasMatch('ನಮಸ್ಕಾರ'), isTrue);
      expect(TranscriptValidator.latinScriptRegex.hasMatch('Hello world'), isTrue);

      expect(TranscriptValidator.validate('నమస్కారం').resolvedScript, 'te');
      expect(TranscriptValidator.validate('नमस्ते').resolvedScript, 'hi');
      expect(TranscriptValidator.validate('வணக்கம்').resolvedScript, 'ta');
      expect(TranscriptValidator.validate('ನಮಸ್ಕಾರ').resolvedScript, 'kn');
      expect(TranscriptValidator.validate('Hello world').resolvedScript, 'en');
    });

    test('Rejects invalid scripts and unmapped characters', () {
      expect(TranscriptValidator.latinScriptRegex.hasMatch('నమస్కారం'), isFalse);
      expect(TranscriptValidator.tamilScriptRegex.hasMatch('నమస్కారం'), isFalse);

      // CJK characters match cjkHallucinationRegex
      expect(TranscriptValidator.cjkHallucinationRegex.hasMatch('你好'), isTrue);
      final res = TranscriptValidator.validate('你好');
      expect(res.isValid, isFalse);
    });
  });
}
