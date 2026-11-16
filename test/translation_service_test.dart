import 'package:flutter_test/flutter_test.dart';
import 'package:matladu_ai/data/models/asr_state.dart';
import 'package:matladu_ai/data/models/language_model.dart';
import 'package:matladu_ai/data/models/translation_result.dart';
import 'package:matladu_ai/data/repositories/translation_repository.dart';
import 'package:matladu_ai/data/services/local_storage_service.dart';
import 'package:matladu_ai/data/services/translation/on_device_translation_service.dart';
import 'package:matladu_ai/data/services/translation/translation_model_manager.dart';
import 'package:matladu_ai/ui/features/live_translation/view_models/live_translation_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late OnDeviceTranslationService translationService;
  late TranslationModelManager modelManager;
  late LocalStorageService storageService;
  late TranslationRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = LocalStorageService(prefs);
    translationService = OnDeviceTranslationService();
    await translationService.initialize();
    modelManager = TranslationModelManager(translationService: translationService);
    repository = TranslationRepository(
      translationService: translationService,
      storageService: storageService,
    );
  });

  tearDown(() async {
    await translationService.dispose();
  });

  group('TranslationResult Model & Data Contract Tests', () {
    test('TranslationResult.empty() returns valid blank state', () {
      final res = TranslationResult.empty(sourceLang: 'en', targetLang: 'te');
      expect(res.originalText, isEmpty);
      expect(res.translatedText, isEmpty);
      expect(res.sourceLanguageCode, 'en');
      expect(res.targetLanguageCode, 'te');
      expect(res.isSuccess, isTrue);
      expect(res.hasText, isFalse);
      expect(res.isMock, isFalse);
    });

    test('TranslationResult.sameLanguage() reflects text directly without inference', () {
      final res = TranslationResult.sameLanguage(
        text: 'Same language text',
        languageCode: 'en',
        languageName: 'English',
      );
      expect(res.originalText, 'Same language text');
      expect(res.translatedText, 'Same language text');
      expect(res.isSameLanguage, isTrue);
      expect(res.isSuccess, isTrue);
      expect(res.isMock, isFalse);
    });

    test('TranslationResult.modelMissing() populates actionable download notice', () {
      final res = TranslationResult.modelMissing(
        text: 'Hello',
        sourceLang: 'en',
        targetLang: 'te',
        missingLanguageName: 'Telugu',
      );
      expect(res.isModelMissing, isTrue);
      expect(res.isSuccess, isFalse);
      expect(res.errorMessage, contains('Offline pack required'));
      expect(res.errorMessage, contains('Telugu'));
    });

    test('TranslationResult.unsupportedPair() reports unsupported pair', () {
      final res = TranslationResult.unsupportedPair(
        text: 'Test',
        sourceLang: 'en',
        targetLang: 'xyz',
      );
      expect(res.status, TranslationStatus.unsupportedPair);
      expect(res.hasError, isTrue);
      expect(res.errorMessage, contains('Unsupported language pair'));
    });

    test('TranslationResult JSON serialization roundtrip', () {
      final res = TranslationResult.success(
        originalText: 'Hello',
        translatedText: 'నమస్కారం',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
        sourceLanguageName: 'English',
        targetLanguageName: 'Telugu',
        duration: const Duration(milliseconds: 120),
        isMock: false,
      );

      final json = res.toJson();
      expect(json['originalText'], 'Hello');
      expect(json['translatedText'], 'నమస్కారం');
      expect(json['sourceLanguageCode'], 'en');
      expect(json['targetLanguageCode'], 'te');
      expect(json['status'], 'completed');
      expect(json['durationMs'], 120);
      expect(json['isMock'], isFalse);
    });
  });

  group('TranslationModelManager Catalog & Metadata Tests', () {
    test('supportedPacks catalog contains major Indian languages and English', () {
      const packs = TranslationModelManager.supportedPacks;
      expect(packs.isNotEmpty, isTrue);

      final te = packs.firstWhere((p) => p.languageCode == 'te');
      expect(te.languageName, 'Telugu Pack');
      expect(te.nativeName, 'తెలుగు');
      expect(te.sizeMB, lessThanOrEqualTo(35));

      final hi = packs.firstWhere((p) => p.languageCode == 'hi');
      expect(hi.languageName, 'Hindi Pack');
      expect(hi.nativeName, 'हिन्दी');

      final en = packs.firstWhere((p) => p.languageCode == 'en');
      expect(en.languageName, 'English (Basic)');
    });

    test('getMetadataForCode resolves metadata by normalized code', () {
      final metaTe = modelManager.getMetadataForCode('te-IN');
      expect(metaTe, isNotNull);
      expect(metaTe!.languageCode, 'te');
      expect(metaTe.languageName, 'Telugu Pack');

      final metaUnknown = modelManager.getMetadataForCode('unknown');
      expect(metaUnknown, isNull);
    });

    test('isPackDownloaded reports local installation status', () async {
      final isEnDownloaded = await modelManager.isPackDownloaded('en');
      expect(isEnDownloaded, isTrue);

      final isTeDownloaded = await modelManager.isPackDownloaded('te');
      expect(isTeDownloaded, isTrue);
    });

    test('getTotalInstalledSizeMB aggregates total on-device pack footprint', () async {
      final totalMB = await modelManager.getTotalInstalledSizeMB();
      expect(totalMB, greaterThan(0));
    });
  });

  group('OnDeviceTranslationService Inference & Execution Tests', () {
    test('isLanguageSupported returns true for Telugu, Hindi, English, Tamil, Kannada', () {
      expect(translationService.isLanguageSupported('en'), isTrue);
      expect(translationService.isLanguageSupported('te'), isTrue);
      expect(translationService.isLanguageSupported('hi'), isTrue);
      expect(translationService.isLanguageSupported('ta'), isTrue);
      expect(translationService.isLanguageSupported('kn'), isTrue);
      expect(translationService.isLanguageSupported('invalid_xyz'), isFalse);
    });

    test('isPairSupported validates bidirectional pairs', () {
      expect(translationService.isPairSupported('en', 'te'), isTrue);
      expect(translationService.isPairSupported('te', 'en'), isTrue);
      expect(translationService.isPairSupported('en', 'hi'), isTrue);
      expect(translationService.isPairSupported('hi', 'en'), isTrue);
      expect(translationService.isPairSupported('en', 'nonexistent'), isFalse);
    });

    test('Translating empty text returns blank completed result immediately', () async {
      final result = await translationService.translate(
        text: '   ',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );

      expect(result.originalText, isEmpty);
      expect(result.translatedText, isEmpty);
      expect(result.isSuccess, isTrue);
    });

    test('Translating same language returns original text with 0ms inference overhead', () async {
      const input = 'This is an identical language sentence.';
      final result = await translationService.translate(
        text: input,
        sourceLanguageCode: 'en',
        targetLanguageCode: 'en',
      );

      expect(result.translatedText, input);
      expect(result.isSameLanguage, isTrue);
      expect(result.isSuccess, isTrue);
      expect(result.duration, Duration.zero);
    });

    test('Translates English to Telugu accurately', () async {
      final result = await translationService.translate(
        text: 'Hello, how are you?',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );

      expect(result.isSuccess, isTrue);
      expect(result.sourceLanguageCode, 'en');
      expect(result.targetLanguageCode, 'te');
      expect(result.translatedText, contains('ఎలా ఉన్నారు'));
      expect(result.isMock, isFalse);
    });

    test('Translates Telugu to English accurately', () async {
      final result = await translationService.translate(
        text: 'నమస్కారం, మీరు ఎలా ఉన్నారు?',
        sourceLanguageCode: 'te',
        targetLanguageCode: 'en',
      );

      expect(result.isSuccess, isTrue);
      expect(result.sourceLanguageCode, 'te');
      expect(result.targetLanguageCode, 'en');
      expect(result.translatedText, 'Hello, how are you?');
      expect(result.isMock, isFalse);
    });

    test('Translates English to Hindi accurately', () async {
      final result = await translationService.translate(
        text: 'Hello, how are you?',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'hi',
      );

      expect(result.isSuccess, isTrue);
      expect(result.sourceLanguageCode, 'en');
      expect(result.targetLanguageCode, 'hi');
      expect(result.translatedText, contains('कैसे हैं'));
      expect(result.isMock, isFalse);
    });

    test('Translates Hindi to English accurately', () async {
      final result = await translationService.translate(
        text: 'नमस्ते, आप कैसे हैं?',
        sourceLanguageCode: 'hi',
        targetLanguageCode: 'en',
      );

      expect(result.isSuccess, isTrue);
      expect(result.sourceLanguageCode, 'hi');
      expect(result.targetLanguageCode, 'en');
      expect(result.translatedText, 'Hello, how are you?');
      expect(result.isMock, isFalse);
    });

    test('resultStream emits completed translation events', () async {
      final emitted = <TranslationResult>[];
      final sub = translationService.resultStream.listen(emitted.add);

      await translationService.translate(
        text: 'Welcome to Matladu AI',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );
      await Future.delayed(const Duration(milliseconds: 50));

      expect(emitted.length, 1);
      expect(emitted.first.originalText, 'Welcome to Matladu AI');
      expect(emitted.first.isSuccess, isTrue);

      await sub.cancel();
    });
  });

  group('TranslationRepository & Persistence Tests', () {
    test('translateText persists successful result to local storage history', () async {
      expect(repository.getHistory(), isEmpty);

      final result = await repository.translateText(
        text: 'Thank you',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );

      expect(result.isSuccess, isTrue);

      final history = repository.getHistory();
      expect(history.length, 1);
      expect(history.first.sourceText, 'Thank you');
      expect(history.first.translatedText, contains('ధన్యవాదాలు'));
    });

    test('clearHistory removes all translation records', () async {
      await repository.translateText(
        text: 'Hello',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );
      expect(repository.getHistory().length, 1);

      await repository.clearHistory();
      expect(repository.getHistory(), isEmpty);
    });

    test('Backward-compatible translate() with LanguageModel works seamlessly', () async {
      final item = await repository.translate(
        text: 'Good morning',
        sourceLang: LanguageModel.fromCode('en')!, // English
        targetLang: LanguageModel.fromCode('te')!, // Telugu
      );

      expect(item.sourceText, 'Good morning');
      expect(item.sourceLanguageCode, 'en');
      expect(item.targetLanguageCode, 'te');
      expect(item.translatedText.isNotEmpty, isTrue);
    });
  });

  group('LiveTranslationViewModel On-Device Neural Integration Tests', () {
    test('Initializes with ASR recognition and executes genuine on-device translation', () async {
      final asr = ASRRecognitionResult(
        text: 'Hello, how are you?',
        isFinal: true,
        confidence: 0.96,
        detectedLanguageCode: 'en',
        detectedLanguageName: 'English',
        audioDuration: const Duration(seconds: 2),
        timestamp: DateTime.now(),
        isMock: false,
      );

      final vm = LiveTranslationViewModel(
        initialRecognition: asr,
        translationRepository: repository,
        initialTargetLanguageCode: 'te',
      );

      // Wait for asynchronous translation execution
      await Future.delayed(const Duration(milliseconds: 120));

      expect(vm.originalText, 'Hello, how are you?');
      expect(vm.sourceLanguageCode, 'en');
      expect(vm.targetLanguageCode, 'te');
      expect(vm.translatedText, contains('ఎలా ఉన్నారు'));
      expect(vm.isTranslationComplete, isTrue);
      expect(vm.isMock, isFalse);
    });

    test('tryAgain() re-triggers on-device translation', () async {
      final vm = LiveTranslationViewModel(
        translationRepository: repository,
        initialTargetLanguageCode: 'te',
      );

      vm.tryAgain();
      await Future.delayed(const Duration(milliseconds: 120));

      expect(vm.isTranslationComplete, isTrue);
      expect(vm.translatedText.isNotEmpty, isTrue);
    });

    test('updateRecognitionResult dynamically re-translates incoming ASR updates', () async {
      final vm = LiveTranslationViewModel(
        translationRepository: repository,
        initialTargetLanguageCode: 'te',
      );

      vm.updateRecognitionResult(
        ASRRecognitionResult(
          text: 'Welcome to Matladu',
          isFinal: true,
          detectedLanguageCode: 'en',
          detectedLanguageName: 'English',
          audioDuration: const Duration(seconds: 3),
          timestamp: DateTime.now(),
          isMock: false,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 120));

      expect(vm.originalText, 'Welcome to Matladu');
      expect(vm.translatedText, contains('మాట్లాడు'));
      expect(vm.isTranslationComplete, isTrue);
      expect(vm.isMock, isFalse);
    });
  });
}
