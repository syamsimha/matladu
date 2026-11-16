import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/app_strings.dart';
import 'core/navigation/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/asr_repository.dart';
import 'data/repositories/audio_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/translation_repository.dart';
import 'data/repositories/tts_repository.dart';
import 'data/services/asr/hybrid_asr_service.dart';
import 'data/services/asr/model_manager_service.dart';
import 'data/services/asr/online_asr_service.dart';
import 'data/services/asr/sherpa_on_device_asr_service.dart';
import 'data/services/audio_capture_service.dart';
import 'data/services/audio_permission_service.dart';
import 'data/services/engine/engine_selection_manager.dart';
import 'data/services/local_storage_service.dart';
import 'data/services/network_connectivity_service.dart';
import 'data/services/room/i_room_service.dart';
import 'data/services/room/room_communication_service.dart';
import 'data/services/translation/hybrid_translation_service.dart';
import 'data/services/translation/on_device_translation_service.dart';
import 'data/services/translation/online_translation_service.dart';
import 'data/services/tts/on_device_tts_service.dart';
import 'ui/features/home/view_models/home_view_model.dart';
import 'ui/features/live_translation/view_models/live_translation_view_model.dart';
import 'ui/features/live_translation/view_models/tts_view_model.dart';
import 'ui/features/settings/view_models/settings_view_model.dart';
import 'ui/features/theme/view_models/theme_view_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style matching light theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize local persistence & core services
  final prefs = await SharedPreferences.getInstance();
  final storageService = LocalStorageService(prefs);

  final settingsRepository = SettingsRepository(
    storageService: storageService,
  );

  // Validated OS-level network connectivity monitoring (0 cloud pings)
  final networkConnectivityService = NetworkConnectivityService();
  await networkConnectivityService.initialize();

  // Phase 4: Real On-Device Neural Translation Service (100% private, 0 network egress)
  final onDeviceTranslationService = OnDeviceTranslationService();
  await onDeviceTranslationService.initialize();

  // Phase 7 & 8: Online Cloud Neural Translation Service (zero secret keys in APK)
  final onlineTranslationService = OnlineTranslationService(
    storageService: storageService,
  );
  await onlineTranslationService.initialize();

  // Phase 2: Real Audio Capture and Permission Services
  const audioPermissionService = AudioPermissionService();
  final audioCaptureService = RecordAudioCaptureService();

  final audioRepository = AudioRepository(
    captureService: audioCaptureService,
    permissionService: audioPermissionService,
  );

  // Phase 3: Real On-Device ASR Service powered by Sherpa-ONNX (100% private, 0 network egress)
  final modelManagerService = ModelManagerService();
  final onDeviceAsrService = SherpaOnDeviceASRService(
    modelManager: modelManagerService,
    fallbackService: null, // STRICT ON-DEVICE PRIVACY: 0 Mock fallback allowed in production
  );
  await onDeviceAsrService.initialize();

  // Phase 7: Online Cloud Speech ASR Service (zero secret keys in APK)
  final onlineAsrService = OnlineASRService();
  await onlineAsrService.initialize();

  // Phase 7 & 8: Central Engine Selection Manager with quota-aware adaptive switching
  final engineSelectionManager = EngineSelectionManager(
    connectivityService: networkConnectivityService,
    modelManagerService: modelManagerService,
    onDeviceTranslationService: onDeviceTranslationService,
    onlineTranslationService: onlineTranslationService,
    settingsRepository: settingsRepository,
    initialMode: settingsRepository.getConnectionMode().mode,
  );

  // Phase 7: Hybrid Translation and ASR Services dynamically dispatching
  // between On-Device (100% private) and Cloud according to EngineSelectionManager
  final hybridTranslationService = HybridTranslationService(
    onDeviceService: onDeviceTranslationService,
    onlineService: onlineTranslationService,
    engineSelectionManager: engineSelectionManager,
  );

  final hybridAsrService = HybridASRService(
    onDeviceService: onDeviceAsrService,
    onlineService: onlineAsrService,
    engineSelectionManager: engineSelectionManager,
    settingsRepository: settingsRepository,
  );

  final translationRepository = TranslationRepository(
    translationService: hybridTranslationService,
    storageService: storageService,
  );

  final asrRepository = ASRRepository(
    audioRepository: audioRepository,
    asrService: hybridAsrService,
  );

  // Phase 7: Real Room Communication Service (WebSocket Relay + Local Loopback)
  final roomService = RoomCommunicationService();

  // Phase 5: Real On-Device Text-to-Speech Service (100% private, 0 network egress)
  final onDeviceTtsService = OnDeviceTtsService();
  await onDeviceTtsService.initialize();

  final ttsRepository = TtsRepository(
    ttsService: onDeviceTtsService,
    storageService: storageService,
  );
  await ttsRepository.initialize();

  runApp(
    MatladuApp(
      translationRepository: translationRepository,
      settingsRepository: settingsRepository,
      audioRepository: audioRepository,
      asrRepository: asrRepository,
      ttsRepository: ttsRepository,
      modelManagerService: modelManagerService,
      networkConnectivityService: networkConnectivityService,
      roomService: roomService,
      engineSelectionManager: engineSelectionManager,
    ),
  );
}

