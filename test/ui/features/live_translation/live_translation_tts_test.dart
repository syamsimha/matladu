import 'package:flutter_test/flutter_test.dart';
import 'package:matladu_ai/data/models/asr_state.dart';
import 'package:matladu_ai/data/models/translation_result.dart';
import 'package:matladu_ai/data/repositories/translation_repository.dart';
import 'package:matladu_ai/data/repositories/tts_repository.dart';
import 'package:matladu_ai/data/services/local_storage_service.dart';
import 'package:matladu_ai/data/services/translation/i_translation_service.dart';
import 'package:matladu_ai/ui/features/live_translation/view_models/live_translation_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/services/tts_repository_test.dart';

class FakeTranslationService implements ITranslationService {
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
      translated = 'హలో, మీరు ఎలా ఉన్నారు?';
    } else if (sourceLanguageCode == 'te' && targetLanguageCode == 'en') {
      translated = 'Hello, how are you?';
    } else if (sourceLanguageCode == 'en' && targetLanguageCode == 'hi') {
      translated = 'नमस्कार, आप कैसे हैं?';
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

void main() {
  group('LiveTranslationViewModel Phase 5 Automatic TTS Tests', () {
    late FakeTranslationService fakeTranslationService;
    late FakeTtsService fakeTtsService;
    late LocalStorageService storageService;
    late TranslationRepository translationRepo;
    late TtsRepository ttsRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storageService = LocalStorageService(prefs);
      fakeTranslationService = FakeTranslationService();
      fakeTtsService = FakeTtsService();

      translationRepo = TranslationRepository(
        translationService: fakeTranslationService,
        storageService: storageService,
      );

      ttsRepo = TtsRepository(
        ttsService: fakeTtsService,
        storageService: storageService,
      );
      await ttsRepo.initialize();
    });

    test('Automatically triggers offline TTS playback when translation completes', () async {
      final initialAsr = ASRRecognitionResult(
        text: 'Hello, how are you?',
        detectedLanguageCode: 'en',
        detectedLanguageName: 'English',
        confidence: 0.98,
        audioDuration: const Duration(seconds: 2),
        timestamp: DateTime.now(),
        isFinal: true,
        isMock: false,
      );

      // Create ViewModel targeting Hindi (hi) which is available in fakeTtsService
      final vm = LiveTranslationViewModel(
        initialRecognition: initialAsr,
        translationRepository: translationRepo,
        ttsRepository: ttsRepo,
        initialTargetLanguageCode: 'hi',
      );

      // Allow asynchronous execution to complete
      await Future.delayed(const Duration(milliseconds: 50));

      expect(vm.isTranslationComplete, isTrue);
      expect(vm.translatedText, 'नमस्कार, आप कैसे हैं?');

      // AUTOMATIC PLAYBACK VERIFICATION:
      // Speech synthesis was triggered automatically with NO manual tap on Play button!
      expect(fakeTtsService.spokenTexts, contains('नमस्कार, आप कैसे हैं?'));
      expect(fakeTtsService.spokenLangs, contains('hi'));
      expect(vm.isPlayingAudio, isTrue);
    });

    test('Does not speak if translation string is empty or error', () async {
      final vm = LiveTranslationViewModel(
        initialRecognition: null,
        translationRepository: translationRepo,
        ttsRepository: ttsRepo,
        initialTargetLanguageCode: 'en',
      );

      fakeTtsService.spokenTexts.clear();
      await vm.executeTranslation(text: '', isAutoFlow: true);

      expect(fakeTtsService.spokenTexts.isEmpty, isTrue);
      expect(vm.isPlayingAudio, isFalse);
    });

    test('Replays current translation when user taps Play button while idle', () async {
      final vm = LiveTranslationViewModel(
        initialRecognition: null,
        translationRepository: translationRepo,
        ttsRepository: ttsRepo,
        initialTargetLanguageCode: 'hi',
      );

      await vm.executeTranslation(text: 'Hello', targetCode: 'hi');
      fakeTtsService.spokenTexts.clear();

      // User presses Play Translation manually
      await vm.playTranslation();

      expect(fakeTtsService.spokenTexts, contains('नमस्कार, आप कैसे हैं?'));
    });

    test('Stops playback immediately when user taps center button while audio is playing', () async {
      final vm = LiveTranslationViewModel(
        initialRecognition: null,
        translationRepository: translationRepo,
        ttsRepository: ttsRepo,
        initialTargetLanguageCode: 'hi',
      );

      await vm.executeTranslation(text: 'Hello', targetCode: 'hi', isAutoFlow: true);
      // Wait for stream event to propagate
      await Future.delayed(const Duration(milliseconds: 20));
      expect(vm.isPlayingAudio, isTrue);

      // User taps button while playing -> stops playback immediately
      await vm.playTranslation();
      await Future.delayed(const Duration(milliseconds: 20));

      expect(vm.isPlayingAudio, isFalse);
      expect(fakeTtsService.stopCalls, greaterThanOrEqualTo(1));
    });

    test('Reports voice unavailable when target language voice is missing but preserves translated text', () async {
      // Telugu ('te') is not in fakeTtsService.offlineVoices
      final vm = LiveTranslationViewModel(
        initialRecognition: null,
        translationRepository: translationRepo,
        ttsRepository: ttsRepo,
        initialTargetLanguageCode: 'te',
      );

      await vm.executeTranslation(text: 'Hello', targetCode: 'te', isAutoFlow: true);
      // Wait for stream event to propagate
      await Future.delayed(const Duration(milliseconds: 20));

      // Translated text is kept visible
      expect(vm.translatedText, 'హలో, మీరు ఎలా ఉన్నారు?');
      // Voice unavailable state is flagged
      expect(vm.isTtsVoiceUnavailable, isTrue);
      expect(vm.ttsErrorMessage, isNotNull);
      // Playback did not start
      expect(vm.isPlayingAudio, isFalse);
    });
  });
}
