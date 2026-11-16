import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matladu_ai/data/models/asr_state.dart';
import 'package:matladu_ai/data/models/audio_recording_state.dart';
import 'package:matladu_ai/data/models/conversation_turn_model.dart';
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
import 'package:matladu_ai/ui/features/live_translation/view_models/live_translation_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TwoWayFakeTranslationService implements ITranslationService {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> isModelDownloaded(String languageCode) async => true;

  @override
  Future<bool> downloadModel(String languageCode,
      {void Function(double progress)? onProgress}) async => true;

  @override
  Future<bool> deleteModel(String languageCode) async => true;

  @override
  Future<TranslationResult> translate({
    required String text,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) async {
    String translated = 'Translated: $text';
    if (sourceLanguageCode == 'en' && targetLanguageCode == 'te') {
      if (text.contains('hospital')) {
        translated = 'సమీపంలోని ఆసుపత్రి ఎక్కడ ఉంది?';
      } else if (text.contains('Thank')) {
        translated = 'చాలా ధన్యవాదాలు.';
      } else {
        translated = 'నమస్కారం, మీరు ఎలా ఉన్నారు?';
      }
    } else if (sourceLanguageCode == 'te' && targetLanguageCode == 'en') {
      if (text.contains('ఆసుపత్రి')) {
        translated = 'The hospital is two kilometers away.';
      } else {
        translated = 'Hello, how are you?';
      }
    } else if (sourceLanguageCode == 'en' && targetLanguageCode == 'hi') {
      translated = 'नमस्कार, आप कैसे हैं?';
    } else if (sourceLanguageCode == 'hi' && targetLanguageCode == 'en') {
      translated = 'Hello, how are you?';
    }

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

class TwoWayFakeTtsService implements ITtsService {
  final StreamController<TtsResult> _controller = StreamController<TtsResult>.broadcast();
  TtsPlaybackState _state = TtsPlaybackState.idle;
  String? _currentRequestId;

  final List<String> spokenTexts = [];
  final List<String> spokenLangs = [];
  int stopCalls = 0;
  Duration speechDuration = const Duration(milliseconds: 30);

  final List<TtsVoice> offlineVoices = [
    const TtsVoice(
      name: 'en-us-local',
      locale: 'en-US',
      languageCode: 'en',
      isNetworkRequired: false,
      quality: 400,
    ),
    const TtsVoice(
      name: 'te-in-x-teg-local',
      locale: 'te-IN',
      languageCode: 'te',
      isNetworkRequired: false,
      quality: 400,
    ),
    const TtsVoice(
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

    // Automatically complete speech after speechDuration
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

class FakeAudioPermissionService extends AudioPermissionService {
  final AudioPermissionStatus status;
  const FakeAudioPermissionService({this.status = AudioPermissionStatus.granted});

  @override
  Future<AudioPermissionStatus> checkPermission() async => status;

  @override
  Future<AudioPermissionStatus> requestPermission() async => status;
}

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

void main() {
  group('LiveTranslationViewModel Phase 6 Two-Way Conversation Tests', () {
    late TwoWayFakeTranslationService fakeTranslationService;
    late TwoWayFakeTtsService fakeTtsService;
    late SettableMockAsrService mockAsrService;
    late LocalStorageService storageService;
    late TranslationRepository translationRepo;
    late TtsRepository ttsRepo;
    late ASRRepository asrRepo;
    late SettingsRepository settingsRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storageService = LocalStorageService(prefs);
      fakeTranslationService = TwoWayFakeTranslationService();
      fakeTtsService = TwoWayFakeTtsService();
      mockAsrService = SettableMockAsrService();

      final audioRepo = AudioRepository(
        captureService: FakeAudioCaptureService(),
        permissionService: const FakeAudioPermissionService(),
      );

      asrRepo = ASRRepository(
        audioRepository: audioRepo,
        asrService: mockAsrService,
      );

      translationRepo = TranslationRepository(
        translationService: fakeTranslationService,
        storageService: storageService,
      );

      ttsRepo = TtsRepository(
        ttsService: fakeTtsService,
        storageService: storageService,
      );
      await ttsRepo.initialize();

      settingsRepo = SettingsRepository(storageService: storageService);
    });

    test('Turn 1: Person A speaks English -> detects English -> translates to Telugu -> speaks Telugu', () async {
      final initialAsr = ASRRecognitionResult(
        text: 'Where is the nearest hospital?',
        isFinal: true,
        detectedLanguageCode: 'en',
        detectedLanguageName: 'English',
        confidence: 0.98,
        audioDuration: const Duration(seconds: 2),
        timestamp: DateTime.now(),
      );

      final vm = LiveTranslationViewModel(
        initialRecognition: initialAsr,
        translationRepository: translationRepo,
        ttsRepository: ttsRepo,
        asrRepository: asrRepo,
        settingsRepository: settingsRepo,
        initialSourceLanguageCode: 'en',
        initialTargetLanguageCode: 'te',
      );

      await Future.delayed(const Duration(milliseconds: 50));

      expect(vm.originalText, equals('Where is the nearest hospital?'));
      expect(vm.translatedText, equals('సమీపంలోని ఆసుపత్రి ఎక్కడ ఉంది?'));
      expect(vm.sourceLanguageCode, equals('en'));
      expect(vm.targetLanguageCode, equals('te'));
      expect(vm.turnCount, equals(1));

      final turn1 = vm.conversationHistory.first;
      expect(turn1.speaker, equals(ConversationSpeaker.speakerA));
      expect(turn1.sourceLanguageCode, equals('en'));
      expect(turn1.targetLanguageCode, equals('te'));
      expect(turn1.originalText, equals('Where is the nearest hospital?'));
      expect(turn1.translatedText, equals('సమీపంలోని ఆసుపత్రి ఎక్కడ ఉంది?'));

      // Verified automatic TTS for Turn 1 spoke Telugu
      expect(fakeTtsService.spokenTexts, contains('సమీపంలోని ఆసుపత్రి ఎక్కడ ఉంది?'));
    });

    test('Turn 2: Person B responds in Telugu -> detects Telugu -> translates to English -> speaks English', () async {
      final initialAsr = ASRRecognitionResult(
        text: 'Where is the nearest hospital?',
        isFinal: true,
        detectedLanguageCode: 'en',
        detectedLanguageName: 'English',
        confidence: 0.98,
        audioDuration: const Duration(seconds: 2),
        timestamp: DateTime.now(),
      );

      final vm = LiveTranslationViewModel(
        initialRecognition: initialAsr,
        translationRepository: translationRepo,
        ttsRepository: ttsRepo,
        asrRepository: asrRepo,
        settingsRepository: settingsRepo,
        initialSourceLanguageCode: 'en',
        initialTargetLanguageCode: 'te',
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(vm.turnCount, equals(1));

      // Person B speaks Telugu
      mockAsrService.setNextResult(
        ASRRecognitionResult(
          text: 'ఆసుపత్రి రెండు కిలోమీటర్ల దూరంలో ఉంది.',
          isFinal: true,
          detectedLanguageCode: 'te',
          detectedLanguageName: 'Telugu',
          confidence: 0.95,
          audioDuration: const Duration(seconds: 2),
          timestamp: DateTime.now(),
        ),
      );

      // Start recording turn 2
      final started = await vm.startListening();
      expect(started, isTrue);
      expect(vm.isListening, isTrue);
      expect(vm.turnState, equals(ConversationTurnState.listening));

      // Stop recording and process
      await vm.stopListeningAndProcess();
      await Future.delayed(const Duration(milliseconds: 60));

      expect(vm.turnCount, equals(2));
      final turn2 = vm.conversationHistory[1];
      expect(turn2.speaker, equals(ConversationSpeaker.speakerB));
      expect(turn2.sourceLanguageCode, equals('te'));
      expect(turn2.targetLanguageCode, equals('en'));
      expect(turn2.originalText, equals('ఆసుపత్రి రెండు కిలోమీటర్ల దూరంలో ఉంది.'));
      expect(turn2.translatedText, equals('The hospital is two kilometers away.'));

      // Verified automatic TTS for Turn 2 spoke English
      expect(fakeTtsService.spokenTexts, contains('The hospital is two kilometers away.'));
    });

    test('Turn 3: Person A responds in English -> alternates back to Telugu translation and TTS', () async {
      final initialAsr = ASRRecognitionResult(
        text: 'Where is the nearest hospital?',
        isFinal: true,
        detectedLanguageCode: 'en',
        detectedLanguageName: 'English',
        confidence: 0.98,
        audioDuration: const Duration(seconds: 2),
        timestamp: DateTime.now(),
      );

      final vm = LiveTranslationViewModel(
        initialRecognition: initialAsr,
        translationRepository: translationRepo,
        ttsRepository: ttsRepo,
        asrRepository: asrRepo,
        settingsRepository: settingsRepo,
        initialSourceLanguageCode: 'en',
        initialTargetLanguageCode: 'te',
      );

      await Future.delayed(const Duration(milliseconds: 100));

      // Turn 2: Telugu
      mockAsrService.setNextResult(
        ASRRecognitionResult(
          text: 'ఆసుపత్రి రెండు కిలోమీటర్ల దూరంలో ఉంది.',
          isFinal: true,
          detectedLanguageCode: 'te',
          detectedLanguageName: 'Telugu',
          confidence: 0.95,
          audioDuration: const Duration(seconds: 2),
          timestamp: DateTime.now(),
        ),
      );
      await vm.startListening();
      await vm.stopListeningAndProcess();
      await Future.delayed(const Duration(milliseconds: 100));

      // Turn 3: English
      mockAsrService.setNextResult(
        ASRRecognitionResult(
          text: 'Thank you very much.',
          isFinal: true,
          detectedLanguageCode: 'en',
          detectedLanguageName: 'English',
          confidence: 0.97,
          audioDuration: const Duration(seconds: 2),
          timestamp: DateTime.now(),
        ),
      );
      await vm.startListening();
      await vm.stopListeningAndProcess();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(vm.turnCount, equals(3));
      final turn3 = vm.conversationHistory[2];
      expect(turn3.speaker, equals(ConversationSpeaker.speakerA));
      expect(turn3.sourceLanguageCode, equals('en'));
      expect(turn3.targetLanguageCode, equals('te'));
      expect(turn3.originalText, equals('Thank you very much.'));
      expect(turn3.translatedText, equals('చాలా ధన్యవాదాలు.'));

      // Verified automatic TTS for Turn 3 spoke Telugu
      expect(fakeTtsService.spokenTexts, contains('చాలా ధన్యవాదాలు.'));
    });

    test('Microphone lock during TTS prevents acoustic feedback', () async {
      fakeTtsService.speechDuration = const Duration(milliseconds: 20);

      final initialAsr = ASRRecognitionResult(
        text: 'Hello, how are you?',
        isFinal: true,
        detectedLanguageCode: 'en',
        confidence: 0.95,
        audioDuration: const Duration(seconds: 2),
        timestamp: DateTime.now(),
      );

      final vm = LiveTranslationViewModel(
        initialRecognition: initialAsr,
        translationRepository: translationRepo,
        ttsRepository: ttsRepo,
        asrRepository: asrRepo,
        settingsRepository: settingsRepo,
      );

      // Wait for initial auto TTS to finish completely
      await Future.delayed(const Duration(milliseconds: 60));
      expect(vm.isPlayingAudio, isFalse);

      // Now set speech duration for the test to 300ms
      fakeTtsService.speechDuration = const Duration(milliseconds: 300);

      // Start TTS playback
      await vm.playTranslation();
      await Future.delayed(const Duration(milliseconds: 10));

      // While audio is speaking, attempting to record immediately halts playback and avoids acoustic feedback
      expect(vm.isPlayingAudio, isTrue);
      final started = await vm.startListening();
      expect(started, isFalse);
      expect(vm.isListening, isFalse);
      expect(vm.isPlayingAudio, isFalse);
    });

    test('Manual swapDirection swaps source and target cleanly', () async {
      final vm = LiveTranslationViewModel(
        translationRepository: translationRepo,
        ttsRepository: ttsRepo,
        asrRepository: asrRepo,
        initialSourceLanguageCode: 'en',
        initialTargetLanguageCode: 'te',
      );

      expect(vm.sourceLanguageCode, equals('en'));
      expect(vm.targetLanguageCode, equals('te'));

      vm.swapDirection();

      expect(vm.sourceLanguageCode, equals('te'));
      expect(vm.targetLanguageCode, equals('en'));
    });

    test('clearConversationHistory clears turns and resets to idle', () async {
      final initialAsr = ASRRecognitionResult(
        text: 'Test turn',
        isFinal: true,
        detectedLanguageCode: 'en',
        confidence: 0.95,
        audioDuration: const Duration(seconds: 2),
        timestamp: DateTime.now(),
      );

      final vm = LiveTranslationViewModel(
        initialRecognition: initialAsr,
        translationRepository: translationRepo,
        ttsRepository: ttsRepo,
        asrRepository: asrRepo,
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(vm.turnCount, equals(1));

      vm.clearConversationHistory();

      expect(vm.turnCount, equals(0));
      expect(vm.conversationHistory, isEmpty);
      expect(vm.originalText, isEmpty);
      expect(vm.translatedText, isEmpty);
      expect(vm.turnState, equals(ConversationTurnState.idle));
    });

    test('replayTurn replays previous turn audio without clearing history', () async {
      final initialAsr = ASRRecognitionResult(
        text: 'Where is the nearest hospital?',
        isFinal: true,
        detectedLanguageCode: 'en',
        confidence: 0.98,
        audioDuration: const Duration(seconds: 2),
        timestamp: DateTime.now(),
      );

      final vm = LiveTranslationViewModel(
        initialRecognition: initialAsr,
        translationRepository: translationRepo,
        ttsRepository: ttsRepo,
        asrRepository: asrRepo,
        initialTargetLanguageCode: 'te',
      );

      await Future.delayed(const Duration(milliseconds: 50));
      final turn1 = vm.conversationHistory.first;

      fakeTtsService.spokenTexts.clear();
      await vm.replayTurn(turn1);

      expect(fakeTtsService.spokenTexts, contains('సమీపంలోని ఆసుపత్రి ఎక్కడ ఉంది?'));
    });

    test('Third-language detection: Hindi detected when pair is En ⇄ Te displays warning and aborts translation', () async {
      final vm = LiveTranslationViewModel(
        translationRepository: translationRepo,
        ttsRepository: ttsRepo,
        asrRepository: asrRepo,
        settingsRepository: settingsRepo,
        initialSourceLanguageCode: 'en',
        initialTargetLanguageCode: 'te',
      );

      // Third language: Hindi
      mockAsrService.setNextResult(
        ASRRecognitionResult(
          text: 'नमस्ते, आप कैसे हैं?',
          isFinal: true,
          detectedLanguageCode: 'hi',
          detectedLanguageName: 'Hindi',
          confidence: 0.95,
          audioDuration: const Duration(seconds: 2),
          timestamp: DateTime.now(),
        ),
      );

      fakeTtsService.spokenTexts.clear();
      await vm.startListening();
      await vm.stopListeningAndProcess();

      // Warning displayed, translation aborted, pair preserved
      expect(vm.warningMessage, isNotNull);
      expect(vm.warningMessage, contains('Detected Hindi'));
      expect(vm.warningMessage, contains('English to Telugu'));
      expect(vm.translatedText, isEmpty,
          reason: 'Must not generate potentially incorrect translation automatically');
      expect(fakeTtsService.spokenTexts, isEmpty,
          reason: 'Must not speak translation for third language');
      expect(vm.sourceLanguageCode, equals('en'));
      expect(vm.targetLanguageCode, equals('te'));
    });

    test('Uncertain language detection: low confidence displays warning without silently guessing', () async {
      final vm = LiveTranslationViewModel(
        translationRepository: translationRepo,
        ttsRepository: ttsRepo,
        asrRepository: asrRepo,
        settingsRepository: settingsRepo,
        initialSourceLanguageCode: 'en',
        initialTargetLanguageCode: 'te',
      );

      // Uncertain audio
      mockAsrService.setNextResult(
        ASRRecognitionResult(
          text: 'Muffled unclear speech',
          isFinal: true,
          detectedLanguageCode: 'und',
          confidence: 0.15,
          audioDuration: const Duration(seconds: 2),
          timestamp: DateTime.now(),
        ),
      );

      fakeTtsService.spokenTexts.clear();
      await vm.startListening();
      await vm.stopListeningAndProcess();

      expect(vm.warningMessage, isNotNull);
      expect(vm.warningMessage, contains('could not be determined with confidence'));
      expect(vm.translatedText, isEmpty);
      expect(fakeTtsService.spokenTexts, isEmpty);
      expect(vm.sourceLanguageCode, equals('en'));
      expect(vm.targetLanguageCode, equals('te'));
    });
  });
}
