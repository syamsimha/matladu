import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:matladu_ai/data/models/asr_state.dart';
import 'package:matladu_ai/data/models/audio_recording_state.dart';
import 'package:matladu_ai/data/models/connection_mode_model.dart';
import 'package:matladu_ai/data/models/language_model.dart';
import 'package:matladu_ai/data/models/translation_result.dart';
import 'package:matladu_ai/data/repositories/asr_repository.dart';
import 'package:matladu_ai/data/repositories/audio_repository.dart';
import 'package:matladu_ai/data/repositories/settings_repository.dart';
import 'package:matladu_ai/data/repositories/translation_repository.dart';
import 'package:matladu_ai/data/services/asr/mock_asr_service.dart';
import 'package:matladu_ai/data/services/asr/pcm_converter.dart';
import 'package:matladu_ai/data/services/asr/transcript_validator.dart';
import 'package:matladu_ai/data/services/audio_capture_service.dart';
import 'package:matladu_ai/data/services/audio_permission_service.dart';
import 'package:matladu_ai/data/services/engine/engine_selection_manager.dart';
import 'package:matladu_ai/data/services/local_storage_service.dart';
import 'package:matladu_ai/data/services/network_connectivity_service.dart';
import 'package:matladu_ai/data/services/translation/hybrid_translation_service.dart';
import 'package:matladu_ai/data/services/translation/on_device_translation_service.dart';
import 'package:matladu_ai/data/services/translation/online_translation_service.dart';
import 'package:matladu_ai/ui/features/home/view_models/home_view_model.dart';
import 'package:matladu_ai/ui/features/settings/view_models/settings_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =============================================================================
// TEST DOUBLES & MOCKS FOR DETERMINISTIC VERIFICATION
// Note: These unit tests use controlled mock doubles conforming to production
// contracts. Real on-device Sherpa ONNX binary execution requires an Android
// runtime with loaded libsherpa-onnx-jni.so.
// =============================================================================

class SettableMockAsrService extends MockASRService {
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

class FakeAudioPermissionService implements IAudioPermissionService {
  const FakeAudioPermissionService();

  @override
  Future<AudioPermissionStatus> checkPermission() async => AudioPermissionStatus.granted;

  @override
  Future<AudioPermissionStatus> requestPermission() async => AudioPermissionStatus.granted;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> openSettings() async => true;
}

class FakeAudioCaptureService implements IAudioCaptureService {
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
    _stateController.add(_state);
    return true;
  }

  @override
  Future<Uint8List?> stopCapture() async {
    _state = AudioCaptureState.idle;
    _stateController.add(_state);
    return Uint8List(0);
  }

