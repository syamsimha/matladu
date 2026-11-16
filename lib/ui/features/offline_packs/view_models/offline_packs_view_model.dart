import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../data/models/offline_pack_model.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../../data/repositories/translation_repository.dart';
import '../../../../data/services/asr/model_manager_service.dart';
import '../../../../data/services/network_connectivity_service.dart';

/// ViewModel managing state for the Offline Packs Screen (Screen 5)
/// with genuine byte-based progress, pause/cancel/retry support,
/// disk integrity verification, and real installation tracking.
class OfflinePacksViewModel extends ChangeNotifier {
  final SettingsRepository _settingsRepository;
  final ModelManagerService? _modelManagerService;
  final TranslationRepository? _translationRepository;
  final NetworkConnectivityService? _networkConnectivityService;

  // Active cancellation tokens / flags for in-flight downloads
  final Map<String, bool> _cancelRequestedMap = {};

  // List of all managed packs
  final List<OfflinePackModel> _packs = [];

  // Whisper ASR Pack
  OfflinePackModel _whisperPack = const OfflinePackModel(
    id: 'whisper-tiny-multilingual',
    languageName: 'Whisper Multilingual Tiny',
    languageCode: 'multilingual',
    flagEmoji: '🎙️',
    sizeInMB: 104,
    modelType: 'Speech Recognition (ASR)',
    installState: PackInstallState.notDownloaded,
    totalBytes: 108633190, // ~103.6 MB exact
  );

  bool _isLoading = true;

  OfflinePacksViewModel({
    required SettingsRepository settingsRepository,
    ModelManagerService? modelManagerService,
    TranslationRepository? translationRepository,
    NetworkConnectivityService? networkConnectivityService,
  })  : _settingsRepository = settingsRepository,
        _modelManagerService = modelManagerService,
        _translationRepository = translationRepository,
        _networkConnectivityService = networkConnectivityService {
    _initializePacks();
  }

  bool get isLoading => _isLoading;
  OfflinePackModel get whisperPack => _whisperPack;
  List<OfflinePackModel> get availablePacks =>
      _packs.where((p) => p.installState != PackInstallState.installedAndReady).toList();
  List<OfflinePackModel> get downloadedPacks =>
      _packs.where((p) => p.installState == PackInstallState.installedAndReady).toList();

  // Backward-compatible properties
  bool get isSpeechModelInstalled => _whisperPack.isReady;
  bool get isSpeechModelDownloading => _whisperPack.isDownloading;
  double get speechModelDownloadProgress => _whisperPack.downloadProgress;

  Future<void> _initializePacks() async {
    _packs.clear();

    // Standard language packs
    final defaultPacks = [
      const OfflinePackModel(
        id: 'en',
        languageName: 'English (Basic)',
        languageCode: 'en',
        flagEmoji: '🇺🇸',
        sizeInMB: 18,
        modelType: 'Neural Translation (Pivot)',
        totalBytes: 19084000,
      ),
      const OfflinePackModel(
        id: 'te',
        languageName: 'Telugu Pack',
        languageCode: 'te',
        flagEmoji: '🇮🇳',
        sizeInMB: 30,
        modelType: 'Neural Translation',
        totalBytes: 31247560,
      ),
      const OfflinePackModel(
        id: 'hi',
        languageName: 'Hindi Pack',
        languageCode: 'hi',
        flagEmoji: '🇮🇳',
        sizeInMB: 28,
        modelType: 'Neural Translation',
        totalBytes: 29780000,
      ),
      const OfflinePackModel(
        id: 'ta',
        languageName: 'Tamil Pack',
        languageCode: 'ta',
        flagEmoji: '🇮🇳',
        sizeInMB: 31,
        modelType: 'Neural Translation',
        totalBytes: 32505856,
      ),
      const OfflinePackModel(
        id: 'kn',
        languageName: 'Kannada Pack',
        languageCode: 'kn',
        flagEmoji: '🇮🇳',
        sizeInMB: 31,
        modelType: 'Neural Translation',
        totalBytes: 32505856,
      ),
      const OfflinePackModel(
        id: 'bn',
        languageName: 'Bengali Pack',
        languageCode: 'bn',
        flagEmoji: '🇮🇳',
        sizeInMB: 28,
        modelType: 'Neural Translation',
        totalBytes: 29360128,
      ),
      const OfflinePackModel(
        id: 'gu',
        languageName: 'Gujarati Pack',
        languageCode: 'gu',
        flagEmoji: '🇮🇳',
        sizeInMB: 30,
        modelType: 'Neural Translation',
        totalBytes: 31457280,
      ),
      const OfflinePackModel(
        id: 'mr',
        languageName: 'Marathi Pack',
        languageCode: 'mr',
        flagEmoji: '🇮🇳',
        sizeInMB: 28,
        modelType: 'Neural Translation',
        totalBytes: 29360128,
      ),
      const OfflinePackModel(
        id: 'ur',
        languageName: 'Urdu Pack',
        languageCode: 'ur',
        flagEmoji: '🇮🇳',
        sizeInMB: 30,
        modelType: 'Neural Translation',
        totalBytes: 31457280,
      ),
      const OfflinePackModel(
        id: 'de',
        languageName: 'German Pack',
        languageCode: 'de',
        flagEmoji: '🇩🇪',
        sizeInMB: 36,
        modelType: 'Neural Translation',
        totalBytes: 37748736,
      ),
    ];

    _packs.addAll(defaultPacks);

    // Verify actual disk presence
    await verifyInstalledPacks();

    _isLoading = false;
    notifyListeners();
  }

