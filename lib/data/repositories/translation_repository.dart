import 'dart:async';
import '../models/language_model.dart';
import '../models/translation_item_model.dart';
import '../models/translation_result.dart';
import '../services/local_storage_service.dart';
import '../services/translation/i_translation_service.dart';

/// Repository managing on-device translation transactions and translation history persistence.
///
/// STRICTURES:
/// - 100% on-device neural inference.
/// - Zero external cloud translation endpoints.
/// - Preserves local user translation history securely in private storage.
class TranslationRepository {
  final ITranslationService _translationService;
  final LocalStorageService _storageService;

  TranslationRepository({
    required ITranslationService translationService,
    required LocalStorageService storageService,
  })  : _translationService = translationService,
        _storageService = storageService;

  /// Translates [text] on-device from [sourceLanguageCode] to [targetLanguageCode].
  /// Saves successful translations to local history.
  Future<TranslationResult> translateText({
    required String text,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) async {
    final result = await _translationService.translate(
      text: text,
      sourceLanguageCode: sourceLanguageCode,
      targetLanguageCode: targetLanguageCode,
    );

    if (result.isSuccess && result.hasText) {
      final item = TranslationItemModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sourceText: result.originalText,
        translatedText: result.translatedText,
        sourceLanguageCode: result.sourceLanguageCode,
        targetLanguageCode: result.targetLanguageCode,
        timestamp: result.timestamp,
      );
      await _storageService.saveTranslation(item);
    }

    return result;
  }

  /// Translates [text] using [LanguageModel] instances (backward-compatible API).
  Future<TranslationItemModel> translate({
    required String text,
    required LanguageModel sourceLang,
    required LanguageModel targetLang,
  }) async {
    final result = await translateText(
      text: text,
      sourceLanguageCode: sourceLang.code,
      targetLanguageCode: targetLang.code,
    );

    return TranslationItemModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sourceText: result.originalText,
      translatedText: result.isSuccess ? result.translatedText : '',
      sourceLanguageCode: result.sourceLanguageCode,
      targetLanguageCode: result.targetLanguageCode,
      timestamp: result.timestamp,
    );
  }

  /// Checks if an on-device translation model pack is installed for a given language code.
  Future<bool> isModelDownloaded(String languageCode) {
    return _translationService.isModelDownloaded(languageCode);
  }

  /// Downloads an on-device translation model pack when explicitly requested by user.
  Future<bool> downloadModel(
    String languageCode, {
    void Function(double progress)? onProgress,
  }) {
    return _translationService.downloadModel(
      languageCode,
      onProgress: onProgress,
    );
  }

  /// Deletes a local translation model pack to free storage.
  Future<bool> deleteModel(String languageCode) {
    return _translationService.deleteModel(languageCode);
  }

  /// Returns historical translations stored locally on device.
  List<TranslationItemModel> getHistory() {
    return _storageService.getTranslationHistory();
  }

  /// Clears local translation history.
  Future<void> clearHistory() async {
    await _storageService.clearHistory();
  }

  /// Returns audio wave animation data stream.
  Stream<List<double>> getVoiceWaves() {
    return Stream.periodic(const Duration(milliseconds: 100), (count) {
      return [
        (0.3 + 0.5 * (count % 3 == 0 ? 0.8 : 0.4)).clamp(0.1, 1.0),
        (0.5 + 0.4 * (count % 2 == 0 ? 0.9 : 0.3)).clamp(0.1, 1.0),
        (0.8 + 0.2 * (count % 4 == 0 ? 1.0 : 0.5)).clamp(0.1, 1.0),
        (0.4 + 0.5 * (count % 2 == 0 ? 0.7 : 0.2)).clamp(0.1, 1.0),
        (0.6 + 0.3 * (count % 3 == 0 ? 0.6 : 0.3)).clamp(0.1, 1.0),
      ];
    });
  }
}