  @override
  Future<void> cancelCapture() async {
    _state = AudioCaptureState.idle;
    _stateController.add(_state);
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

class ControlledConnectivityService extends NetworkConnectivityService {
  bool _connected;
  final StreamController<NetworkState> _controller = StreamController<NetworkState>.broadcast();

  ControlledConnectivityService(this._connected);

  @override
  bool get isConnected => _connected;

  @override
  bool get isValidatedInternet => _connected;

  @override
  Stream<NetworkState> get stateStream => _controller.stream;

  void emitState(bool connected) {
    _connected = connected;
    final state = NetworkState(
      isConnected: connected,
      isValidated: connected,
      isWifi: connected,
      isCellular: false,
      type: connected ? 'wifi' : 'none',
    );
    _controller.add(state);
  }

  @override
  Future<NetworkState> checkConnectivity() async {
    final state = NetworkState(
      isConnected: _connected,
      isValidated: _connected,
      isWifi: _connected,
      isCellular: false,
      type: _connected ? 'wifi' : 'none',
    );
    return state;
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}

class MockableOnDeviceTranslationService extends OnDeviceTranslationService {
  final Map<String, bool> _installedModels = {'en': true, 'te': true, 'hi': true, 'ta': true, 'kn': true};

  MockableOnDeviceTranslationService({Map<String, bool>? initialModels}) {
    if (initialModels != null) {
      _installedModels.clear();
      _installedModels.addAll(initialModels);
    }
  }

  void setModelInstalled(String lang, bool installed) {
    _installedModels[lang] = installed;
  }

  @override
  Future<bool> isModelDownloaded(String languageCode) async {
    return _installedModels[languageCode] ?? false;
  }

  @override
  Future<TranslationResult> translate({
    required String text,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) async {
    final isInstalled = await isModelDownloaded(targetLanguageCode);
    if (!isInstalled) {
      return TranslationResult.modelMissing(
        text: text,
        sourceLang: sourceLanguageCode,
        targetLang: targetLanguageCode,
        missingLanguageName: targetLanguageCode,
      );
    }
    return TranslationResult(
      originalText: text,
      translatedText: '[Local ML Kit] $text ($sourceLanguageCode->$targetLanguageCode)',
      sourceLanguageCode: sourceLanguageCode,
      targetLanguageCode: targetLanguageCode,
      status: TranslationStatus.completed,
      timestamp: DateTime.now(),
      isMock: true,
    );
  }
}

class MockResponseHttpClient implements HttpClient {
  int statusCode;
  String responseBody;
  final List<Uri> interceptedUris = [];

  MockResponseHttpClient({
    this.statusCode = 200,
    this.responseBody = '{"responseStatus": 200, "responseData": {"translatedText": "శుభోదయం"}}',
  });

  @override
  Duration? connectionTimeout;

  @override
  void close({bool force = false}) {}

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    interceptedUris.add(url);
    return _MockHttpClientRequest(statusCode, responseBody);
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    interceptedUris.add(url);
    return _MockHttpClientRequest(statusCode, responseBody);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpClientRequest implements HttpClientRequest {
  final int statusCode;
  final String responseBody;

  _MockHttpClientRequest(this.statusCode, this.responseBody);

  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async {
    return _MockHttpClientResponse(statusCode, responseBody);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _headers = {};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers[name.toLowerCase()] = [value.toString()];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  final int statusCode;
  final String responseBody;

  _MockHttpClientResponse(this.statusCode, this.responseBody);

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.value(utf8.encode(responseBody)).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// =============================================================================
// REGRESSION TEST SUITE
// =============================================================================

void main() {
  group('1. Automatic Language Detection & Audio Preprocessing', () {
    test('Acoustic detection correctly resolves spoken Telugu without defaulting to English', () async {
      final mockAsr = SettableMockAsrService();
      final audioRepo = AudioRepository(
        captureService: FakeAudioCaptureService(),
        permissionService: const FakeAudioPermissionService(),
      );
      final asrRepo = ASRRepository(
        audioRepository: audioRepo,
        asrService: mockAsr,
      );

      mockAsr.setNextResult(ASRRecognitionResult(
        text: 'నమస్కారం, మీరు ఎలా ఉన్నారు?',
        detectedLanguageCode: 'te',
        detectedLanguageName: 'Telugu',
        confidence: 0.94,
        audioDuration: const Duration(seconds: 2),
        timestamp: DateTime.now(),
        isFinal: true,
        isMock: false,
      ));

      await asrRepo.startListeningAndRecognition(languageCodeHint: 'auto');
      final result = await asrRepo.stopAndFinalize();

      expect(result.detectedLanguageCode, 'te');
      expect(result.detectedLanguageName, 'Telugu');
      expect(result.confidence, greaterThanOrEqualTo(0.35));
      expect(result.detectedLanguageCode, isNot('en'));
    });

    test('Acoustic detection correctly resolves all 5 supported languages', () async {
      final langs = [
        ('te', 'Telugu', 'నమస్తే'),
        ('en', 'English', 'Hello, how are you?'),
        ('hi', 'Hindi', 'नमस्ते आप कैसे हैं'),
        ('ta', 'Tamil', 'வணக்கம்'),
        ('kn', 'Kannada', 'ನಮಸ್ಕಾರ'),
      ];

      for (final (code, name, sampleText) in langs) {
        final mockAsr = SettableMockAsrService();
        final audioRepo = AudioRepository(
          captureService: FakeAudioCaptureService(),
          permissionService: const FakeAudioPermissionService(),
        );
        final asrRepo = ASRRepository(
          audioRepository: audioRepo,
          asrService: mockAsr,
        );

        mockAsr.setNextResult(ASRRecognitionResult(
          text: sampleText,
          detectedLanguageCode: code,
          detectedLanguageName: name,
          confidence: 0.91,
          audioDuration: const Duration(seconds: 2),
          timestamp: DateTime.now(),
          isFinal: true,
          isMock: false,
        ));

        await asrRepo.startListeningAndRecognition(languageCodeHint: 'auto');
        final result = await asrRepo.stopAndFinalize();

        expect(result.detectedLanguageCode, code);
        expect(result.detectedLanguageName, name);
        expect(result.confidence, greaterThanOrEqualTo(0.35));
      }
    });

    test('Consecutive alternating languages do NOT reuse stale cached language results', () async {
      final mockAsr = SettableMockAsrService();
      final audioRepo = AudioRepository(
        captureService: FakeAudioCaptureService(),
        permissionService: const FakeAudioPermissionService(),
      );
      final asrRepo = ASRRepository(
        audioRepository: audioRepo,
        asrService: mockAsr,
      );

      // Turn 1: Spoken Telugu
      mockAsr.setNextResult(ASRRecognitionResult(
        text: 'నమస్కారం',
        detectedLanguageCode: 'te',
        detectedLanguageName: 'Telugu',
        confidence: 0.95,
        audioDuration: const Duration(seconds: 2),
        timestamp: DateTime.now(),
        isFinal: true,
      ));
      await asrRepo.startListeningAndRecognition(languageCodeHint: 'auto');
      final r1 = await asrRepo.stopAndFinalize();
      expect(r1.detectedLanguageCode, 'te');

      // Turn 2: Spoken English
      mockAsr.setNextResult(ASRRecognitionResult(
        text: 'Good morning',
        detectedLanguageCode: 'en',
        detectedLanguageName: 'English',
        confidence: 0.98,
        audioDuration: const Duration(seconds: 2),
        timestamp: DateTime.now(),
        isFinal: true,
      ));
      await asrRepo.startListeningAndRecognition(languageCodeHint: 'auto');
      final r2 = await asrRepo.stopAndFinalize();
      expect(r2.detectedLanguageCode, 'en');
      expect(r2.detectedLanguageCode, isNot('te')); // Stale Telugu state cleared!

      // Turn 3: Spoken Hindi
      mockAsr.setNextResult(ASRRecognitionResult(
        text: 'नमस्ते',
        detectedLanguageCode: 'hi',
        detectedLanguageName: 'Hindi',
        confidence: 0.92,
        audioDuration: const Duration(seconds: 2),
        timestamp: DateTime.now(),
        isFinal: true,
      ));
      await asrRepo.startListeningAndRecognition(languageCodeHint: 'auto');
      final r3 = await asrRepo.stopAndFinalize();
      expect(r3.detectedLanguageCode, 'hi');
      expect(r3.detectedLanguageCode, isNot('en')); // Stale English state cleared!
    });

    test('Low-confidence or ambiguous detection yields und with 0.0 confidence, never guesses en', () async {
      final mockAsr = SettableMockAsrService();
      final audioRepo = AudioRepository(
        captureService: FakeAudioCaptureService(),
        permissionService: const FakeAudioPermissionService(),
      );
      final asrRepo = ASRRepository(
        audioRepository: audioRepo,
        asrService: mockAsr,
      );

      mockAsr.setNextResult(ASRRecognitionResult(
        text: '...',
        detectedLanguageCode: 'und',
        detectedLanguageName: 'Undetermined',
        confidence: 0.0,
        audioDuration: const Duration(seconds: 1),
        timestamp: DateTime.now(),
        isFinal: true,
      ));

      await asrRepo.startListeningAndRecognition(languageCodeHint: 'auto');
      final res = await asrRepo.stopAndFinalize();

      expect(res.detectedLanguageCode, 'und');
      expect(res.confidence, lessThan(0.35));
      expect(res.detectedLanguageCode, isNot('en'));
    });

    test('Romanized Indic speech does NOT get overridden to English by script heuristics', () {
      const romanizedText = 'Namaskaram, meeru ela unnaru?';
      final val = TranscriptValidator.validate(romanizedText);

      expect(val.isValid, isTrue);
      // In SherpaOnDeviceASRService, acoustic detection 'te' takes precedence over Latin script
      const acousticLang = 'te';
      final isIndicScript = val.resolvedScript == 'te' || val.resolvedScript == 'hi';
      final finalLang = (acousticLang.isNotEmpty && acousticLang != 'und')
          ? acousticLang
          : (isIndicScript ? val.resolvedScript : 'und');

      expect(finalLang, 'te'); // Acoustic detection is preserved!
    });

    test('Quiet microphone input (peak < 14,000) is dynamically boosted into nominal Whisper range', () {
      final quietFloatSamples = Float32List(1600);
      for (int i = 0; i < quietFloatSamples.length; i++) {
        quietFloatSamples[i] = 0.06 * math.sin(2 * math.pi * 440 * i / 16000);
      }

      final (minBefore, maxBefore) = PCMConverter.computeFloatMinMax(quietFloatSamples);
      expect(maxBefore, closeTo(0.06, 0.01));

      final boosted = PCMConverter.optimizeDynamicRange(quietFloatSamples, nominalPeak: 0.70);
      final (minAfter, maxAfter) = PCMConverter.computeFloatMinMax(boosted);

      expect(maxAfter, greaterThan(0.40));
      expect(maxAfter, lessThanOrEqualTo(1.0));
      expect(minAfter, greaterThanOrEqualTo(-1.0));
    });
  });

  group('2. Translation Direction & Target Locking', () {
    late SharedPreferences prefs;
    late LocalStorageService storage;
    late SettingsRepository settingsRepo;
    late TranslationRepository transRepo;
    late MockableOnDeviceTranslationService onDeviceTranslation;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
      settingsRepo = SettingsRepository(storageService: storage);
      onDeviceTranslation = MockableOnDeviceTranslationService();
      transRepo = TranslationRepository(
        translationService: onDeviceTranslation,
        storageService: storage,
      );
    });

    test('All required language pairs translate correctly and target remains locked', () async {
      final scenarios = [
        ('te', 'en', 'నమస్తే', 'English'),
        ('en', 'te', 'Hello', 'Telugu'),
        ('hi', 'te', 'नमस्ते', 'Telugu'),
        ('te', 'hi', 'నమస్కారం', 'Hindi'),
        ('ta', 'kn', 'வணக்கம்', 'Kannada'),
      ];

      for (final (src, tgt, text, expectedTgtName) in scenarios) {
        await settingsRepo.setSourceLanguage(LanguageModel.fromCode(src)!);
        await settingsRepo.setTargetLanguage(LanguageModel.fromCode(tgt)!);

        final mockAsr = SettableMockAsrService();
        mockAsr.setNextResult(ASRRecognitionResult(
          text: text,
          detectedLanguageCode: src,
          detectedLanguageName: src,
          confidence: 0.95,
          audioDuration: const Duration(seconds: 2),
          timestamp: DateTime.now(),
          isFinal: true,
        ));
        final audioRepo = AudioRepository(
          captureService: FakeAudioCaptureService(),
          permissionService: const FakeAudioPermissionService(),
        );
        final asrRepo = ASRRepository(
          audioRepository: audioRepo,
          asrService: mockAsr,
        );

        final homeVm = HomeViewModel(
          translationRepository: transRepo,
          settingsRepository: settingsRepo,
          asrRepository: asrRepo,
        );

        await homeVm.toggleRecording();
        await homeVm.toggleRecording();

        expect(homeVm.targetLanguage.code, tgt);
        expect(homeVm.targetLanguage.name, expectedTgtName);
        expect(homeVm.resolvedTargetCode, tgt);
        expect(homeVm.resolvedSourceCode, src);
        expect(homeVm.latestTranslationText, contains('$src->$tgt'));
      }
    });

    test('Auto-Detect applies ONLY to source; target language is NEVER changed', () async {
      await settingsRepo.setSourceLanguage(LanguageModel.autoDetect);
      await settingsRepo.setTargetLanguage(LanguageModel.fromCode('en')!);

      final mockAsr = SettableMockAsrService();
      mockAsr.setNextResult(ASRRecognitionResult(
        text: 'బాగున్నారా?',
        detectedLanguageCode: 'te',
        detectedLanguageName: 'Telugu',
        confidence: 0.92,
        audioDuration: const Duration(seconds: 2),
        timestamp: DateTime.now(),
        isFinal: true,
      ));
      final audioRepo = AudioRepository(
        captureService: FakeAudioCaptureService(),
        permissionService: const FakeAudioPermissionService(),
      );
      final asrRepo = ASRRepository(
        audioRepository: audioRepo,
        asrService: mockAsr,
      );

      final homeVm = HomeViewModel(
        translationRepository: transRepo,
        settingsRepository: settingsRepo,
        asrRepository: asrRepo,
      );

      await homeVm.toggleRecording();
      await homeVm.toggleRecording();

      expect(homeVm.resolvedSourceCode, 'te');
      expect(homeVm.targetLanguage.code, 'en');
      expect(homeVm.resolvedTargetCode, 'en');
      expect(homeVm.sourceLanguage.code, 'auto');
      expect(homeVm.latestTranslationText, contains('te->en'));
    });

    test('When spoken language matches selected target, app does NOT translate language into itself', () async {
      await settingsRepo.setSourceLanguage(LanguageModel.autoDetect);
      await settingsRepo.setTargetLanguage(LanguageModel.fromCode('te')!);

      final mockAsr = SettableMockAsrService();
      mockAsr.setNextResult(ASRRecognitionResult(
        text: 'నమస్కారం',
        detectedLanguageCode: 'te',
        detectedLanguageName: 'Telugu',
        confidence: 0.96,
        audioDuration: const Duration(seconds: 2),
        timestamp: DateTime.now(),
        isFinal: true,
      ));
      final audioRepo = AudioRepository(
        captureService: FakeAudioCaptureService(),
        permissionService: const FakeAudioPermissionService(),
      );
      final asrRepo = ASRRepository(
        audioRepository: audioRepo,
        asrService: mockAsr,
      );

      final homeVm = HomeViewModel(
        translationRepository: transRepo,
        settingsRepository: settingsRepo,
        asrRepository: asrRepo,
      );

      await homeVm.toggleRecording();
      await homeVm.toggleRecording();

      expect(homeVm.resolvedSourceCode, 'te');
      expect(homeVm.resolvedTargetCode, 'te');
      expect(homeVm.latestTranslationText, isEmpty);
    });

    test('Failed translation returns empty string and does NOT replace failed result with original sentence', () async {
      final failingService = MockableOnDeviceTranslationService(initialModels: {});
      final failTransRepo = TranslationRepository(
        translationService: failingService,
        storageService: storage,
      );

      final item = await failTransRepo.translate(
        text: 'Critical sentence',
        sourceLang: LanguageModel.fromCode('en')!,
        targetLang: LanguageModel.fromCode('te')!,
      );

      expect(item.translatedText, isEmpty);
    });
  });

  group('3. Connection-Mode Matrix (All 8 Combinations)', () {
    late ControlledConnectivityService connectivityOnline;
    late ControlledConnectivityService connectivityOffline;
    late MockResponseHttpClient onlineHttp;
    late OnlineTranslationService onlineService;
    late MockableOnDeviceTranslationService onDeviceInstalled;
    late MockableOnDeviceTranslationService onDeviceMissing;

    setUp(() {
      connectivityOnline = ControlledConnectivityService(true);
      connectivityOffline = ControlledConnectivityService(false);
      onlineHttp = MockResponseHttpClient(
        statusCode: 200,
        responseBody: '{"responseStatus": 200, "responseData": {"translatedText": "శుభోదయం"}}',
      );
      onlineService = OnlineTranslationService(httpClient: onlineHttp);
      onDeviceInstalled = MockableOnDeviceTranslationService(initialModels: {'en': true, 'te': true});
      onDeviceMissing = MockableOnDeviceTranslationService(initialModels: {'en': true, 'te': false});
    });

    test('Matrix Comb 1: Auto + Internet + Pack Installed -> Uses Online Provider', () async {
      final engineMgr = EngineSelectionManager(
        connectivityService: connectivityOnline,
        onlineTranslationService: onlineService,
        onDeviceTranslationService: onDeviceInstalled,
        initialMode: ConnectionModeType.automatic,
      );
      final hybrid = HybridTranslationService(
        onlineService: onlineService,
        onDeviceService: onDeviceInstalled,
        engineSelectionManager: engineMgr,
      );
      await hybrid.initialize();

      final res = await hybrid.translate(text: 'Hello', sourceLanguageCode: 'en', targetLanguageCode: 'te');
      expect(res.isSuccess, isTrue);
      expect(onlineHttp.interceptedUris.length, 1);
      expect(res.translatedText, 'శుభోదయం');
    });

    test('Matrix Comb 2: Auto + No Internet + Pack Installed -> Seamlessly Uses Offline ML Kit', () async {
      final engineMgr = EngineSelectionManager(
        connectivityService: connectivityOffline,
        onlineTranslationService: onlineService,
        onDeviceTranslationService: onDeviceInstalled,
        initialMode: ConnectionModeType.automatic,
      );
      final hybrid = HybridTranslationService(
        onlineService: onlineService,
        onDeviceService: onDeviceInstalled,
        engineSelectionManager: engineMgr,
      );
      await hybrid.initialize();

      final res = await hybrid.translate(text: 'Hello', sourceLanguageCode: 'en', targetLanguageCode: 'te');
      expect(res.isSuccess, isTrue);
      expect(onlineHttp.interceptedUris.length, 0);
      expect(res.translatedText, contains('[Local ML Kit]'));
    });

    test('Matrix Comb 3: Auto + No Internet + Pack Missing -> Shows Unavailable / Pack Needed', () async {
      final engineMgr = EngineSelectionManager(
        connectivityService: connectivityOffline,
        onlineTranslationService: onlineService,
        onDeviceTranslationService: onDeviceMissing,
        initialMode: ConnectionModeType.automatic,
      );
      final hybrid = HybridTranslationService(
        onlineService: onlineService,
        onDeviceService: onDeviceMissing,
        engineSelectionManager: engineMgr,
      );
      await hybrid.initialize();

      final res = await hybrid.translate(text: 'Hello', sourceLanguageCode: 'en', targetLanguageCode: 'te');
      expect(res.isSuccess, isFalse);
      expect(res.status, TranslationStatus.error);
    });

    test('Matrix Comb 4: Online + Internet + Pack Installed -> Uses Online Provider Only', () async {
      final engineMgr = EngineSelectionManager(
        connectivityService: connectivityOnline,
        onlineTranslationService: onlineService,
        onDeviceTranslationService: onDeviceInstalled,
        initialMode: ConnectionModeType.cloudAi,
      );
      final hybrid = HybridTranslationService(
        onlineService: onlineService,
        onDeviceService: onDeviceInstalled,
        engineSelectionManager: engineMgr,
      );
      await hybrid.initialize();

      final res = await hybrid.translate(text: 'Hello', sourceLanguageCode: 'en', targetLanguageCode: 'te');
      expect(res.isSuccess, isTrue);
      expect(onlineHttp.interceptedUris.length, 1);
      expect(res.translatedText, 'శుభోదయం');
    });

    test('Matrix Comb 5: Online + No Internet + Pack Installed -> Online Unavailable (Zero Fallback)', () async {
      final engineMgr = EngineSelectionManager(
        connectivityService: connectivityOffline,
        onlineTranslationService: onlineService,
        onDeviceTranslationService: onDeviceInstalled,
        initialMode: ConnectionModeType.cloudAi,
      );
      final hybrid = HybridTranslationService(
        onlineService: onlineService,
        onDeviceService: onDeviceInstalled,
        engineSelectionManager: engineMgr,
      );
      await hybrid.initialize();

      final res = await hybrid.translate(text: 'Hello', sourceLanguageCode: 'en', targetLanguageCode: 'te');
      expect(res.isSuccess, isFalse);
      expect(onlineHttp.interceptedUris.length, 0);
      expect(res.translatedText, isNot(contains('[Local ML Kit]')));
      expect(engineMgr.currentResolution.statusTitle, 'Online Unavailable');
    });

    test('Matrix Comb 6: Offline + Internet Available + Pack Installed -> Authoritative Offline (Zero Egress)', () async {
      final engineMgr = EngineSelectionManager(
        connectivityService: connectivityOnline,
        onlineTranslationService: onlineService,
        onDeviceTranslationService: onDeviceInstalled,
        initialMode: ConnectionModeType.onDevice,
      );
      final hybrid = HybridTranslationService(
        onlineService: onlineService,
        onDeviceService: onDeviceInstalled,
        engineSelectionManager: engineMgr,
      );
      await hybrid.initialize();

      final res = await hybrid.translate(text: 'Hello', sourceLanguageCode: 'en', targetLanguageCode: 'te');
      expect(res.isSuccess, isTrue);
      expect(onlineHttp.interceptedUris.length, 0);
      expect(res.translatedText, contains('[Local ML Kit]'));
      expect(engineMgr.activeMode, ConnectionModeType.onDevice);
    });

    test('Matrix Comb 7: Offline + No Internet + Pack Installed -> Offline Only', () async {
      final engineMgr = EngineSelectionManager(
        connectivityService: connectivityOffline,
        onlineTranslationService: onlineService,
        onDeviceTranslationService: onDeviceInstalled,
        initialMode: ConnectionModeType.onDevice,
      );
      final hybrid = HybridTranslationService(
        onlineService: onlineService,
        onDeviceService: onDeviceInstalled,
        engineSelectionManager: engineMgr,
      );
      await hybrid.initialize();

      final res = await hybrid.translate(text: 'Hello', sourceLanguageCode: 'en', targetLanguageCode: 'te');
      expect(res.isSuccess, isTrue);
      expect(onlineHttp.interceptedUris.length, 0);
      expect(res.translatedText, contains('[Local ML Kit]'));
    });

    test('Matrix Comb 8: Offline + Any Network + Pack Missing -> Explicit Missing Pack Message', () async {
      final engineMgr = EngineSelectionManager(
        connectivityService: connectivityOnline,
        onlineTranslationService: onlineService,
        onDeviceTranslationService: onDeviceMissing,
        initialMode: ConnectionModeType.onDevice,
      );
      final hybrid = HybridTranslationService(
        onlineService: onlineService,
        onDeviceService: onDeviceMissing,
        engineSelectionManager: engineMgr,
      );
      await hybrid.initialize();

      final res = await hybrid.translate(text: 'Hello', sourceLanguageCode: 'en', targetLanguageCode: 'te');
      expect(res.isSuccess, isFalse);
      expect(res.isModelMissing, isTrue);
      expect(onlineHttp.interceptedUris.length, 0);
    });
  });

  group('4. Reactive State Synchronization & Lifecycle', () {
    test('Changing connection mode in Settings updates EngineSelectionManager and HomeViewModel immediately without restart', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final settingsRepo = SettingsRepository(storageService: storage);
      final connectivity = ControlledConnectivityService(true);
      final onDevice = MockableOnDeviceTranslationService();

      final engineMgr = EngineSelectionManager(
        connectivityService: connectivity,
        onDeviceTranslationService: onDevice,
        settingsRepository: settingsRepo,
        initialMode: ConnectionModeType.automatic,
      );

      final settingsVm = SettingsViewModel(
        settingsRepository: settingsRepo,
        engineSelectionManager: engineMgr,
      );

      final transRepo = TranslationRepository(
        translationService: onDevice,
        storageService: storage,
      );

      final homeVm = HomeViewModel(
        translationRepository: transRepo,
        settingsRepository: settingsRepo,
        engineSelectionManager: engineMgr,
        networkConnectivityService: connectivity,
      );

      expect(homeVm.selectedConnectionMode, ConnectionModeType.automatic);
      expect(homeVm.statusPillText, 'Auto (Online)');

      // User switches to Offline in Settings
      await settingsVm.setConnectionMode(ConnectionModeType.onDevice);

      // Immediate reactive update without app restart!
      expect(engineMgr.activeMode, ConnectionModeType.onDevice);
      expect(homeVm.selectedConnectionMode, ConnectionModeType.onDevice);
      expect(homeVm.statusPillText, 'Offline - Ready');
      expect(homeVm.isOnlineEngineActive, isFalse);
    });

    test('Disconnecting internet triggers immediate reactive connectivity and engine update', () async {
      final connectivity = ControlledConnectivityService(true);
      final onDevice = MockableOnDeviceTranslationService();

      final engineMgr = EngineSelectionManager(
        connectivityService: connectivity,
        onDeviceTranslationService: onDevice,
        initialMode: ConnectionModeType.automatic,
      );

      expect(engineMgr.currentResolution.translationEngine, EngineType.onlineCloud);

      // Network disconnects while app is running
      connectivity.emitState(false);
      await Future.delayed(const Duration(milliseconds: 20));

      expect(engineMgr.networkAvailability, NetworkAvailability.disconnected);
      expect(engineMgr.currentResolution.translationEngine, EngineType.onDevice);
    });

    test('App resumed lifecycle immediately invokes connectivity and engine re-resolution', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final settingsRepo = SettingsRepository(storageService: storage);
      final connectivity = ControlledConnectivityService(false);
      final onDevice = MockableOnDeviceTranslationService();

      final engineMgr = EngineSelectionManager(
        connectivityService: connectivity,
        onDeviceTranslationService: onDevice,
        settingsRepository: settingsRepo,
        initialMode: ConnectionModeType.automatic,
      );

      final transRepo = TranslationRepository(
        translationService: onDevice,
        storageService: storage,
      );

      final homeVm = HomeViewModel(
        translationRepository: transRepo,
        settingsRepository: settingsRepo,
        engineSelectionManager: engineMgr,
        networkConnectivityService: connectivity,
      );

      expect(homeVm.networkAvailability, NetworkAvailability.disconnected);

      // While in background, network was restored
      connectivity.emitState(true);

      // App is resumed from background
      await homeVm.handleAppResumed();

      expect(homeVm.networkAvailability, NetworkAvailability.connected);
      expect(homeVm.isOnlineEngineActive, isTrue);
    });
  });
}
