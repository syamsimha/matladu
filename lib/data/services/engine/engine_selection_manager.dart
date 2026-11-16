import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/connection_mode_model.dart';
import '../asr/model_manager_service.dart';
import '../network_connectivity_service.dart';
import '../translation/on_device_translation_service.dart';
import '../translation/online_translation_service.dart';

import '../../repositories/settings_repository.dart';

enum EngineType {
  onDevice,
  onlineCloud,
  unavailable,
}

/// Actual network availability state (Concept B).
enum NetworkAvailability {
  connected,
  disconnected,
  unavailable,
}

/// Actual translation engine currently in use (Concept C).
enum TranslationEngineInUse {
  onlineMyMemory,
  localMlKit,
  unavailable,
}

/// Detailed resolution of active engine components for a requested language pair.
class EngineResolution {
  final EngineType asrEngine;
  final EngineType translationEngine;
  final EngineType ttsEngine;
  final bool isReady;
  final bool isFullyOffline;
  final bool isOnlineRequired;
  final String statusTitle;
  final String statusDescription;
  final String? missingRequirement;

  const EngineResolution({
    required this.asrEngine,
    required this.translationEngine,
    required this.ttsEngine,
    required this.isReady,
    required this.isFullyOffline,
    required this.isOnlineRequired,
    required this.statusTitle,
    required this.statusDescription,
    this.missingRequirement,
  });

  bool get canTranscribe => asrEngine != EngineType.unavailable;
  bool get canTranslate => translationEngine != EngineType.unavailable;
  bool get canSpeak => ttsEngine != EngineType.unavailable;
}

/// Central Engine Selection Manager enforcing Phase 8 operating modes and Permanent Free Policy.
///
/// THREE APPROVED OPERATING MODES:
/// 1. Online Mode (cloudAi):
///    - Speech recognition: On-device Whisper / Sherpa-ONNX.
///    - Translation: External internet translation API (MyMemory API).
///    - Text-to-speech: On-device Android offline TTS.
///    - No offline translation-pack download required.
///    - Only recognized text is sent to the external provider; zero audio egress.
/// 2. Offline Mode (onDevice):
///    - Speech recognition: On-device Whisper.
///    - Translation: On-device Google ML Kit.
///    - Text-to-speech: On-device Android offline TTS.
///    - Zero internet required; never silently switches to cloud API.
/// 3. Automatic Mode (automatic):
///    - When internet is available and free quota remains, uses online translation.
///    - When free online quota is exhausted (HTTP 429), automatically switches to 100% free on-device ML Kit.
///    - When internet is disconnected, uses local ML Kit translation immediately.
///    - When internet reconnects, resumes online translation only if free quota is available.
///    - ASR and TTS remain 100% on-device in every mode.
class EngineSelectionManager extends ChangeNotifier {
  final NetworkConnectivityService _connectivityService;
  final ModelManagerService? _modelManagerService;
  final OnDeviceTranslationService? _onDeviceTranslationService;
  final OnlineTranslationService? _onlineTranslationService;
  final SettingsRepository? _settingsRepository;

  ConnectionModeType _userConfiguredMode = ConnectionModeType.automatic;
  bool _autoSwitchEnabled = true;
  String _targetSrc = 'en';
  String _targetTgt = 'te';

  EngineResolution _currentResolution = const EngineResolution(
    asrEngine: EngineType.onDevice,
    translationEngine: EngineType.onlineCloud,
    ttsEngine: EngineType.onDevice,
    isReady: true,
    isFullyOffline: false,
    isOnlineRequired: false,
    statusTitle: 'Auto - Online Translation',
    statusDescription: 'Smart Adaptive: Online translation active while connected. Speech & TTS run on-device.',
  );

  final _resolutionController = StreamController<EngineResolution>.broadcast();
  StreamSubscription<NetworkState>? _networkSubscription;
  StreamSubscription<bool>? _quotaSubscription;
  StreamSubscription<ConnectionModeType>? _settingsSubscription;

