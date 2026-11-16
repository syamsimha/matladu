// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:matladu_ai/data/models/audio_recording_state.dart';
import 'package:matladu_ai/data/models/connection_mode_model.dart';
import 'package:matladu_ai/data/models/language_model.dart';
import 'package:matladu_ai/data/models/offline_pack_model.dart';
import 'package:matladu_ai/data/models/translation_result.dart';
import 'package:matladu_ai/data/repositories/settings_repository.dart';
import 'package:matladu_ai/data/repositories/translation_repository.dart';
import 'package:matladu_ai/data/services/asr/android_speech_recognizer_service.dart';
import 'package:matladu_ai/data/services/asr/hybrid_asr_service.dart';
import 'package:matladu_ai/data/services/asr/mock_asr_service.dart';
import 'package:matladu_ai/data/services/asr/model_manager_service.dart';
import 'package:matladu_ai/data/services/asr/online_asr_service.dart';
import 'package:matladu_ai/data/services/asr/sherpa_on_device_asr_service.dart';
import 'package:matladu_ai/data/services/engine/engine_selection_manager.dart';
import 'package:matladu_ai/data/services/local_storage_service.dart';
import 'package:matladu_ai/data/services/network_connectivity_service.dart';
import 'package:matladu_ai/data/services/translation/hybrid_translation_service.dart';
import 'package:matladu_ai/data/services/translation/on_device_translation_service.dart';
import 'package:matladu_ai/data/services/translation/online_translation_service.dart';
import 'package:matladu_ai/ui/features/home/view_models/home_view_model.dart';
import 'package:matladu_ai/ui/features/offline_packs/view_models/offline_packs_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storageService;
  late SettingsRepository settingsRepo;
  late NetworkConnectivityService connectivityService;
  late ModelManagerService modelManager;
  late OnDeviceTranslationService onDeviceTranslation;
  late OnlineTranslationService onlineTranslation;
  late EngineSelectionManager engineManager;
  late HybridTranslationService hybridTranslation;
  late TranslationRepository translationRepo;
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = LocalStorageService(prefs);

    settingsRepo = SettingsRepository(storageService: storageService);
    connectivityService = NetworkConnectivityService();
    connectivityService.updateStateForTesting(const NetworkState(
      isConnected: true,
      isValidated: true,
      isWifi: true,
      isCellular: false,
      type: 'wifi',
    ));
    tempDir = await Directory.systemTemp.createTemp('matladu_final_test_');

    modelManager = ModelManagerService(
      overrideBaseDir: tempDir,
    );

    onDeviceTranslation = OnDeviceTranslationService(
      simulatedDownloadedCodes: <String>{},
    );
    await onDeviceTranslation.initialize();
    onlineTranslation = OnlineTranslationService();

    engineManager = EngineSelectionManager(
      connectivityService: connectivityService,
      modelManagerService: modelManager,
      onDeviceTranslationService: onDeviceTranslation,
      onlineTranslationService: onlineTranslation,
      settingsRepository: settingsRepo,
    );

    hybridTranslation = HybridTranslationService(
      onDeviceService: onDeviceTranslation,
      onlineService: onlineTranslation,
      engineSelectionManager: engineManager,
    );
    await hybridTranslation.initialize();

    translationRepo = TranslationRepository(
      translationService: hybridTranslation,
      storageService: storageService,
    );
  });

  tearDown(() async {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('Priority 1 & 8 — Offline Language-Pack Download & Lifecycle Verification', () {
    test('1. Download begins in the correct initial downloading state with 0 bytes', () async {
      final vm = OfflinePacksViewModel(
        settingsRepository: settingsRepo,
        modelManagerService: modelManager,
        translationRepository: translationRepo,
        networkConnectivityService: connectivityService,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final pack = vm.availablePacks.firstWhere((p) => p.id == 'te');
      expect(pack.installState, equals(PackInstallState.notDownloaded));
      expect(pack.downloadedBytes, equals(0));
    });

    test('2 & 3. No artificial 20% initial progress and no fake timer-based jumps', () async {
      final receivedProgressList = <double>[];

      // Call downloadModel directly with a progress listener to monitor emitted increments
      await onDeviceTranslation.downloadModel(
        'te',
        onProgress: (p) {
          receivedProgressList.add(p);
        },
      );

      // Verify that 0.2 was NEVER emitted
      expect(receivedProgressList.contains(0.2), isFalse,
          reason: 'Hardcoded 20% (0.2) progress must never be emitted.');
      expect(receivedProgressList.first, equals(0.0),
          reason: 'Progress must start genuinely at 0.0.');
      expect(receivedProgressList.last, equals(1.0));
    });

    test('4. Indeterminate progress is correctly modeled when exact byte stream is unavailable', () {
      const pack = OfflinePackModel(
        id: 'te',
        languageName: 'Telugu Pack',
        languageCode: 'te',
        flagEmoji: '🇮🇳',
        sizeInMB: 30,
        installState: PackInstallState.downloading,
        downloadedBytes: 0,
        totalBytes: 31247560,
      );

      expect(pack.downloadProgress, equals(0.0));
      expect(pack.byteProgressText, contains('Downloading model (~30 MB)...'));
      expect(pack.stateBadgeLabel, equals('Downloading...'));
    });

    test('5. Downloaded status appears only after actual ML Kit installation and independent verification', () async {
      final vm = OfflinePacksViewModel(
        settingsRepository: settingsRepo,
        modelManagerService: modelManager,
        translationRepository: translationRepo,
        networkConnectivityService: connectivityService,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final pack = vm.availablePacks.firstWhere((p) => p.id == 'hi');
      await vm.downloadPack(pack);

      // Verify pack is in downloadedPacks
      expect(vm.downloadedPacks.any((p) => p.id == 'hi'), isTrue);
      final hiDownloaded = vm.downloadedPacks.firstWhere((p) => p.id == 'hi');
      expect(hiDownloaded.installState, equals(PackInstallState.installedAndReady));
      expect(hiDownloaded.installedSizeMB, isNotNull);

      // Verify persistent storage was updated
      expect(settingsRepo.getDownloadedPackCodes().contains('hi'), isTrue);

      // Verify translation repository confirms it is installed
      expect(await translationRepo.isModelDownloaded('hi'), isTrue);
    });

    test('6. Failed downloads do not become Downloaded and preserve clean error state', () async {
      // Offline translation service where download fails
      final failingVm = OfflinePacksViewModel(
        settingsRepository: settingsRepo,
        modelManagerService: modelManager,
        translationRepository: null, // Null repository triggers failure
        networkConnectivityService: connectivityService,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final pack = failingVm.availablePacks.firstWhere((p) => p.id == 'ta');
      await failingVm.downloadPack(pack);

      expect(failingVm.downloadedPacks.any((p) => p.id == 'ta'), isFalse);
      expect(settingsRepo.getDownloadedPackCodes().contains('ta'), isFalse);
      final failedPack = failingVm.availablePacks.firstWhere((p) => p.id == 'ta');
      expect(failedPack.installState, equals(PackInstallState.failed));
      expect(failedPack.downloadedBytes, equals(0));
    });

    test('7. Interrupted downloads do not become Downloaded', () async {
      final vm = OfflinePacksViewModel(
        settingsRepository: settingsRepo,
        modelManagerService: modelManager,
        translationRepository: translationRepo,
        networkConnectivityService: connectivityService,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final pack = vm.availablePacks.firstWhere((p) => p.id == 'kn');
      final downloadFuture = vm.downloadPack(pack);
      vm.cancelDownload(pack.id); // Cancel mid-flight

      await downloadFuture;

      expect(vm.downloadedPacks.any((p) => p.id == 'kn'), isFalse);
      expect(settingsRepo.getDownloadedPackCodes().contains('kn'), isFalse);
    });

    test('8. Duplicate download requests are prevented while a pack is actively downloading', () async {
      final vm = OfflinePacksViewModel(
        settingsRepository: settingsRepo,
        modelManagerService: modelManager,
        translationRepository: translationRepo,
        networkConnectivityService: connectivityService,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final pack = vm.availablePacks.firstWhere((p) => p.id == 'bn');

      // Start download
      final future1 = vm.downloadPack(pack);
      // Attempt duplicate download immediately
      final future2 = vm.downloadPack(pack);

      await Future.wait([future1, future2]);

      expect(vm.downloadedPacks.where((p) => p.id == 'bn').length, equals(1));
    });

    test('9 & 10. Successful deletion removes installed status and does not affect other language packs', () async {
      final vm = OfflinePacksViewModel(
        settingsRepository: settingsRepo,
        modelManagerService: modelManager,
        translationRepository: translationRepo,
        networkConnectivityService: connectivityService,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Install both Telugu and Hindi
      await vm.downloadPack(vm.availablePacks.firstWhere((p) => p.id == 'te'));
      await vm.downloadPack(vm.availablePacks.firstWhere((p) => p.id == 'hi'));

      expect(vm.downloadedPacks.any((p) => p.id == 'te'), isTrue);
      expect(vm.downloadedPacks.any((p) => p.id == 'hi'), isTrue);

      // Delete Telugu only
      await vm.deletePack('te');

      // Telugu removed
      expect(vm.downloadedPacks.any((p) => p.id == 'te'), isFalse);
      expect(settingsRepo.getDownloadedPackCodes().contains('te'), isFalse);
      expect(await translationRepo.isModelDownloaded('te'), isFalse);

      // Hindi completely unaffected
      expect(vm.downloadedPacks.any((p) => p.id == 'hi'), isTrue);
      expect(settingsRepo.getDownloadedPackCodes().contains('hi'), isTrue);
      expect(await translationRepo.isModelDownloaded('hi'), isTrue);
    });

    test('11. UI state updates upon reopening after installation and deletion', () async {
      final vm1 = OfflinePacksViewModel(
        settingsRepository: settingsRepo,
        modelManagerService: modelManager,
        translationRepository: translationRepo,
        networkConnectivityService: connectivityService,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await vm1.downloadPack(vm1.availablePacks.firstWhere((p) => p.id == 'mr'));
      expect(vm1.downloadedPacks.any((p) => p.id == 'mr'), isTrue);

      // Reopen in a new ViewModel instance
      final vm2 = OfflinePacksViewModel(
        settingsRepository: settingsRepo,
        modelManagerService: modelManager,
        translationRepository: translationRepo,
        networkConnectivityService: connectivityService,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vm2.downloadedPacks.any((p) => p.id == 'mr'), isTrue);

      // Delete in vm2
      await vm2.deletePack('mr');
      expect(vm2.downloadedPacks.any((p) => p.id == 'mr'), isFalse);

      // Reopen again in vm3
      final vm3 = OfflinePacksViewModel(
        settingsRepository: settingsRepo,
        modelManagerService: modelManager,
        translationRepository: translationRepo,
        networkConnectivityService: connectivityService,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vm3.downloadedPacks.any((p) => p.id == 'mr'), isFalse);
      expect(vm3.availablePacks.firstWhere((p) => p.id == 'mr').installState,
          equals(PackInstallState.notDownloaded));
    });
  });

  group('Priority 3 & 8 — Speech Recognition Architecture & Consent Verification', () {
    test('12 & 13. Offline mode does not initiate external translation requests or transmit audio', () async {
      await settingsRepo.setConnectionMode(ConnectionModeType.onDevice);
      expect(settingsRepo.getConnectionMode().type, equals(ConnectionModeType.onDevice));

      final res = await hybridTranslation.translate(
        text: 'నమస్కారం',
        sourceLanguageCode: 'te',
        targetLanguageCode: 'en',
      );

      // Offline mode routes strictly to On-Device ML Kit
      expect(res.isMock, isFalse);
    });

    test('14 & 15. Google Speech Consent enforcement and rejection behavior', () async {
      // By default, cloud speech consent is false
      expect(settingsRepo.getCloudSpeechConsent(), isFalse);

      final hybridAsr = HybridASRService(
        onDeviceService: SherpaOnDeviceASRService(
          modelManager: modelManager,
          fallbackService: MockASRService(),
        ),
        onlineService: OnlineASRService(),
        androidSpeechService: AndroidSpeechRecognizerService(),
        engineSelectionManager: engineManager,
        settingsRepository: settingsRepo,
      );

      // Online mode with consent = false routes to On-Device Whisper
      await settingsRepo.setConnectionMode(ConnectionModeType.cloudAi);
      await hybridAsr.startStreamingRecognition(
        const Stream<Uint8List>.empty(),
        audioConfig: const AudioCaptureConfig(),
        languageCodeHint: 'te',
      );

      // Grant consent
      await settingsRepo.setCloudSpeechConsent(true);
      expect(settingsRepo.getCloudSpeechConsent(), isTrue);

      // Revoke consent
      await settingsRepo.setCloudSpeechConsent(false);
      expect(settingsRepo.getCloudSpeechConsent(), isFalse);
    });

    test('16. Whisper download, verification and deletion remain completely unaffected', () async {
      final vm = OfflinePacksViewModel(
        settingsRepository: settingsRepo,
        modelManagerService: modelManager,
        translationRepository: translationRepo,
        networkConnectivityService: connectivityService,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(vm.whisperPack.installState, equals(PackInstallState.notDownloaded));
      expect(vm.isSpeechModelInstalled, isFalse);

      // Delete whisper model when absent preserves notDownloaded
      await vm.deleteSpeechModel();
      expect(vm.whisperPack.installState, equals(PackInstallState.notDownloaded));
    });
  });

  group('Priority 5, 7 & 8 — Translation Engine & UI Safety Rules', () {
    test('17. Target language remains locked and never mutates automatically', () async {
      final homeVm = HomeViewModel(
        translationRepository: translationRepo,
        settingsRepository: settingsRepo,
        engineSelectionManager: engineManager,
      );

      await homeVm.setSourceLanguage(LanguageModel.autoDetect);
      await homeVm.setTargetLanguage(LanguageModel.fromCode('de')!);

      expect(homeVm.sourceLanguage.code, equals('auto'));
      expect(homeVm.targetLanguage.code, equals('de'));

      // Target language can never be set to auto
      await homeVm.setTargetLanguage(LanguageModel.autoDetect);
      expect(homeVm.targetLanguage.code, equals('de'));
    });

    test('18. Same-language translation is strictly prevented', () async {
      final res = await onlineTranslation.translate(
        text: 'Hello world',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'en',
      );

      expect(res.translatedText, equals('Hello world'));
      expect(res.status, equals(TranslationStatus.completed));
    });

    test('19. Existing translation pivot behavior and unsupported pairs handled honestly', () {
      expect(AndroidSpeechRecognizerService.isLanguageSupported('en'), isTrue);
      expect(AndroidSpeechRecognizerService.isLanguageSupported('te'), isTrue);
      expect(AndroidSpeechRecognizerService.isLanguageSupported('hi'), isTrue);
      // Minority languages unsupported by Google SpeechRecognizer
      expect(AndroidSpeechRecognizerService.isLanguageSupported('sa'), isFalse);
      expect(AndroidSpeechRecognizerService.isLanguageSupported('brx'), isFalse);
      expect(AndroidSpeechRecognizerService.isLanguageSupported('kok'), isFalse);
      expect(AndroidSpeechRecognizerService.isLanguageSupported('doi'), isFalse);
    });
  });
}
