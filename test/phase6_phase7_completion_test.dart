import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matladu_ai/data/models/asr_state.dart';
import 'package:matladu_ai/data/models/audio_recording_state.dart';
import 'package:matladu_ai/data/models/language_model.dart';
import 'package:matladu_ai/data/models/room_model.dart';
import 'package:matladu_ai/data/models/translation_result.dart';
import 'package:matladu_ai/data/models/tts_result.dart';
import 'package:matladu_ai/data/models/tts_voice.dart';
import 'package:matladu_ai/data/models/two_way_direction.dart';
import 'package:matladu_ai/data/repositories/asr_repository.dart';
import 'package:matladu_ai/data/repositories/audio_repository.dart';
import 'package:matladu_ai/data/repositories/settings_repository.dart';
import 'package:matladu_ai/data/repositories/translation_repository.dart';
import 'package:matladu_ai/data/repositories/tts_repository.dart';
import 'package:matladu_ai/data/services/asr/mock_asr_service.dart';
import 'package:matladu_ai/data/services/asr/model_manager_service.dart';
import 'package:matladu_ai/data/services/audio_capture_service.dart';
import 'package:matladu_ai/data/services/audio_permission_service.dart';
import 'package:matladu_ai/data/services/local_storage_service.dart';
import 'package:matladu_ai/data/services/translation/i_translation_service.dart';
import 'package:matladu_ai/data/services/tts/i_tts_service.dart';
import 'package:matladu_ai/ui/features/live_translation/view_models/live_translation_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTranslationService implements ITranslationService {
  int callCount = 0;
  final Map<String, String> responses = {
    'en_to_te:Hello, how are you?': 'నమస్కారం, మీరు ఎలా ఉన్నారు?',
    'te_to_en:బాగున్నాను, ధన్యవాదాలు': 'I am fine, thank you',
    'en_to_te:Where is the hospital?': 'ఆసుపత్రి ఎక్కడ ఉంది?',
    'te_to_en:ఇక్కడికి సమీపంలో ఉంది': 'It is nearby here',
    'en_to_te:Thank you very much': 'చాలా ధన్యవాదాలు',
    'en_to_hi:Hello': 'नमस्ते',
    'hi_to_en:नमस्ते': 'Hello',
  };

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
    callCount++;
    final key = '${sourceLanguageCode}_to_$targetLanguageCode:$text';
    final translated = responses[key] ?? '[Translated $targetLanguageCode]: $text';

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
  final List<String> spokenTexts = [];
  final List<String> spokenLangs = [];
  int stopCalls = 0;
  Duration speechDuration = const Duration(milliseconds: 30);

  final List<TtsVoice> offlineVoices = const [
    TtsVoice(
      name: 'en-us-local',
      locale: 'en-US',
      languageCode: 'en',
      isNetworkRequired: false,
      quality: 400,
    ),
    TtsVoice(
      name: 'te-in-x-teg-local',
      locale: 'te-IN',
      languageCode: 'te',
      isNetworkRequired: false,
      quality: 400,
    ),
    TtsVoice(
      name: 'hi-in-local',
      locale: 'hi-IN',
      languageCode: 'hi',
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
  Future<bool> isLanguageSupported(String languageCode) async {
    return offlineVoices.any((v) => v.languageCode == languageCode);
  }

  @override
  Future<bool> isOfflineVoiceAvailable(String languageCode) async {
    return offlineVoices.any((v) => v.languageCode == languageCode);
  }

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
    final voice = await getBestOfflineVoice(languageCode);
    if (voice == null) {
      _state = TtsPlaybackState.voiceUnavailable;
      _controller.add(TtsResult(
        requestId: requestId ?? '',
        state: TtsPlaybackState.voiceUnavailable,
        text: text,
        languageCode: languageCode,
        errorMessage: 'Offline voice unavailable for $languageCode',
      ));
      return false;
    }

    spokenTexts.add(text);
    spokenLangs.add(languageCode);
    final currentReq = requestId ?? '';
    _currentRequestId = currentReq;
    _state = TtsPlaybackState.speaking;
    _controller.add(TtsResult(
      requestId: currentReq,
      state: TtsPlaybackState.speaking,
      text: text,
      languageCode: languageCode,
      voiceName: voice.name,
    ));

    Future.delayed(speechDuration, () {
      if (_state == TtsPlaybackState.speaking && _currentRequestId == currentReq) {
        _state = TtsPlaybackState.completed;
        _controller.add(TtsResult(
          requestId: currentReq,
          state: TtsPlaybackState.completed,
          text: text,
          languageCode: languageCode,
          voiceName: voice.name,
        ));
      }
    });

    return true;
  }

  @override
  Future<bool> stop() async {
    stopCalls++;
    _state = TtsPlaybackState.stopped;
    _controller.add(TtsResult(
      requestId: _currentRequestId ?? '',
      state: TtsPlaybackState.stopped,
      text: '',
      languageCode: '',
    ));
    _state = TtsPlaybackState.idle;
    return true;
  }

  @override
  Future<bool> pause() async {
    _state = TtsPlaybackState.paused;
    _controller.add(TtsResult(
      requestId: _currentRequestId ?? '',
      state: TtsPlaybackState.paused,
      text: '',
      languageCode: '',
    ));
    return true;
  }

  @override
  Future<bool> resume() async => true;

  @override
  Future<void> setSpeechRate(double rate) async {}

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

  late _SettableMockAsrService mockAsr;
  late ASRRepository asrRepo;
  late _FakeTranslationService fakeTranslation;
  late TranslationRepository translationRepo;
  late _FakeTtsService fakeTts;
  late TtsRepository ttsRepo;
  late SettingsRepository settingsRepo;
  late LocalStorageService storageService;
  late Directory tempModelsDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = LocalStorageService(prefs);
    settingsRepo = SettingsRepository(storageService: storageService);

    mockAsr = _SettableMockAsrService();
    final audioCapture = _FakeAudioCaptureService();
    const audioPermission = _FakeAudioPermissionService();
    final audioRepo = AudioRepository(
      captureService: audioCapture,
      permissionService: audioPermission,
    );
    asrRepo = ASRRepository(asrService: mockAsr, audioRepository: audioRepo);

    fakeTranslation = _FakeTranslationService();
    translationRepo = TranslationRepository(
      translationService: fakeTranslation,
      storageService: storageService,
    );

    fakeTts = _FakeTtsService();
    ttsRepo = TtsRepository(
      ttsService: fakeTts,
      storageService: storageService,
    );

    tempModelsDir = await Directory.systemTemp.createTemp('matladu_p6p7_test_');
  });

  tearDown(() async {
    if (await tempModelsDir.exists()) {
      await tempModelsDir.delete(recursive: true);
    }
  });

  group('Phase 6 — Two-Way Conversation & Turn Management', () {
    test('Alternating turns: 5 alternating turns in English ⇄ Telugu', () async {
      final vm = LiveTranslationViewModel(
        translationRepository: translationRepo,
        ttsRepository: ttsRepo,
        asrRepository: asrRepo,
        settingsRepository: settingsRepo,
        initialSourceLanguageCode: 'en',
        initialTargetLanguageCode: 'te',
      );

      // Verify initial configuration
      expect(vm.sourceLanguageCode, 'en');
      expect(vm.targetLanguageCode, 'te');

      final conversationTurns = [
        {'text': 'Hello, how are you?', 'lang': 'en', 'expectedTgt': 'te'},
        {'text': 'బాగున్నాను, ధన్యవాదాలు', 'lang': 'te', 'expectedTgt': 'en'},
        {'text': 'Where is the hospital?', 'lang': 'en', 'expectedTgt': 'te'},
        {'text': 'ఇక్కడికి సమీపంలో ఉంది', 'lang': 'te', 'expectedTgt': 'en'},
        {'text': 'Thank you very much', 'lang': 'en', 'expectedTgt': 'te'},
      ];

      for (int i = 0; i < conversationTurns.length; i++) {
        final step = conversationTurns[i];
        mockAsr.setNextResult(ASRRecognitionResult(
          text: step['text']!,
          isFinal: true,
          detectedLanguageCode: step['lang']!,
          detectedLanguageName: step['lang'] == 'en' ? 'English' : 'Telugu',
          confidence: 0.98,
          audioDuration: const Duration(seconds: 2),
          timestamp: DateTime.now(),
        ));

        if (vm.isPlayingAudio) {
          await vm.stopPlayback(isManual: true);
        }
        fakeTts.spokenTexts.clear();
        await vm.startListening();
        await vm.stopListeningAndProcess();

        for (int w = 0; w < 15 && (vm.isTranslating || vm.translatedText.isEmpty); w++) {
          await Future.delayed(const Duration(milliseconds: 25));
        }
        await Future.delayed(const Duration(milliseconds: 20));

        expect(vm.originalText, equals(step['text']));
        expect(vm.targetLanguageCode, equals(step['expectedTgt']));
        expect(vm.translatedText.isNotEmpty, isTrue);
        expect(fakeTts.spokenTexts, isNotEmpty,
            reason: 'Turn ${i + 1} must automatically trigger TTS playback');
        expect(vm.conversationHistory.length, equals(i + 1));
      }

      expect(vm.conversationHistory.length, equals(5));
      expect(vm.conversationHistory[0].sourceLanguageCode, 'en');
      expect(vm.conversationHistory[1].sourceLanguageCode, 'te');
      expect(vm.conversationHistory[2].sourceLanguageCode, 'en');
      expect(vm.conversationHistory[3].sourceLanguageCode, 'te');
      expect(vm.conversationHistory[4].sourceLanguageCode, 'en');
    });

    test('Alternating turns: English ⇄ Hindi alternation', () async {
      final vm = LiveTranslationViewModel(
        translationRepository: translationRepo,
        ttsRepository: ttsRepo,
        asrRepository: asrRepo,
        settingsRepository: settingsRepo,
        initialSourceLanguageCode: 'en',
        initialTargetLanguageCode: 'hi',
      );

      expect(vm.sourceLanguageCode, 'en');
      expect(vm.targetLanguageCode, 'hi');

      // Turn 1: English -> Hindi
      mockAsr.setNextResult(ASRRecognitionResult(
        text: 'Hello',
        isFinal: true,
        detectedLanguageCode: 'en',
        confidence: 0.99,
        audioDuration: const Duration(seconds: 1),
        timestamp: DateTime.now(),
      ));

      await vm.startListening();
      await vm.stopListeningAndProcess();
      await Future.delayed(const Duration(milliseconds: 60));

      expect(vm.translatedText, equals('नमस्ते'));
      expect(vm.targetLanguageCode, equals('hi'));

      // Turn 2: Hindi -> English
      mockAsr.setNextResult(ASRRecognitionResult(
        text: 'नमस्ते',
        isFinal: true,
        detectedLanguageCode: 'hi',
        confidence: 0.99,
        audioDuration: const Duration(seconds: 1),
        timestamp: DateTime.now(),
      ));

      await vm.startListening();
      await vm.stopListeningAndProcess();
      await Future.delayed(const Duration(milliseconds: 60));

      expect(vm.translatedText, equals('Hello'));
      expect(vm.targetLanguageCode, equals('en'));
      expect(vm.conversationHistory.length, equals(2));
    });

    test('Mic & TTS Coordination: mic cannot capture while TTS is actively speaking (prevents feedback)', () async {
      final vm = LiveTranslationViewModel(
        translationRepository: translationRepo,
        ttsRepository: ttsRepo,
        asrRepository: asrRepo,
        settingsRepository: settingsRepo,
        initialSourceLanguageCode: 'en',
        initialTargetLanguageCode: 'te',
      );

      // Start speech playback
      fakeTts.speechDuration = const Duration(seconds: 2);
      await vm.playTranslation();
      await Future.delayed(const Duration(milliseconds: 10));
      expect(vm.isPlayingAudio, isTrue);

      // Attempting to record during TTS playback must stop TTS and refuse capture
      final started = await vm.startListening();
      expect(started, isFalse);
      expect(vm.isListening, isFalse);
      expect(vm.isPlayingAudio, isFalse);
    });

    test('Rapid mic tap debouncing rejects second tap within 600ms', () async {
      final vm = LiveTranslationViewModel(
        translationRepository: translationRepo,
        ttsRepository: ttsRepo,
        asrRepository: asrRepo,
        settingsRepository: settingsRepo,
      );

      // First tap starts listening
      await vm.toggleConversationRecording();
      expect(vm.isListening, isTrue);

      // Second immediate tap (within <600ms debounce window)
      await vm.toggleConversationRecording();
      // Should still be listening (not immediately toggled or duplicated)
      expect(vm.isListening, isTrue);
    });

    test('Stale request cancellation: superseded turn does not overwrite active turn', () async {
      final vm = LiveTranslationViewModel(
        translationRepository: translationRepo,
        ttsRepository: ttsRepo,
        asrRepository: asrRepo,
        settingsRepository: settingsRepo,
        initialSourceLanguageCode: 'en',
        initialTargetLanguageCode: 'te',
      );

      // Start turn 1 listening
      await vm.startListening();
      final turn1Id = vm.activeTurnId;

      // Start turn 2 listening before turn 1 finishes processing
      await vm.startListening();
      final turn2Id = vm.activeTurnId;
      expect(turn2Id, isNot(equals(turn1Id)));

      // If turn 1's translation arrives late with turnId == turn1Id, it is rejected
      await vm.executeTranslation(
        text: 'Old stale text',
        sourceCode: 'en',
        targetCode: 'te',
        turnId: turn1Id,
      );

      // VM original text is not overwritten with stale turn 1
      expect(vm.originalText, isNot(equals('Old stale text')));
    });

    test('Lifecycle transition: handleAppPaused halts mic capture and TTS playback', () async {
      final vm = LiveTranslationViewModel(
        translationRepository: translationRepo,
        ttsRepository: ttsRepo,
        asrRepository: asrRepo,
        settingsRepository: settingsRepo,
      );

      await vm.startListening();
      expect(vm.isListening, isTrue);

      // Background app
      await vm.handleAppPaused();
      expect(vm.isListening, isFalse);
      expect(vm.currentAudioLevel, equals(0.0));
    });

    test('Stop button interrupts speech output and Replay button restarts it', () async {
      final vm = LiveTranslationViewModel(
        translationRepository: translationRepo,
        ttsRepository: ttsRepo,
        asrRepository: asrRepo,
        settingsRepository: settingsRepo,
        initialSourceLanguageCode: 'en',
        initialTargetLanguageCode: 'te',
      );

      await vm.executeTranslation(
        text: 'Where is the hospital?',
        sourceCode: 'en',
        targetCode: 'te',
        isAutoFlow: false,
      );

      // Start playing
      await vm.playTranslation();
      await Future.delayed(const Duration(milliseconds: 10));
      expect(vm.isPlayingAudio, isTrue);

      // User presses Stop
      await vm.stopPlayback(isManual: true);
      expect(vm.isPlayingAudio, isFalse);
      expect(vm.userManuallyStopped, isTrue);

      // User presses Replay
      fakeTts.spokenTexts.clear();
      await vm.playTranslation();
      expect(fakeTts.spokenTexts, contains('ఆసుపత్రి ఎక్కడ ఉంది?'));
    });
  });

  group('Phase 7 — Offline Intelligence & Packs Verification', () {
    test('ModelManagerService correctly validates model installation on disk', () async {
      final modelService = ModelManagerService(overrideBaseDir: tempModelsDir);
      final meta = ModelManagerService.availableModels.firstWhere(
        (m) => m.id == 'whisper-tiny-multilingual',
      );

      // Initially not installed
      expect(await modelService.isModelInstalled(meta.id), isFalse);

      // Create model directory and required files
      final modelDir = await modelService.getModelDirectory(meta.id);
      for (final filename in meta.requiredFiles) {
        final f = File('${modelDir.path}/$filename');
        await f.writeAsString('mock model weights binary non-empty');
      }

      // Now recognized as installed
      expect(await modelService.isModelInstalled(meta.id), isTrue);

      // If one file is empty (0 bytes), isModelInstalled returns false
      final firstFile = File('${modelDir.path}/${meta.requiredFiles.first}');
      await firstFile.writeAsString('');
      expect(await modelService.isModelInstalled(meta.id), isFalse);
    });

    test('TwoWayDirectionManager preserves language pair when unknown language is spoken', () {
      final langEn = LanguageModel.fromCode('en')!;
      final langTe = LanguageModel.fromCode('te')!;
      final manager = TwoWayDirectionManager(languageA: langEn, languageB: langTe);

      // Speaker speaks French (outside En ⇄ Te)
      final result = manager.resolve(detectedLanguageCode: 'fr', confidence: 0.95);
      expect(result.canTranslate, isFalse);
      expect(result.isOutsidePair, isTrue);
      expect(result.sourceLanguage.code, 'en');
      expect(result.targetLanguage.code, 'te');
    });

    test('Crockford-32 room code format validation', () {
      final roomCode = RoomModel.generateRoomCode();
      expect(roomCode, startsWith('MTL-'));
      final codeBody = roomCode.replaceFirst('MTL-', '');
      expect(codeBody.length, equals(6));
      expect(RegExp(r'^[2-9A-HJ-NP-Z]{6}$').hasMatch(codeBody), isTrue);
      expect(RoomModel.isValidCode(roomCode), isTrue);
    });
  });
}