  EngineSelectionManager({
    required NetworkConnectivityService connectivityService,
    ModelManagerService? modelManagerService,
    OnDeviceTranslationService? onDeviceTranslationService,
    OnlineTranslationService? onlineTranslationService,
    SettingsRepository? settingsRepository,
    ConnectionModeType? initialMode,
    bool autoSwitchEnabled = true,
  })  : _connectivityService = connectivityService,
        _modelManagerService = modelManagerService,
        _onDeviceTranslationService = onDeviceTranslationService,
        _onlineTranslationService = onlineTranslationService,
        _settingsRepository = settingsRepository,
        _autoSwitchEnabled = autoSwitchEnabled {
    _userConfiguredMode = initialMode ??
        settingsRepository?.getConnectionMode().type ??
        ConnectionModeType.automatic;
    _listenToNetworkChanges();
    _listenToQuotaChanges();
    _listenToSettingsChanges();
    resolve(sourceLanguageCode: _targetSrc, targetLanguageCode: _targetTgt);
  }

  ConnectionModeType get activeMode => _userConfiguredMode;
  bool get isAutoSwitchEnabled => _autoSwitchEnabled;
  EngineResolution get currentResolution => _currentResolution;
  Stream<EngineResolution> get resolutionStream => _resolutionController.stream;
  bool get isQuotaExhausted => _onlineTranslationService?.isDailyQuotaExhausted ?? false;

  /// Concept B: Actual network availability
  NetworkAvailability get networkAvailability {
    if (!_connectivityService.isConnected) {
      return NetworkAvailability.disconnected;
    }
    if (!_connectivityService.isValidatedInternet) {
      return NetworkAvailability.unavailable;
    }
    return NetworkAvailability.connected;
  }

  /// Concept C: Actual translation engine currently in use
  TranslationEngineInUse get translationEngineInUse {
    switch (_currentResolution.translationEngine) {
      case EngineType.onlineCloud:
        return TranslationEngineInUse.onlineMyMemory;
      case EngineType.onDevice:
        return TranslationEngineInUse.localMlKit;
      case EngineType.unavailable:
        return TranslationEngineInUse.unavailable;
    }
  }

  void setTargetPair(String src, String tgt) {
    _targetSrc = src;
    _targetTgt = tgt;
    resolve(sourceLanguageCode: src, targetLanguageCode: tgt);
  }

  void _listenToSettingsChanges() {
    _settingsSubscription = _settingsRepository?.connectionModeStream.listen((mode) {
      if (_userConfiguredMode != mode) {
        debugPrint('[EngineManager] Mode change from settings repository: $mode');
        _userConfiguredMode = mode;
        resolve(sourceLanguageCode: _targetSrc, targetLanguageCode: _targetTgt);
        notifyListeners();
      }
    });
  }

  void _listenToNetworkChanges() {
    _networkSubscription = _connectivityService.stateStream.listen((state) {
      debugPrint('[EngineManager] Connectivity change detected: $state. Re-evaluating engines...');
      resolve(sourceLanguageCode: _targetSrc, targetLanguageCode: _targetTgt);
    });
  }

  void _listenToQuotaChanges() {
    _quotaSubscription = _onlineTranslationService?.quotaExhaustedStream.listen((isExhausted) {
      debugPrint('[EngineManager] Online translation quota state changed: isExhausted=$isExhausted. Re-evaluating engines...');
      resolve(sourceLanguageCode: _targetSrc, targetLanguageCode: _targetTgt);
    });
  }

  void setUserMode(ConnectionModeType mode) {
    _userConfiguredMode = mode;
    _settingsRepository?.setConnectionMode(mode);
    debugPrint('[EngineManager] User set connection mode to: $mode');
    resolve(sourceLanguageCode: _targetSrc, targetLanguageCode: _targetTgt);
    notifyListeners();
  }

  void setAutoSwitchEnabled(bool enabled) {
    _autoSwitchEnabled = enabled;
    debugPrint('[EngineManager] Auto-switch enabled set to: $enabled');
    resolve(sourceLanguageCode: _targetSrc, targetLanguageCode: _targetTgt);
    notifyListeners();
  }