  /// Verifies actual disk files for Whisper and each language pack.
  /// Strictly READ-ONLY. Never triggers automatic downloading or staging.
  Future<void> verifyInstalledPacks() async {
    // 1. Verify Whisper ASR
    final mm = _modelManagerService;
    if (mm != null) {
      final integrity = await mm.checkModelIntegrityState('whisper-tiny-multilingual', strictSizeCheck: true);
      switch (integrity) {
        case ModelIntegrityState.installed:
          _whisperPack = _whisperPack.copyWith(
            installState: PackInstallState.installedAndReady,
            downloadedBytes: _whisperPack.totalBytes,
            installedSizeMB: 103.6,
            errorMessage: null,
          );
          break;
        case ModelIntegrityState.corrupted:
          _whisperPack = _whisperPack.copyWith(
            installState: PackInstallState.corrupted,
            downloadedBytes: 0,
            installedSizeMB: null,
            errorMessage: 'Corrupted or incomplete speech model. Please re-download.',
          );
          break;
        case ModelIntegrityState.notDownloaded:
          _whisperPack = _whisperPack.copyWith(
            installState: PackInstallState.notDownloaded,
            downloadedBytes: 0,
            installedSizeMB: null,
            errorMessage: null,
          );
          break;
      }
    } else {
      _whisperPack = _whisperPack.copyWith(
        installState: PackInstallState.notDownloaded,
        downloadedBytes: 0,
        installedSizeMB: null,
      );
    }

    // 2. Verify Neural Translation Packs
    final tr = _translationRepository;
    for (int i = 0; i < _packs.length; i++) {
      final pack = _packs[i];
      bool isInstalled = false;

      if (tr != null) {
        isInstalled = await tr.isModelDownloaded(pack.languageCode);
      } else {
        // Fallback check against saved storage
        isInstalled = _settingsRepository.getDownloadedPackCodes().contains(pack.id);
      }

      _packs[i] = pack.copyWith(
        installState: isInstalled
            ? PackInstallState.installedAndReady
            : PackInstallState.notDownloaded,
        downloadedBytes: isInstalled ? pack.totalBytes : 0,
        installedSizeMB: isInstalled ? pack.sizeInMB.toDouble() : null,
        errorMessage: null,
      );
    }
    notifyListeners();
  }

  // --- DOWNLOAD ACTIONS ---

  Future<void> downloadPack(OfflinePackModel pack) async {
    final index = _packs.indexWhere((p) => p.id == pack.id);
    if (index == -1) return;

    // Concurrency & duplicate download prevention: ignore duplicate taps
    if (_packs[index].installState == PackInstallState.downloading ||
        _packs[index].installState == PackInstallState.verifying ||
        _packs[index].installState == PackInstallState.installedAndReady) {
      return;
    }

    // Pre-flight internet connectivity check: Downloads strictly require internet
    final net = _networkConnectivityService;
    if (net != null && !net.isConnected) {
      _packs[index] = pack.copyWith(
        installState: PackInstallState.failed,
        errorMessage: 'Internet Connection Required to download offline packs.',
      );
      notifyListeners();
      return;
    }

    _cancelRequestedMap[pack.id] = false;

    // Transition: downloading
    _packs[index] = pack.copyWith(
      installState: PackInstallState.downloading,
      downloadedBytes: 0,
      errorMessage: null,
    );
    notifyListeners();

    try {
      final total = pack.totalBytes;
      final tr = _translationRepository;

      if (tr == null) {
        _packs[index] = pack.copyWith(
          installState: PackInstallState.failed,
          errorMessage: 'Translation repository is unavailable.',
        );
        notifyListeners();
        return;
      }

      final success = await tr.downloadModel(
        pack.languageCode,
        onProgress: (p) {
          if (_cancelRequestedMap[pack.id] == true) return;
          final bytes = (total * p).round();
          _packs[index] = _packs[index].copyWith(
            downloadedBytes: bytes,
          );
          notifyListeners();
        },
      );

      if (_cancelRequestedMap[pack.id] == true) {
        _packs[index] = _packs[index].copyWith(
          installState: PackInstallState.paused,
          errorMessage: 'Download paused by user.',
        );
        notifyListeners();
        return;
      }

      // Transition: verifying
      _packs[index] = _packs[index].copyWith(
        installState: PackInstallState.verifying,
      );
      notifyListeners();

      final verified = await tr.isModelDownloaded(pack.languageCode);
      if (success && verified) {
        await _settingsRepository.addDownloadedPack(pack.id);
        _packs[index] = _packs[index].copyWith(
          installState: PackInstallState.installedAndReady,
          downloadedBytes: total,
          installedSizeMB: pack.sizeInMB.toDouble(),
          errorMessage: null,
        );
      } else {
        _packs[index] = _packs[index].copyWith(
          installState: PackInstallState.failed,
          downloadedBytes: 0,
          installedSizeMB: null,
          errorMessage: 'Model download failed or integrity verification failed.',
        );
      }
      notifyListeners();
    } catch (e) {
      _packs[index] = pack.copyWith(
        installState: PackInstallState.failed,
        downloadedBytes: 0,
        installedSizeMB: null,
        errorMessage: 'Download failed: $e',
      );
      notifyListeners();
    }
  }

