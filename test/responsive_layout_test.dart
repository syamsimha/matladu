import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matladu_ai/core/responsive/responsive_layout.dart';
import 'package:matladu_ai/core/theme/app_theme.dart';
import 'package:matladu_ai/data/repositories/settings_repository.dart';
import 'package:matladu_ai/data/repositories/translation_repository.dart';
import 'package:matladu_ai/data/services/local_storage_service.dart';
import 'package:matladu_ai/data/services/mock_translation_service.dart';
import 'package:matladu_ai/ui/features/about/views/about_screen.dart';
import 'package:matladu_ai/ui/features/connection_mode/views/connection_mode_screen.dart';
import 'package:matladu_ai/ui/features/home/view_models/home_view_model.dart';
import 'package:matladu_ai/ui/features/home/views/home_screen.dart';
import 'package:matladu_ai/ui/features/language_selection/views/language_selection_screen.dart';
import 'package:matladu_ai/ui/features/live_translation/views/live_translation_screen.dart';
import 'package:matladu_ai/ui/features/offline_packs/views/offline_packs_screen.dart';
import 'package:matladu_ai/ui/features/settings/views/settings_screen.dart';
import 'package:matladu_ai/ui/features/splash/views/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsRepository settingsRepo;
  late TranslationRepository transRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    final mockService = MockTranslationService();
    settingsRepo = SettingsRepository(storageService: storage);
    transRepo = TranslationRepository(
      translationService: mockService,
      storageService: storage,
    );
  });

  Widget createTestWidget(Widget child, Size size) {
    return MultiProvider(
      providers: [
        Provider<SettingsRepository>.value(value: settingsRepo),
        Provider<TranslationRepository>.value(value: transRepo),
        ChangeNotifierProvider<HomeViewModel>(
          create: (_) => HomeViewModel(
            translationRepository: transRepo,
            settingsRepository: settingsRepo,
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: const EdgeInsets.only(top: 44, bottom: 34),
            viewInsets: EdgeInsets.zero,
            devicePixelRatio: 2.0,
          ),
          child: child,
        ),
      ),
    );
  }

  // Device test matrix
  final devices = {
    'Compact Phone (iPhone SE / Android)': const Size(320, 568),
    'Standard Phone (iPhone 14 / Pixel)': const Size(390, 844),
    'Large Phone (iPhone Pro Max / Ultra)': const Size(428, 926),
    'Tablet Portrait (iPad / Galaxy Tab)': const Size(820, 1180),
    'Phone Landscape': const Size(844, 390),
  };

  group('Universal & Responsive Layout Tests for all 8 Screens', () {
    for (final entry in devices.entries) {
      final deviceName = entry.key;
      final size = entry.value;

      testWidgets('Screen 1 (Splash) renders overflow-free on $deviceName', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createTestWidget(const SplashScreen(), size));
        expect(tester.takeException(), isNull);
      });

      testWidgets('Screen 2 (Home) renders overflow-free on $deviceName', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createTestWidget(const HomeScreen(), size));
        expect(tester.takeException(), isNull);
      });

      testWidgets('Screen 3 (Live Translation) renders overflow-free on $deviceName', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createTestWidget(const LiveTranslationScreen(), size));
        expect(tester.takeException(), isNull);
      });

      testWidgets('Screen 4 (Select Language) renders overflow-free on $deviceName', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createTestWidget(const LanguageSelectionScreen(), size));
        expect(tester.takeException(), isNull);
      });

      testWidgets('Screen 5 (Offline Packs) renders overflow-free on $deviceName', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createTestWidget(const OfflinePacksScreen(), size));
        expect(tester.takeException(), isNull);
      });

      testWidgets('Screen 6 (Settings) renders overflow-free on $deviceName', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createTestWidget(const SettingsScreen(), size));
        expect(tester.takeException(), isNull);
      });

      testWidgets('Screen 7 (About) renders overflow-free on $deviceName', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createTestWidget(const AboutScreen(), size));
        expect(tester.takeException(), isNull);
      });

      testWidgets('Screen 8 (Connection Mode) renders overflow-free on $deviceName', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createTestWidget(const ConnectionModeScreen(), size));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