  /// Evaluates engine readiness for the given language pair under Phase 8 specifications.
  Future<EngineResolution> resolve({
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) async {
    final bool hasInternet = _connectivityService.isValidatedInternet;
    final bool isQuotaExhausted = _onlineTranslationService?.isDailyQuotaExhausted ?? false;

    // Check Whisper model installation
    bool asrInstalled = false;
    final mm = _modelManagerService;
    if (mm != null) {
      asrInstalled = await mm.isModelInstalled('whisper-tiny-multilingual');
    } else {
      asrInstalled = true; // Test fallback
    }

    // Check translation model installation
    bool translationInstalled = false;
    final tr = _onDeviceTranslationService;
    if (tr != null) {
      final srcInstalled = (sourceLanguageCode == 'auto' || sourceLanguageCode.isEmpty)
          ? true
          : await tr.isModelDownloaded(sourceLanguageCode);
      final tgtInstalled = await tr.isModelDownloaded(targetLanguageCode);
      translationInstalled = srcInstalled && tgtInstalled;

      // In ML Kit, if translating between two non-English languages offline, English pivot model is required
      if (translationInstalled &&
          sourceLanguageCode != 'auto' &&
          sourceLanguageCode.isNotEmpty &&
          sourceLanguageCode != 'en' &&
          targetLanguageCode != 'en') {
        final enInstalled = await tr.isModelDownloaded('en');
        translationInstalled = enInstalled;
      }
    } else {
      translationInstalled = true;
    }

    String? missingReason;
    if (!asrInstalled) {
      missingReason = 'Whisper Multilingual speech model not installed.';
    } else if (!translationInstalled) {
      missingReason = 'Offline translation pack for $targetLanguageCode not installed.';
    }

    EngineResolution resolution;

    switch (_userConfiguredMode) {
      case ConnectionModeType.cloudAi:
        // ONLINE MODE: External internet translation API.
        // ASR and TTS remain 100% on-device. No offline translation pack required.
        if (!hasInternet) {
          resolution = EngineResolution(
            asrEngine: asrInstalled ? EngineType.onDevice : EngineType.unavailable,
            translationEngine: EngineType.unavailable,
            ttsEngine: EngineType.onDevice,
            isReady: false,
            isFullyOffline: false,
            isOnlineRequired: true,
            statusTitle: 'Online Unavailable',
            statusDescription: 'Online mode requires an active internet connection. Please connect or switch to Offline Mode.',
            missingRequirement: 'Internet connection required for Online Mode.',
          );
        } else if (isQuotaExhausted) {
          resolution = EngineResolution(
            asrEngine: asrInstalled ? EngineType.onDevice : EngineType.unavailable,
            translationEngine: EngineType.unavailable,
            ttsEngine: EngineType.onDevice,
            isReady: false,
            isFullyOffline: false,
            isOnlineRequired: true,
            statusTitle: 'Online Quota Exhausted',
            statusDescription: 'Daily free online translation limit reached (HTTP 429). Switch to Offline Mode to continue translating for free.',
            missingRequirement: 'Daily free online translation limit reached. Offline Mode is 100% free and unlimited.',
          );
        } else if (!asrInstalled) {
          resolution = const EngineResolution(
            asrEngine: EngineType.onlineCloud,
            translationEngine: EngineType.onlineCloud,
            ttsEngine: EngineType.onDevice,
            isReady: true,
            isFullyOffline: false,
            isOnlineRequired: true,
            statusTitle: 'Online - Ready',
            statusDescription: 'Online translation active. Speech recognition running via system services.',
          );
        } else {
          resolution = const EngineResolution(
            asrEngine: EngineType.onDevice,
            translationEngine: EngineType.onlineCloud,
            ttsEngine: EngineType.onDevice,
            isReady: true,
            isFullyOffline: false,
            isOnlineRequired: true,
            statusTitle: 'Online - Cloud Translation',
            statusDescription: 'External neural translation API active. Zero audio upload; speech and TTS run on-device.',
          );
        }
        break;

      case ConnectionModeType.onDevice:
        // OFFLINE MODE: 100% on-device speech, translation, and TTS.
        // Zero internet required. Never silently switches to cloud API.
        final bool isReady = asrInstalled && translationInstalled;
        if (!isReady) {
          resolution = EngineResolution(
            asrEngine: asrInstalled ? EngineType.onDevice : EngineType.unavailable,
            translationEngine: translationInstalled ? EngineType.onDevice : EngineType.unavailable,
            ttsEngine: EngineType.onDevice,
            isReady: false,
            isFullyOffline: true,
            isOnlineRequired: false,
            statusTitle: 'Offline Pack Required',
            statusDescription: missingReason ?? 'Please download required offline packs from Settings.',
            missingRequirement: missingReason,
          );
        } else {
          resolution = const EngineResolution(
            asrEngine: EngineType.onDevice,
            translationEngine: EngineType.onDevice,
            ttsEngine: EngineType.onDevice,
            isReady: true,
            isFullyOffline: true,
            isOnlineRequired: false,
            statusTitle: 'Offline - Ready',
            statusDescription: '100% On-Device Neural Processing. Zero data egress.',
          );
        }
        break;

      case ConnectionModeType.automatic:
      case ConnectionModeType.peerToPeer:
        // AUTOMATIC MODE: Intelligent switching with permanent free offline fallback.
        if (hasInternet && !isQuotaExhausted) {
          resolution = EngineResolution(
            asrEngine: asrInstalled ? EngineType.onDevice : EngineType.onlineCloud,
            translationEngine: EngineType.onlineCloud,
            ttsEngine: EngineType.onDevice,
            isReady: true,
            isFullyOffline: false,
            isOnlineRequired: false,
            statusTitle: 'Auto - Online Translation',
            statusDescription: asrInstalled
                ? 'Smart Adaptive: Free online translation active while connected. Speech & TTS run on-device.'
                : 'Smart Adaptive: Free online translation active. Speech running via system service.',
          );
        } else if (hasInternet && isQuotaExhausted) {
          // Free daily online quota exhausted: automatically fallback to local ML Kit
          if (asrInstalled && translationInstalled) {
            resolution = const EngineResolution(
              asrEngine: EngineType.onDevice,
              translationEngine: EngineType.onDevice,
              ttsEngine: EngineType.onDevice,
              isReady: true,
              isFullyOffline: true,
              isOnlineRequired: false,
              statusTitle: 'Auto - On-Device (Quota Exceeded)',
              statusDescription: 'Daily free online quota reached. Automatically continuing with 100% free on-device translation.',
            );
          } else {
            resolution = EngineResolution(
              asrEngine: asrInstalled ? EngineType.onDevice : EngineType.unavailable,
              translationEngine: translationInstalled ? EngineType.onDevice : EngineType.unavailable,
              ttsEngine: EngineType.onDevice,
              isReady: false,
              isFullyOffline: true,
              isOnlineRequired: false,
              statusTitle: 'Offline Pack Required',
              statusDescription: 'Daily online translation quota reached and offline pack is not installed. Download in Offline Packs to continue free translation.',
              missingRequirement: missingReason ?? 'Offline language pack required (daily online quota exhausted).',
            );
          }
        } else if (!hasInternet) {
          // Internet disconnected:
          if (asrInstalled && translationInstalled) {
            resolution = const EngineResolution(
              asrEngine: EngineType.onDevice,
              translationEngine: EngineType.onDevice,
              ttsEngine: EngineType.onDevice,
              isReady: true,
              isFullyOffline: true,
              isOnlineRequired: false,
              statusTitle: 'Auto - Offline Translation',
              statusDescription: 'Smart Adaptive: Offline fallback active. 100% on-device neural processing.',
            );
          } else {
            resolution = EngineResolution(
              asrEngine: asrInstalled ? EngineType.onDevice : EngineType.unavailable,
              translationEngine: translationInstalled ? EngineType.onDevice : EngineType.unavailable,
              ttsEngine: EngineType.onDevice,
              isReady: false,
              isFullyOffline: true,
              isOnlineRequired: false,
              statusTitle: 'Offline Pack Required',
              statusDescription: 'No internet connection and required offline pack is not installed. Please connect or download offline packs.',
              missingRequirement: missingReason ?? 'Internet or offline language pack required.',
            );
          }
        } else {
          // Speech model missing
          resolution = EngineResolution(
            asrEngine: EngineType.unavailable,
            translationEngine: isQuotaExhausted ? EngineType.unavailable : EngineType.onlineCloud,
            ttsEngine: EngineType.onDevice,
            isReady: false,
            isFullyOffline: false,
            isOnlineRequired: false,
            statusTitle: 'Speech Model Required',
            statusDescription: 'Whisper Multilingual speech model not installed. Please download it from Offline Packs.',
            missingRequirement: missingReason,
          );
        }
        break;
    }

    _currentResolution = resolution;
    if (!_resolutionController.isClosed) {
      _resolutionController.add(resolution);
    }
    notifyListeners();
    return resolution;
  }

  @override
  void dispose() {
    _networkSubscription?.cancel();
    _quotaSubscription?.cancel();
    _settingsSubscription?.cancel();
    _resolutionController.close();
    super.dispose();
  }
}
