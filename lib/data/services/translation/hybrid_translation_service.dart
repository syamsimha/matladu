import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/connection_mode_model.dart';
import '../../models/translation_result.dart';
import '../asr/transcript_validator.dart';
import '../engine/engine_selection_manager.dart';
import 'i_translation_service.dart';
import 'on_device_translation_service.dart';
import 'online_translation_service.dart';

/// Hybrid Translation Service supporting Phase 8 operating modes.
///
/// MODES SUPPORTED:
/// 1. Online Mode (cloudAi): External internet translation API (MyMemory).
///    Speech recognition & TTS remain 100% on-device. Zero audio egress.
/// 2. Offline Mode (onDevice): 100% on-device Google ML Kit neural translation.
///    Zero internet required. Never silently switches to cloud API.
/// 3. Automatic Mode (automatic): Intelligently uses online translation when
///    connected, and on-device translation when offline. If an online request
///    fails mid-request, safely retries locally if offline model is installed.
class HybridTranslationService implements ITranslationService {
  final OnDeviceTranslationService _onDeviceService;
  final OnlineTranslationService _onlineService;
  final EngineSelectionManager _engineSelectionManager;

  final _resultController = StreamController<TranslationResult>.broadcast();
  StreamSubscription<TranslationResult>? _onDeviceSub;
  StreamSubscription<TranslationResult>? _onlineSub;

  HybridTranslationService({
    required OnDeviceTranslationService onDeviceService,
    required OnlineTranslationService onlineService,
    required EngineSelectionManager engineSelectionManager,
  })  : _onDeviceService = onDeviceService,
        _onlineService = onlineService,
        _engineSelectionManager = engineSelectionManager {
    _onDeviceSub = _onDeviceService.resultStream.listen(_resultController.add);
    _onlineSub = _onlineService.resultStream.listen(_resultController.add);
  }

  OnDeviceTranslationService get onDeviceService => _onDeviceService;
  OnlineTranslationService get onlineService => _onlineService;
  EngineSelectionManager get engineSelectionManager => _engineSelectionManager;

  @override
  Stream<TranslationResult> get resultStream => _resultController.stream;

  @override
  Future<void> initialize() async {
    await _onDeviceService.initialize();
    await _onlineService.initialize();
  }

  @override
  bool isLanguageSupported(String languageCode) {
    return _onDeviceService.isLanguageSupported(languageCode) ||
        _onlineService.isLanguageSupported(languageCode);
  }

  @override
  bool isPairSupported(String sourceCode, String targetCode) {
    return isLanguageSupported(sourceCode) && isLanguageSupported(targetCode);
  }

  @override
  Future<bool> isModelDownloaded(String languageCode) {
    return _onDeviceService.isModelDownloaded(languageCode);
  }

  @override
  Future<bool> downloadModel(
    String languageCode, {
    void Function(double progress)? onProgress,
  }) {
    return _onDeviceService.downloadModel(languageCode, onProgress: onProgress);
  }

  @override
  Future<bool> deleteModel(String languageCode) {
    return _onDeviceService.deleteModel(languageCode);
  }

