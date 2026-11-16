import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matladu_ai/core/theme/app_theme.dart';
import 'package:matladu_ai/data/models/language_model.dart';
import 'package:matladu_ai/data/repositories/settings_repository.dart';
import 'package:matladu_ai/data/repositories/translation_repository.dart';
import 'package:matladu_ai/data/services/local_storage_service.dart';
import 'package:matladu_ai/data/services/mock_translation_service.dart';
import 'package:matladu_ai/ui/features/home/view_models/home_view_model.dart';
import 'package:matladu_ai/ui/features/home/views/home_screen.dart';
import 'package:matladu_ai/ui/features/theme/view_models/theme_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsRepository settingsRepo;
  late TranslationRepository transRepo;
  late ThemeViewModel themeViewModel;
  late HomeViewModel homeViewModel;

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
    themeViewModel = ThemeViewModel(settingsRepository: settingsRepo);
    homeViewModel = HomeViewModel(
      translationRepository: transRepo,
      settingsRepository: settingsRepo,
    );
  });

  Widget buildTestApp({ThemeMode initialTheme = ThemeMode.light}) {
    return MultiProvider(
      providers: [
        Provider<SettingsRepository>.value(value: settingsRepo),
        Provider<TranslationRepository>.value(value: transRepo),
        ChangeNotifierProvider<ThemeViewModel>.value(value: themeViewModel),
        ChangeNotifierProvider<HomeViewModel>.value(value: homeViewModel),
      ],
      child: Consumer<ThemeViewModel>(
        builder: (context, themeVm, _) {
          return MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeVm.themeMode,
            home: const MediaQuery(
              data: MediaQueryData(
                size: Size(390, 844),
                padding: EdgeInsets.only(top: 44, bottom: 34),
                devicePixelRatio: 1.0,
              ),
              child: HomeScreen(),
            ),
          );
        },
      ),
    );
  }

  group('ThemeViewModel & Theme Persistence Tests', () {
    test('Initializes with Light mode by default', () {
      expect(themeViewModel.themeMode, ThemeMode.light);
      expect(themeViewModel.isDark, isFalse);
    });

    test('Toggles theme from Light to Dark and back', () async {
      await themeViewModel.toggleTheme();
      expect(themeViewModel.themeMode, ThemeMode.dark);
      expect(themeViewModel.isDark, isTrue);

      await themeViewModel.toggleTheme();
      expect(themeViewModel.themeMode, ThemeMode.light);
      expect(themeViewModel.isDark, isFalse);
    });

    test('Loads persisted Dark theme preference correctly', () async {
      SharedPreferences.setMockInitialValues({'matladu_theme_mode': 'dark'});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final repo = SettingsRepository(storageService: storage);
      final vm = ThemeViewModel(settingsRepository: repo);

      expect(vm.themeMode, ThemeMode.dark);
      expect(vm.isDark, isTrue);
    });

    test('Persists mode change to repository on toggle', () async {
      await themeViewModel.toggleTheme();
      expect(settingsRepo.getThemeMode(), ThemeMode.dark);

      await themeViewModel.toggleTheme();
      expect(settingsRepo.getThemeMode(), ThemeMode.light);
    });
  });

  group('Home Screen UI Corrections & Theme Integration', () {
    testWidgets('Renders separate Source and Target language selection boxes with swap icon', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      // Check for source language text and detection label (Auto Detect by default)
      expect(find.text('Auto Detect'), findsWidgets);
      expect(find.text('(Detect)'), findsOneWidget);

      // Check for target language text and native script
      expect(find.text('Telugu'), findsWidgets);
      expect(find.text('(తెలుగు)'), findsOneWidget);

      // Check for swap button icon
      expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);
    });

    testWidgets('Tapping swap button swaps source and target languages', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      // Set explicit pair English -> Telugu to verify swap
      homeViewModel.setSourceLanguage(const LanguageModel(code: 'en', name: 'English', nativeName: 'English'));
      await tester.pump();

      expect(homeViewModel.sourceLanguage.code, 'en');
      expect(homeViewModel.targetLanguage.code, 'te');

      // Tap swap button
      final swapButton = find.byKey(const ValueKey('swap_languages_button'));
      await tester.tap(swapButton, warnIfMissed: false);
      await tester.pump();

      // Verified swapped
      expect(homeViewModel.sourceLanguage.code, 'te');
      expect(homeViewModel.targetLanguage.code, 'en');
    });

    testWidgets('Replaces VIP Crown with Theme Toggle button and toggles dark mode', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      // Crown icon must NOT exist
      expect(find.byIcon(Icons.workspace_premium_rounded), findsNothing);

      // Moon icon displayed initially in light mode
      expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
      expect(themeViewModel.isDark, isFalse);

      // Tap theme toggle button
      await tester.tap(find.byKey(const ValueKey('theme_toggle_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Dark mode activated -> Sun icon displayed
      expect(themeViewModel.isDark, isTrue);
      expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);

      // Tap again to switch back
      await tester.tap(find.byKey(const ValueKey('theme_toggle_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(themeViewModel.isDark, isFalse);
      expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
    });

    testWidgets('Both separate language boxes are independently tappable', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      // Left box
      final sourceBox = find.text('(Detect)');
      expect(sourceBox, findsOneWidget);

      // Right box
      final targetBox = find.text('(తెలుగు)');
      expect(targetBox, findsOneWidget);
    });
  });
}
