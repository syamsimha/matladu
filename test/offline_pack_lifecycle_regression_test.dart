import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:matladu_ai/data/models/audio_recording_state.dart';
import 'package:matladu_ai/data/models/connection_mode_model.dart';
import 'package:matladu_ai/data/models/language_model.dart';
import 'package:matladu_ai/data/models/offline_pack_model.dart';
import 'package:matladu_ai/data/repositories/asr_repository.dart';
import 'package:matladu_ai/data/repositories/audio_repository.dart';
import 'package:matladu_ai/data/repositories/settings_repository.dart';
import 'package:matladu_ai/data/repositories/translation_repository.dart';
import 'package:matladu_ai/data/services/asr/mock_asr_service.dart';
import 'package:matladu_ai/data/services/asr/model_manager_service.dart';
import 'package:matladu_ai/data/services/audio_capture_service.dart';
import 'package:matladu_ai/data/services/audio_permission_service.dart';
import 'package:matladu_ai/data/services/local_storage_service.dart';
import 'package:matladu_ai/data/services/network_connectivity_service.dart';
import 'package:matladu_ai/data/services/translation/on_device_translation_service.dart';
import 'package:matladu_ai/ui/features/home/view_models/home_view_model.dart';
import 'package:matladu_ai/ui/features/offline_packs/view_models/offline_packs_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAudioPermissionService implements IAudioPermissionService {
  const FakeAudioPermissionService();
  @override
  Future<AudioPermissionStatus> checkPermission() async => AudioPermissionStatus.granted;
  @override
  Future<AudioPermissionStatus> requestPermission() async => AudioPermissionStatus.granted;
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<bool> openSettings() async => true;
}

class FakeAudioCaptureService implements IAudioCaptureService {
  @override
  Stream<Uint8List> get audioStream => const Stream.empty();
  @override
  Stream<double> get amplitudeStream => const Stream.empty();
  @override
  Stream<AudioCaptureState> get stateStream => const Stream.empty();
  @override
  AudioCaptureState get currentState => AudioCaptureState.idle;
  @override
  bool get isRecording => false;
  @override
  AudioCaptureConfig get config => const AudioCaptureConfig();
  @override
  Uint8List get capturedAudioBytes => Uint8List(0);
  @override
  int get totalBytesCaptured => 0;
  @override
  Duration get recordingDuration => Duration.zero;
  @override
  Future<bool> startCapture({AudioCaptureConfig? config}) async => true;
  @override
  Future<Uint8List?> stopCapture() async => Uint8List(0);
  @override
  Future<void> cancelCapture() async {}
  @override
  void resetBuffer() {}
  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempModelsDir;
  late ModelManagerService modelManager;
  late LocalStorageService storageService;
  late SettingsRepository settingsRepo;
  late OnDeviceTranslationService translationService;
  late TranslationRepository translationRepo;
  late NetworkConnectivityService connectivityService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = LocalStorageService(prefs);
    settingsRepo = SettingsRepository(storageService: storageService);

    tempModelsDir = await Directory.systemTemp.createTemp('matladu_pack_lifecycle_');
    modelManager = ModelManagerService(overrideBaseDir: tempModelsDir);

    // Initial translation service with empty downloaded codes (fresh install)
    translationService = OnDeviceTranslationService(
      simulatedDownloadedCodes: <String>{},
    );
    await translationService.initialize();

    translationRepo = TranslationRepository(
      translationService: translationService,
      storageService: storageService,
    );

