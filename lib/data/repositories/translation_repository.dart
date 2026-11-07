import '../models/language_model.dart';
import '../models/translation_item_model.dart';
import '../services/local_storage_service.dart';
import '../services/mock_translation_service.dart';

/// Repository managing translation transactions and translation history persistence.
class TranslationRepository {
  final ITranslationService _translationService;
  final LocalStorageService _storageService;

  TranslationRepository({
    required ITranslationService translationService,
    required LocalStorageService storageService,
  })  : _translationService = translationService,
        _storageService = storageService;

  Future<TranslationItemModel> translate({
    required String text,
    required LanguageModel sourceLang,
    required LanguageModel targetLang,
  }) async {
    final result = await _translationService.translate(
      text: text,
      sourceLang: sourceLang,
      targetLang: targetLang,
    );

    // Persist to local history
    await _storageService.saveTranslation(result);
    return result;
  }

  List<TranslationItemModel> getHistory() {
    return _storageService.getTranslationHistory();
  }

  Future<void> clearHistory() async {
    await _storageService.clearHistory();
  }

  Stream<List<double>> getVoiceWaves() {
    return _translationService.listenVoiceWaves();
  }
}