class MatladuApp extends StatelessWidget {
  final TranslationRepository translationRepository;
  final SettingsRepository settingsRepository;
  final AudioRepository audioRepository;
  final ASRRepository asrRepository;
  final TtsRepository ttsRepository;
  final ModelManagerService? modelManagerService;
  final NetworkConnectivityService? networkConnectivityService;
  final IRoomService? roomService;
  final EngineSelectionManager? engineSelectionManager;

  const MatladuApp({
    super.key,
    required this.translationRepository,
    required this.settingsRepository,
    required this.audioRepository,
    required this.asrRepository,
    required this.ttsRepository,
    this.modelManagerService,
    this.networkConnectivityService,
    this.roomService,
    this.engineSelectionManager,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TranslationRepository>.value(value: translationRepository),
        Provider<SettingsRepository>.value(value: settingsRepository),
        Provider<AudioRepository>.value(value: audioRepository),
        Provider<ASRRepository>.value(value: asrRepository),
        Provider<TtsRepository>.value(value: ttsRepository),
        if (modelManagerService != null)
          Provider<ModelManagerService>.value(value: modelManagerService!),
        if (networkConnectivityService != null)
          Provider<NetworkConnectivityService>.value(value: networkConnectivityService!),
        if (roomService != null)
          Provider<IRoomService>.value(value: roomService!),
        if (engineSelectionManager != null)
          ChangeNotifierProvider<EngineSelectionManager>.value(value: engineSelectionManager!),
        ChangeNotifierProvider<ThemeViewModel>(
          create: (_) => ThemeViewModel(settingsRepository: settingsRepository),
        ),
        ChangeNotifierProvider<SettingsViewModel>(
          create: (_) => SettingsViewModel(
            settingsRepository: settingsRepository,
            ttsRepository: ttsRepository,
            engineSelectionManager: engineSelectionManager,
          ),
        ),
        ChangeNotifierProvider<TtsViewModel>(
          create: (_) => TtsViewModel(ttsRepository: ttsRepository),
        ),
        ChangeNotifierProvider<LiveTranslationViewModel>(
          create: (_) => LiveTranslationViewModel(
            translationRepository: translationRepository,
            ttsRepository: ttsRepository,
            asrRepository: asrRepository,
            settingsRepository: settingsRepository,
            roomService: roomService,
          ),
        ),
        ChangeNotifierProvider<HomeViewModel>(
          create: (_) => HomeViewModel(
            translationRepository: translationRepository,
            settingsRepository: settingsRepository,
            audioRepository: audioRepository,
            asrRepository: asrRepository,
            ttsRepository: ttsRepository,
            modelManagerService: modelManagerService,
            networkConnectivityService: networkConnectivityService,
            engineSelectionManager: engineSelectionManager,
          ),
        ),
      ],
      child: Consumer<ThemeViewModel>(
        builder: (context, themeVm, _) {
          return MaterialApp(
            title: AppStrings.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeVm.themeMode,
            initialRoute: AppRoutes.splash,
            onGenerateRoute: AppRoutes.onGenerateRoute,
          );
        },
      ),
    );
  }
}