    connectivityService = NetworkConnectivityService();
    // Default to connected for standard verification tests
    connectivityService.updateStateForTesting(const NetworkState(
      isConnected: true,
      isValidated: true,
      isWifi: true,
      isCellular: false,
      type: 'wifi',
    ));
  });

  tearDown(() async {
    await translationService.dispose();
    connectivityService.dispose();
    if (await tempModelsDir.exists()) {
      await tempModelsDir.delete(recursive: true);
    }
  });

  /// Helper to stage mock valid files for a given model in the temp directory.
  Future<void> stageValidMockModelFiles(String modelId) async {
    final meta = ModelManagerService.availableModels.firstWhere((m) => m.id == modelId);
    final modelDir = await modelManager.getModelDirectory(modelId);
    for (final filename in meta.requiredFiles) {
      final file = File('${modelDir.path}/$filename');
      int size = 1024;
      if (modelId == 'whisper-tiny-multilingual') {
        if (filename.contains('tokens')) size = 850 * 1024; // > 100KB
        if (filename.contains('encoder')) size = 13 * 1024 * 1024; // > 5MB
        if (filename.contains('decoder')) size = 90 * 1024 * 1024; // > 50MB
      }
      final sink = file.openWrite();
      sink.add(List.filled(size, 65));
      await sink.flush();
      await sink.close();
    }
  }

  group('1. Whisper ASR Model Lifecycle & Reappearance Prevention', () {
    test('Fresh install initializes Whisper in notDownloaded state without auto-download', () async {
      final vm = OfflinePacksViewModel(
        settingsRepository: settingsRepo,
        modelManagerService: modelManager,
        translationRepository: translationRepo,
        networkConnectivityService: connectivityService,
      );

      // Allow async initialization
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(vm.whisperPack.installState, PackInstallState.notDownloaded);
      expect(vm.whisperPack.isReady, isFalse);
      expect(vm.isSpeechModelInstalled, isFalse);
      expect(vm.whisperPack.downloadedBytes, 0);
    });

    test('Reopening OfflinePacksViewModel does NOT automatically download Whisper', () async {
      // First open
      final vm1 = OfflinePacksViewModel(
        settingsRepository: settingsRepo,
        modelManagerService: modelManager,
        translationRepository: translationRepo,
        networkConnectivityService: connectivityService,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(vm1.whisperPack.installState, PackInstallState.notDownloaded);

      // Reopening screen (new ViewModel instance with same persistent state)
      final vm2 = OfflinePacksViewModel(
        settingsRepository: settingsRepo,
        modelManagerService: modelManager,
        translationRepository: translationRepo,
        networkConnectivityService: connectivityService,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(vm2.whisperPack.installState, PackInstallState.notDownloaded);
      expect(vm2.whisperPack.isDownloading, isFalse);
    });

    test('Deleting Whisper deletes files from disk and persists notDownloaded state', () async {
      // Pre-install Whisper
      await stageValidMockModelFiles('whisper-tiny-multilingual');
      expect(await modelManager.isModelInstalled('whisper-tiny-multilingual'), isTrue);

      final vm = OfflinePacksViewModel(
        settingsRepository: settingsRepo,
        modelManagerService: modelManager,
        translationRepository: translationRepo,
        networkConnectivityService: connectivityService,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(vm.whisperPack.installState, PackInstallState.installedAndReady);

      // User initiates explicit delete
      await vm.deleteSpeechModel();

      // State is notDownloaded
      expect(vm.whisperPack.installState, PackInstallState.notDownloaded);
      expect(vm.whisperPack.isReady, isFalse);

      // Files are absent on disk
      expect(await modelManager.isModelInstalled('whisper-tiny-multilingual'), isFalse);
      final modelDir = Directory('${tempModelsDir.path}/models/asr/whisper-tiny-multilingual');
      expect(await modelDir.exists(), isFalse);

      // Reopening ViewModel MUST preserve deletion
      final reopenedVm = OfflinePacksViewModel(
        settingsRepository: settingsRepo,
        modelManagerService: modelManager,
        translationRepository: translationRepo,
        networkConnectivityService: connectivityService,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(reopenedVm.whisperPack.installState, PackInstallState.notDownloaded);
    });

    test('ModelManagerService.isModelInstalled is strictly read-only and does not create directories', () async {
      const modelId = 'whisper-tiny-multilingual';
      final modelDir = Directory('${tempModelsDir.path}/models/asr/$modelId');
      expect(await modelDir.exists(), isFalse);

      final isInstalled = await modelManager.isModelInstalled(modelId);
      expect(isInstalled, isFalse);
      // Verify directory was NOT created merely by checking status
      expect(await modelDir.exists(), isFalse);
    });
  });

  group('2. Language Pack Lifecycle & English Model Persistence', () {
    test('Fresh install initializes downloadedPackCodes as empty list (no hardcoded en)', () {
      final packs = storageService.getDownloadedPackCodes();
      expect(packs, isEmpty);
      expect(packs.contains('en'), isFalse);
    });

    test('English language pack is notDownloaded by default', () async {
      final vm = OfflinePacksViewModel(
        settingsRepository: settingsRepo,
        modelManagerService: modelManager,
        translationRepository: translationRepo,
        networkConnectivityService: connectivityService,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final enPack = vm.availablePacks.firstWhere((p) => p.id == 'en');
      expect(enPack.installState, PackInstallState.notDownloaded);
      expect(enPack.isReady, isFalse);
      expect(vm.downloadedPacks.any((p) => p.id == 'en'), isFalse);
    });

    test('All Indic language packs (te, hi, ta, kn) are notDownloaded by default', () async {
      final vm = OfflinePacksViewModel(
        settingsRepository: settingsRepo,
        modelManagerService: modelManager,
        translationRepository: translationRepo,
        networkConnectivityService: connectivityService,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      for (final code in ['te', 'hi', 'ta', 'kn']) {
        final pack = vm.availablePacks.firstWhere((p) => p.id == code);
        expect(pack.installState, PackInstallState.notDownloaded);
        expect(pack.isReady, isFalse);
      }
      expect(vm.downloadedPacks, isEmpty);
    });

    test('Downloading and then deleting English removes model and persists deletion', () async {
      final vm = OfflinePacksViewModel(
        settingsRepository: settingsRepo,
        modelManagerService: modelManager,
        translationRepository: translationRepo,
        networkConnectivityService: connectivityService,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final enPack = vm.availablePacks.firstWhere((p) => p.id == 'en');
      await vm.downloadPack(enPack);

      expect(vm.downloadedPacks.any((p) => p.id == 'en'), isTrue);
      expect(settingsRepo.getDownloadedPackCodes().contains('en'), isTrue);

      // Now delete English
      await vm.deletePack('en');

      expect(vm.downloadedPacks.any((p) => p.id == 'en'), isFalse);
      expect(settingsRepo.getDownloadedPackCodes().contains('en'), isFalse);
      expect(await translationRepo.isModelDownloaded('en'), isFalse);

      // Reopening Offline Packs MUST preserve deletion
      final reopenedVm = OfflinePacksViewModel(
        settingsRepository: settingsRepo,
        modelManagerService: modelManager,
        translationRepository: translationRepo,
        networkConnectivityService: connectivityService,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(reopenedVm.downloadedPacks.any((p) => p.id == 'en'), isFalse);
      final reopenedEn = reopenedVm.availablePacks.firstWhere((p) => p.id == 'en');
      expect(reopenedEn.installState, PackInstallState.notDownloaded);
    });

    test('Deleting Telugu pack removes it and preserves deletion upon reopen', () async {
      final vm = OfflinePacksViewModel(
        settingsRepository: settingsRepo,
        modelManagerService: modelManager,
        translationRepository: translationRepo,
        networkConnectivityService: connectivityService,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final tePack = vm.availablePacks.firstWhere((p) => p.id == 'te');
      await vm.downloadPack(tePack);

      expect(vm.downloadedPacks.any((p) => p.id == 'te'), isTrue);

      await vm.deletePack('te');

      expect(vm.downloadedPacks.any((p) => p.id == 'te'), isFalse);
      expect(await translationRepo.isModelDownloaded('te'), isFalse);

      final reopenedVm = OfflinePacksViewModel(
        settingsRepository: settingsRepo,
        modelManagerService: modelManager,
        translationRepository: translationRepo,
        networkConnectivityService: connectivityService,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final reopenedTe = reopenedVm.availablePacks.firstWhere((p) => p.id == 'te');
      expect(reopenedTe.installState, PackInstallState.notDownloaded);
    });
  });

  group('3. Physical Deletion, Disk Absence & Integrity Verification', () {
    test('Empty directory is detected as notDownloaded', () async {
      const modelId = 'whisper-tiny-multilingual';
      final modelDir = await modelManager.getModelDirectory(modelId, createIfMissing: true);
      expect(await modelDir.exists(), isTrue);
      expect(modelDir.listSync(), isEmpty);

      final state = await modelManager.checkModelIntegrityState(modelId);
      expect(state, ModelIntegrityState.notDownloaded);
      expect(await modelManager.isModelInstalled(modelId), isFalse);
    });

    test('Truncated / 0-byte files are detected as corrupted or incomplete', () async {
      const modelId = 'whisper-tiny-multilingual';
      final modelDir = await modelManager.getModelDirectory(modelId, createIfMissing: true);
      // Write truncated files (e.g. 50 bytes instead of 90MB)
      final meta = ModelManagerService.availableModels.firstWhere((m) => m.id == modelId);
      for (final filename in meta.requiredFiles) {
        final f = File('${modelDir.path}/$filename');
        await f.writeAsString('small truncated data');
      }

      final state = await modelManager.checkModelIntegrityState(modelId, strictSizeCheck: true);
      expect(state, ModelIntegrityState.corrupted);
      expect(await modelManager.isModelInstalled(modelId, strictSizeCheck: true), isFalse);

      final vm = OfflinePacksViewModel(
        settingsRepository: settingsRepo,
        modelManagerService: modelManager,
        translationRepository: translationRepo,
        networkConnectivityService: connectivityService,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(vm.whisperPack.installState, PackInstallState.corrupted);
      expect(vm.whisperPack.errorMessage, contains('Corrupted or incomplete'));
    });

    test('deleteModel verifies absence of files on disk', () async {
      await stageValidMockModelFiles('whisper-tiny-multilingual');
      expect(await modelManager.isModelInstalled('whisper-tiny-multilingual'), isTrue);

      final success = await modelManager.deleteModel('whisper-tiny-multilingual');
      expect(success, isTrue);

      final modelDir = Directory('${tempModelsDir.path}/models/asr/whisper-tiny-multilingual');
      expect(await modelDir.exists(), isFalse);
    });
  });

  group('4. Offline Download Restrictions & Pre-Flight Checks', () {
    test('Attempting Whisper download while offline fails immediately with clear error', () async {
      // Disconnect network
      connectivityService.updateStateForTesting(NetworkState.disconnected());

      final vm = OfflinePacksViewModel(
        settingsRepository: settingsRepo,
        modelManagerService: modelManager,
        translationRepository: translationRepo,
        networkConnectivityService: connectivityService,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final result = await vm.downloadSpeechModel();
      expect(result, isFalse);
      expect(vm.whisperPack.installState, PackInstallState.failed);
      expect(vm.whisperPack.errorMessage, contains('Internet Connection Required'));
      expect(vm.whisperPack.downloadedBytes, 0);
    });

    test('Attempting language pack download while offline fails immediately with clear error', () async {
      // Disconnect network
      connectivityService.updateStateForTesting(NetworkState.disconnected());

      final vm = OfflinePacksViewModel(
        settingsRepository: settingsRepo,
        modelManagerService: modelManager,
        translationRepository: translationRepo,
        networkConnectivityService: connectivityService,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final tePack = vm.availablePacks.firstWhere((p) => p.id == 'te');
      await vm.downloadPack(tePack);

      final updatedTe = vm.availablePacks.firstWhere((p) => p.id == 'te');
      expect(updatedTe.installState, PackInstallState.failed);
      expect(updatedTe.errorMessage, contains('Internet Connection Required'));
      expect(updatedTe.downloadedBytes, 0);
    });
  });

  group('5. Voice Recording Pre-Flight with Missing Whisper', () {
    test('HomeViewModel toggleRecording disables capture and requires model when Whisper missing in Offline Mode', () async {
      await settingsRepo.setConnectionMode(ConnectionModeType.onDevice);
      final mockAsr = MockASRService();
      final asrRepo = ASRRepository(
        audioRepository: AudioRepository(
          captureService: FakeAudioCaptureService(),
          permissionService: const FakeAudioPermissionService(),
        ),
        asrService: mockAsr,
      );

      final homeVm = HomeViewModel(
        translationRepository: translationRepo,
        settingsRepository: settingsRepo,
        modelManagerService: modelManager,
        asrRepository: asrRepo,
        networkConnectivityService: connectivityService,
      );

      bool modelRequiredTriggered = false;
      String? requiredModelName;

      final success = await homeVm.toggleRecording(
        onModelRequired: (modelName, sizeMB) {
          modelRequiredTriggered = true;
          requiredModelName = modelName;
        },
      );

      expect(success, isFalse);
      expect(homeVm.isRecording, isFalse);
      expect(modelRequiredTriggered, isTrue);
      expect(requiredModelName, 'Whisper Multilingual Tiny');
      expect(homeVm.audioErrorMessage, contains('Whisper speech model is required'));
    });

    test('HomeViewModel downloadAndInstallSpeechModel fails fast when offline', () async {
      connectivityService.updateStateForTesting(NetworkState.disconnected());

      final homeVm = HomeViewModel(
        translationRepository: translationRepo,
        settingsRepository: settingsRepo,
        modelManagerService: modelManager,
        networkConnectivityService: connectivityService,
      );

      final success = await homeVm.downloadAndInstallSpeechModel();
      expect(success, isFalse);
      expect(homeVm.isSpeechModelDownloading, isFalse);
      expect(homeVm.audioErrorMessage, contains('Internet Connection Required'));
    });
  });

  group('6. Target Language Locking & No Automatic Changes', () {
    test('Auto Detect applies strictly to source language and target never changes', () async {
      await settingsRepo.setSourceLanguage(LanguageModel.fromCode('auto')!);
      await settingsRepo.setTargetLanguage(LanguageModel.fromCode('te')!);

      final homeVm = HomeViewModel(
        translationRepository: translationRepo,
        settingsRepository: settingsRepo,
        networkConnectivityService: connectivityService,
      );

      expect(homeVm.sourceLanguage.code, 'auto');
      expect(homeVm.targetLanguage.code, 'te');

      // Tapping Auto Detect for target is rejected
      await homeVm.setTargetLanguage(LanguageModel.fromCode('auto')!);
      expect(homeVm.targetLanguage.code, 'te'); // Target remained locked
    });
  });
}
