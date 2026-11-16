import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:matladu_ai/data/models/tts_result.dart';
import 'package:matladu_ai/data/models/tts_voice.dart';
import 'package:matladu_ai/data/repositories/tts_repository.dart';
import 'package:matladu_ai/data/services/local_storage_service.dart';
import 'package:matladu_ai/data/services/tts/i_tts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeTtsService implements ITtsService {
  final StreamController<TtsResult> _controller =
      StreamController<TtsResult>.broadcast();
  TtsPlaybackState _state = TtsPlaybackState.idle;
  String? _currentRequestId;

  final List<String> spokenTexts = [];
  final List<String> spokenLangs = [];
  int stopCalls = 0;
  bool isInitialized = false;

  final List<TtsVoice> offlineVoices = [
    const TtsVoice(
      name: 'en-us-local',
      locale: 'en-US',
      languageCode: 'en',
      isNetworkRequired: false,
    ),
    const TtsVoice(
      name: 'hi-in-local',
      locale: 'hi-IN',
      languageCode: 'hi',
      isNetworkRequired: false,
    ),
  ];

  @override
  Stream<TtsResult> get stateStream => _controller.stream;

  @override
  TtsPlaybackState get currentState => _state;

  @override
  String? get currentRequestId => _currentRequestId;

  @override
  Future<void> initialize() async {
    isInitialized = true;
  }

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
    _currentRequestId = requestId;
    _state = TtsPlaybackState.speaking;
    _controller.add(TtsResult(
      requestId: requestId ?? '',
      state: TtsPlaybackState.speaking,
      text: text,
      languageCode: languageCode,
      voiceName: voice.name,
    ));
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

void main() {
  group('TtsRepository Offline Tests', () {
    late FakeTtsService fakeTtsService;
    late LocalStorageService storageService;
    late TtsRepository ttsRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storageService = LocalStorageService(prefs);
      fakeTtsService = FakeTtsService();
      ttsRepo = TtsRepository(
        ttsService: fakeTtsService,
        storageService: storageService,
      );
      await ttsRepo.initialize();
    });

    tearDown(() async {
      await ttsRepo.dispose();
    });

    test('Initializes successfully and reads default autoPlay setting (true)', () {
      expect(fakeTtsService.isInitialized, isTrue);
      expect(ttsRepo.autoPlayEnabled, isTrue);
      expect(ttsRepo.speechRate, 1.0);
    });

    test('Speaks translated text when autoPlay is enabled', () async {
      final success = await ttsRepo.speakTranslation(
        text: 'Hello, how are you?',
        targetLanguageCode: 'en',
        isAutoPlay: true,
      );

      expect(success, isTrue);
      expect(fakeTtsService.spokenTexts, contains('Hello, how are you?'));
      expect(fakeTtsService.spokenLangs, contains('en'));
      expect(ttsRepo.isSpeaking, isTrue);
    });

    test('Rejects autoPlay if user disabled auto-play setting', () async {
      await ttsRepo.setAutoPlayAudio(false);
      expect(ttsRepo.autoPlayEnabled, isFalse);

      final success = await ttsRepo.speakTranslation(
        text: 'Hello',
        targetLanguageCode: 'en',
        isAutoPlay: true,
      );

      expect(success, isFalse);
      expect(fakeTtsService.spokenTexts.isEmpty, isTrue);
    });

    test('Rejects empty or whitespace-only translation strings', () async {
      final success = await ttsRepo.speakTranslation(
        text: '   ',
        targetLanguageCode: 'en',
      );
      expect(success, isFalse);
      expect(fakeTtsService.spokenTexts.isEmpty, isTrue);
    });

    test('Stops previous speech when new translation arrives', () async {
      await ttsRepo.speakTranslation(
        text: 'First translation sentence',
        targetLanguageCode: 'en',
      );
      expect(fakeTtsService.spokenTexts.length, 1);
      expect(ttsRepo.isSpeaking, isTrue);

      // New translation arrives
      await ttsRepo.speakTranslation(
        text: 'Second translation sentence',
        targetLanguageCode: 'en',
      );

      expect(fakeTtsService.stopCalls, 1,
          reason: 'Previous speech must be stopped before starting new speech');
      expect(fakeTtsService.spokenTexts.length, 2);
    });

    test('Reports voice unavailable when language has no offline voice', () async {
      // Telugu is not in fakeTtsService.offlineVoices
      final success = await ttsRepo.speakTranslation(
        text: 'మీరు ఎలా ఉన్నారు?',
        targetLanguageCode: 'te',
      );

      expect(success, isFalse);
      expect(ttsRepo.currentState, TtsPlaybackState.voiceUnavailable);
    });

    test('Manual stop flags session as user-stopped', () async {
      await ttsRepo.speakTranslation(
        text: 'Speaking sentence',
        targetLanguageCode: 'en',
      );
      expect(ttsRepo.isSpeaking, isTrue);

      await ttsRepo.stop();
      expect(ttsRepo.wasStoppedByUser, isTrue);
      expect(ttsRepo.isSpeaking, isFalse);
    });

    test('Replays current translation manually', () async {
      await ttsRepo.speakTranslation(
        text: 'Original translated line',
        targetLanguageCode: 'hi',
      );

      fakeTtsService.spokenTexts.clear();
      final replaySuccess = await ttsRepo.replayCurrentTranslation();

      expect(replaySuccess, isTrue);
      expect(fakeTtsService.spokenTexts, contains('Original translated line'));
      expect(fakeTtsService.spokenLangs, contains('hi'));
    });
  });
}
