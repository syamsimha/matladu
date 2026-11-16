import 'dart:async';
import '../../models/translation_result.dart';

/// Contract defining an on-device machine translation provider.
///
/// NON-NEGOTIABLE REQUIREMENTS:
/// 1. 100% On-Device: Text is never sent over any network socket or cloud API.
/// 2. Audio is never received or processed in this service.
/// 3. Modular: Can support multiple model engines (e.g., ML Kit, IndicTrans2, OPUS-MT).
abstract class ITranslationService {
  /// Asynchronously loads bindings and prepares the on-device translation engine.
  Future<void> initialize();

  /// Checks whether an on-device translation model pack is installed for a given language code.
  Future<bool> isModelDownloaded(String languageCode);

  /// Downloads an on-device translation model bundle when explicitly requested by user.
  Future<bool> downloadModel(
    String languageCode, {
    void Function(double progress)? onProgress,
  });

  /// Deletes a local on-device translation model pack to free storage.
  Future<bool> deleteModel(String languageCode);

  /// Translates [text] locally from [sourceLanguageCode] to [targetLanguageCode].
  Future<TranslationResult> translate({
    required String text,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  });

  /// Checks if a language is supported by the on-device translation engine.
  bool isLanguageSupported(String languageCode);

  /// Checks if a language pair is supported.
  bool isPairSupported(String sourceCode, String targetCode);

  /// Stream of translation results emitted by the engine.
  Stream<TranslationResult> get resultStream;

  /// Releases loaded neural models and cleans up native resources.
  Future<void> dispose();
}

