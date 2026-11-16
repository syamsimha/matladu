import 'dart:async';
import 'package:flutter/foundation.dart';
import 'i_translation_service.dart';

/// Metadata definition for an on-device translation language pack.
class TranslationPackMetadata {
  final String id;
  final String languageCode;
  final String languageName;
  final String nativeName;
  final String flagEmoji;
  final int sizeMB;
  final String modelType;
  final String? sha256Checksum;

  const TranslationPackMetadata({
    required this.id,
    required this.languageCode,
    required this.languageName,
    required this.nativeName,
    required this.flagEmoji,
    required this.sizeMB,
    this.modelType = 'mobile-transformer',
    this.sha256Checksum,
  });
}

/// Manager responsible for discovering, validating, and maintaining local on-device translation model packs.
///
/// Ensures 100% offline neural translation without external cloud dependencies.
class TranslationModelManager {
  final ITranslationService _translationService;

  TranslationModelManager({required ITranslationService translationService})
      : _translationService = translationService;

  /// Catalog of curated on-device translation packs optimized for mobile inference (<35MB per pack).
  static const List<TranslationPackMetadata> supportedPacks = [
    TranslationPackMetadata(
      id: 'en',
      languageCode: 'en',
      languageName: 'English (Basic)',
      nativeName: 'English',
      flagEmoji: '🇺🇸',
      sizeMB: 20,
      modelType: 'mobile-transformer',
    ),
    TranslationPackMetadata(
      id: 'te',
      languageCode: 'te',
      languageName: 'Telugu Pack',
      nativeName: 'తెలుగు',
      flagEmoji: '🇮🇳',
      sizeMB: 25,
      modelType: 'mobile-transformer',
    ),
    TranslationPackMetadata(
      id: 'hi',
      languageCode: 'hi',
      languageName: 'Hindi Pack',
      nativeName: 'हिन्दी',
      flagEmoji: '🇮🇳',
      sizeMB: 28,
      modelType: 'mobile-transformer',
    ),
    TranslationPackMetadata(
      id: 'ta',
      languageCode: 'ta',
      languageName: 'Tamil Pack',
      nativeName: 'தமிழ்',
      flagEmoji: '🇮🇳',
      sizeMB: 30,
      modelType: 'mobile-transformer',
    ),
    TranslationPackMetadata(
      id: 'kn',
      languageCode: 'kn',
      languageName: 'Kannada Pack',
      nativeName: 'ಕನ್ನಡ',
      flagEmoji: '🇮🇳',
      sizeMB: 30,
      modelType: 'mobile-transformer',
    ),
    TranslationPackMetadata(
      id: 'mr',
      languageCode: 'mr',
      languageName: 'Marathi Pack',
      nativeName: 'मराठी',
      flagEmoji: '🇮🇳',
      sizeMB: 28,
      modelType: 'mobile-transformer',
    ),
    TranslationPackMetadata(
      id: 'bn',
      languageCode: 'bn',
      languageName: 'Bengali Pack',
      nativeName: 'বাংলা',
      flagEmoji: '🇮🇳',
      sizeMB: 28,
      modelType: 'mobile-transformer',
    ),
  ];

  /// Checks if a language pack is installed locally on the device.
  Future<bool> isPackDownloaded(String languageCode) async {
    return await _translationService.isModelDownloaded(languageCode);
  }

  /// Explicit user-initiated download of an on-device translation pack.
  Future<bool> downloadPack(
    String languageCode, {
    void Function(double progress)? onProgress,
  }) async {
    debugPrint('[TranslationModelManager] Initiating user download for pack: $languageCode');
    return await _translationService.downloadModel(
      languageCode,
      onProgress: onProgress,
    );
  }

  /// Deletes a local on-device translation pack to release storage.
  Future<bool> deletePack(String languageCode) async {
    debugPrint('[TranslationModelManager] Deleting local pack: $languageCode');
    return await _translationService.deleteModel(languageCode);
  }

  /// Returns metadata for a given language code.
  TranslationPackMetadata? getMetadataForCode(String code) {
    final lower = code.toLowerCase().trim().split('-').first;
    try {
      return supportedPacks.firstWhere(
        (p) => p.languageCode.toLowerCase() == lower,
      );
    } catch (_) {
      return null;
    }
  }

  /// Total installed size in MB of all active packs.
  Future<int> getTotalInstalledSizeMB() async {
    int total = 0;
    for (final pack in supportedPacks) {
      if (await isPackDownloaded(pack.languageCode)) {
        total += pack.sizeMB;
      }
    }
    return total;
  }
}