  @override
  Future<TranslationResult> translate({
    required String text,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      return TranslationResult(
        originalText: text,
        translatedText: '',
        sourceLanguageCode: sourceLanguageCode,
        targetLanguageCode: targetLanguageCode,
        status: TranslationStatus.completed,
        timestamp: DateTime.now(),
        isMock: false,
      );
    }

    final normSrc = sourceLanguageCode.toLowerCase().trim().split('-').first.split('_').first;
    final normTgt = targetLanguageCode.toLowerCase().trim().split('-').first.split('_').first;

    // Detect identical-source/target languages and avoid unnecessary API requests
    if (normSrc == normTgt) {
      debugPrint('[HybridTranslationService] Source and target languages are identical ($normSrc == $normTgt). Returning original text directly.');
      return TranslationResult(
        originalText: text,
        translatedText: text,
        sourceLanguageCode: sourceLanguageCode,
        targetLanguageCode: targetLanguageCode,
        status: TranslationStatus.completed,
        timestamp: DateTime.now(),
        isMock: false,
      );
    }

    final resolution = _engineSelectionManager.currentResolution;
    final activeMode = _engineSelectionManager.activeMode;

    // 1. Explicit Offline Mode or Auto Mode resolving to On-Device (e.g. offline or quota exceeded)
    if (activeMode == ConnectionModeType.onDevice ||
        resolution.translationEngine == EngineType.onDevice) {
      debugPrint('[HybridTranslationService] Executing On-Device ML Kit Neural Translation (100% Free Forever).');
      final result = await _onDeviceService.translate(
        text: text,
        sourceLanguageCode: sourceLanguageCode,
        targetLanguageCode: targetLanguageCode,
      );
      if (result.isSuccess && resolution.statusTitle.contains('Quota Exceeded')) {
        return result.copyWith(
          noticeMessage: 'Daily free online translation quota reached. Continued with 100% free on-device translation.',
        );
      }
      return result;
    }

    // 2. Online Mode or Automatic Mode resolving to Cloud:
    if (resolution.translationEngine == EngineType.onlineCloud) {
      debugPrint('[HybridTranslationService] Executing Online Neural Translation via external provider.');
      final result = await _onlineService.translate(
        text: text,
        sourceLanguageCode: sourceLanguageCode,
        targetLanguageCode: targetLanguageCode,
      );

      // If translation succeeded and matches target language script, return result immediately
      if (result.isSuccess && TranscriptValidator.isScriptValidForTarget(result.translatedText, targetLanguageCode)) {
        return result;
      }

      // Automatic Mode Intelligent Fallback:
      // If the request failed (network timeout, connection drop, or HTTP 429 quota exhaustion),
      // safely fallback to local on-device ML Kit model (100% Free Forever).
      if (activeMode == ConnectionModeType.automatic) {
        final bool isOfflineReady = await _onDeviceService.isModelDownloaded(targetLanguageCode);
        if (isOfflineReady) {
          debugPrint(
            '[HybridTranslationService] Auto-Switch: Online request failed. Retrying with local on-device ML Kit model (Free Forever).',
          );
          final localRetryResult = await _onDeviceService.translate(
            text: text,
            sourceLanguageCode: sourceLanguageCode,
            targetLanguageCode: targetLanguageCode,
          );
          if (localRetryResult.isSuccess) {
            final notice = _onlineService.isDailyQuotaExhausted
                ? 'Daily free online translation quota reached. Continued seamlessly with 100% free on-device translation.'
                : 'Online request interrupted. Continued seamlessly with 100% free on-device translation.';
            return localRetryResult.copyWith(noticeMessage: notice);
          }
        } else if (_onlineService.isDailyQuotaExhausted) {
          return TranslationResult.modelMissing(
            text: text,
            sourceLang: sourceLanguageCode,
            targetLang: targetLanguageCode,
            missingLanguageName: targetLanguageCode,
          ).copyWith(
            errorMessage:
                'Daily free online translation quota reached (HTTP 429). Offline pack for $targetLanguageCode is required. Please download it from Offline Packs to continue free translation.',
          );
        }
      }

      // Return original online error result
      return result;
    }

    // 3. Translation Engine is Unavailable
    final errorResult = TranslationResult(
      originalText: text,
      translatedText: '',
      sourceLanguageCode: sourceLanguageCode,
      targetLanguageCode: targetLanguageCode,
      status: TranslationStatus.error,
      errorMessage: resolution.missingRequirement ?? 'Translation engine is unavailable.',
      timestamp: DateTime.now(),
      isMock: false,
    );
    _resultController.add(errorResult);
    return errorResult;
  }

  @override
  Future<void> dispose() async {
    await _onDeviceSub?.cancel();
    await _onlineSub?.cancel();
    await _onDeviceService.dispose();
    await _onlineService.dispose();
    await _resultController.close();
  }
}
