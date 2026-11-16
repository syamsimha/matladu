import 'package:flutter_test/flutter_test.dart';
import 'package:matladu_ai/data/models/offline_pack_model.dart';
import 'package:matladu_ai/data/repositories/settings_repository.dart';
import 'package:matladu_ai/data/services/local_storage_service.dart';
import 'package:matladu_ai/ui/features/offline_packs/view_models/offline_packs_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Offline Packs Real-Time Tracking Tests', () {
    test('OfflinePackModel calculates accurate byte progress text and state labels', () {
      const pack = OfflinePackModel(
        id: 'whisper-tiny-multilingual',
        languageName: 'Whisper Multilingual Tiny',
        languageCode: 'multilingual',
        flagEmoji: '🎙️',
        sizeInMB: 104,
        totalBytes: 108633190, // ~103.6 MB
        downloadedBytes: 54316595, // 50%
        installState: PackInstallState.downloading,
      );

      expect(pack.downloadProgress, closeTo(0.5, 0.01));
      expect(pack.progressPercent, equals(50));
      expect(pack.byteProgressText, contains('51.8 / 103.6 MB (50%)'));
      expect(pack.stateBadgeLabel, equals('Downloading 50%'));
      expect(pack.isDownloading, isTrue);
      expect(pack.isDownloaded, isFalse);
    });

    test('Initializes with Whisper Tiny and manages install states', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final settingsRepo = SettingsRepository(storageService: storage);

      final vm = OfflinePacksViewModel(settingsRepository: settingsRepo);

      expect(vm.whisperPack.id, equals('whisper-tiny-multilingual'));
      expect(vm.whisperPack.sizeInMB, equals(104));
      expect(vm.whisperPack.languageName, equals('Whisper Multilingual Tiny'));
    });

    test('PackInstallState includes all required production lifecycles', () {
      expect(PackInstallState.values.length, greaterThanOrEqualTo(8));
      expect(PackInstallState.values, contains(PackInstallState.notDownloaded));
      expect(PackInstallState.values, contains(PackInstallState.downloading));
      expect(PackInstallState.values, contains(PackInstallState.paused));
      expect(PackInstallState.values, contains(PackInstallState.installing));
      expect(PackInstallState.values, contains(PackInstallState.verifying));
      expect(PackInstallState.values, contains(PackInstallState.installedAndReady));
      expect(PackInstallState.values, contains(PackInstallState.deleting));
      expect(PackInstallState.values, contains(PackInstallState.deleted));
      expect(PackInstallState.values, contains(PackInstallState.corrupted));
      expect(PackInstallState.values, contains(PackInstallState.failed));
      expect(PackInstallState.values, contains(PackInstallState.updateAvailable));
    });
  });
}