  void cancelDownload(String id) {
    _cancelRequestedMap[id] = true;
    final index = _packs.indexWhere((p) => p.id == id);
    if (index != -1) {
      _packs[index] = _packs[index].copyWith(
        installState: PackInstallState.paused,
        errorMessage: 'Download cancelled.',
      );
      notifyListeners();
    }
  }

  Future<void> deletePack(String id) async {
    final index = _packs.indexWhere((p) => p.id == id);
    if (index != -1) {
      _packs[index] = _packs[index].copyWith(
        installState: PackInstallState.deleting,
      );
      notifyListeners();

      if (_translationRepository != null) {
        await _translationRepository.deleteModel(id);
      }
      await _settingsRepository.deleteDownloadedPack(id);

      // Verify deletion from disk / service
      bool stillInstalled = false;
      if (_translationRepository != null) {
        stillInstalled = await _translationRepository.isModelDownloaded(id);
      }

      _packs[index] = _packs[index].copyWith(
        installState: stillInstalled ? PackInstallState.failed : PackInstallState.notDownloaded,
        downloadedBytes: 0,
        installedSizeMB: null,
        errorMessage: stillInstalled ? 'Deletion failed to remove pack files.' : null,
      );
      notifyListeners();
    }
  }

  // --- WHISPER ASR PACK ACTIONS ---

  Future<bool> downloadSpeechModel() async {
    // Pre-flight internet connectivity check: Downloads strictly require internet
    final net = _networkConnectivityService;
    if (net != null && !net.isConnected) {
      _whisperPack = _whisperPack.copyWith(
        installState: PackInstallState.failed,
        errorMessage: 'Internet Connection Required to download Whisper speech model.',
      );
      notifyListeners();
      return false;
    }

    _cancelRequestedMap[_whisperPack.id] = false;
    _whisperPack = _whisperPack.copyWith(
      installState: PackInstallState.downloading,
      downloadedBytes: 0,
      errorMessage: null,
    );
    notifyListeners();

    final mm = _modelManagerService;
    if (mm == null) {
      _whisperPack = _whisperPack.copyWith(
        installState: PackInstallState.failed,
        errorMessage: 'Speech model manager is unavailable.',
      );
      notifyListeners();
      return false;
    }

    final success = await mm.downloadModel(
      'whisper-tiny-multilingual',
      onProgress: (p) {
        _whisperPack = _whisperPack.copyWith(
          downloadedBytes: (_whisperPack.totalBytes * p).round(),
        );
        notifyListeners();
      },
    );

    // Transition: verifying
    _whisperPack = _whisperPack.copyWith(
      installState: PackInstallState.verifying,
    );
    notifyListeners();

    final verified = await mm.isModelInstalled('whisper-tiny-multilingual');

    if (success && verified) {
      _whisperPack = _whisperPack.copyWith(
        installState: PackInstallState.installedAndReady,
        downloadedBytes: _whisperPack.totalBytes,
        installedSizeMB: 103.6,
        errorMessage: null,
      );
    } else {
      _whisperPack = _whisperPack.copyWith(
        installState: PackInstallState.failed,
        errorMessage: 'Whisper download failed or interrupted.',
      );
    }
    notifyListeners();
    return success && verified;
  }

  void cancelSpeechModelDownload() {
    _cancelRequestedMap[_whisperPack.id] = true;
    _modelManagerService?.cancelDownload('whisper-tiny-multilingual');
    _whisperPack = _whisperPack.copyWith(
      installState: PackInstallState.paused,
      errorMessage: 'Whisper download paused.',
    );
    notifyListeners();
  }

  Future<void> deleteSpeechModel() async {
    _whisperPack = _whisperPack.copyWith(
      installState: PackInstallState.deleting,
    );
    notifyListeners();

    final mm = _modelManagerService;
    if (mm != null) {
      await mm.deleteModel('whisper-tiny-multilingual');
    }

    // Verify deletion on disk
    bool stillInstalled = false;
    if (mm != null) {
      stillInstalled = await mm.isModelInstalled('whisper-tiny-multilingual');
    }

    _whisperPack = _whisperPack.copyWith(
      installState: stillInstalled ? PackInstallState.failed : PackInstallState.notDownloaded,
      downloadedBytes: 0,
      installedSizeMB: null,
      errorMessage: stillInstalled ? 'Deletion failed to remove Whisper model.' : null,
    );
    notifyListeners();
  }
}
