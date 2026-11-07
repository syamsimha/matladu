import 'package:flutter/material.dart';
import '../../../../data/models/offline_pack_model.dart';
import '../../../../data/repositories/settings_repository.dart';

/// ViewModel managing state for the Offline Packs Screen (Screen 5).
class OfflinePacksViewModel extends ChangeNotifier {
  final SettingsRepository _settingsRepository;

  OfflinePacksViewModel({required SettingsRepository settingsRepository})
      : _settingsRepository = settingsRepository {
    _loadPacks();
  }

  List<OfflinePackModel> _availablePacks = [];
  List<OfflinePackModel> _downloadedPacks = [];
  final Map<String, bool> _downloadingMap = {};

  List<OfflinePackModel> get availablePacks => _availablePacks;
  List<OfflinePackModel> get downloadedPacks => _downloadedPacks;
  bool isDownloading(String id) => _downloadingMap[id] ?? false;

  void _loadPacks() {
    final allPacks = _settingsRepository.getOfflinePacks();
    _availablePacks = allPacks.where((p) => !p.isDownloaded).toList();
    _downloadedPacks = allPacks.where((p) => p.isDownloaded).toList();

    // Ensure English (Basic) is included as downloaded per reference
    final hasEnglish = _downloadedPacks.any((p) => p.languageCode == 'en');
    if (!hasEnglish) {
      _downloadedPacks.insert(
        0,
        const OfflinePackModel(
          id: 'en',
          languageName: 'English (Basic)',
          languageCode: 'en',
          flagEmoji: '🇺🇸',
          sizeInMB: 20,
          isDownloaded: true,
        ),
      );
    }
    notifyListeners();
  }

  void downloadPack(OfflinePackModel pack) {
    _downloadingMap[pack.id] = true;
    notifyListeners();

    // Simulate download progress
    Future.delayed(const Duration(milliseconds: 1400), () async {
      _downloadingMap[pack.id] = false;
      await _settingsRepository.togglePackDownload(pack.id);
      _loadPacks();
    });
  }

  Future<void> deletePack(String id) async {
    await _settingsRepository.deleteDownloadedPack(id);
    _loadPacks();
  }
}

