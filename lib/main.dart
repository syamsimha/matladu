import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/app_strings.dart';
import 'core/navigation/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/translation_repository.dart';
import 'data/services/local_storage_service.dart';
import 'data/services/mock_translation_service.dart';
import 'ui/features/home/view_models/home_view_model.dart';

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

  // Initialize local persistence
  final prefs = await SharedPreferences.getInstance();
  final storageService = LocalStorageService(prefs);
  final translationService = MockTranslationService();

  final translationRepository = TranslationRepository(
    translationService: translationService,
    storageService: storageService,
  );

  final settingsRepository = SettingsRepository(
    storageService: storageService,
  );

  runApp(
    MatladuApp(
      translationRepository: translationRepository,
      settingsRepository: settingsRepository,
    ),
  );
}

class MatladuApp extends StatelessWidget {
  final TranslationRepository translationRepository;
  final SettingsRepository settingsRepository;

  const MatladuApp({
    super.key,
    required this.translationRepository,
    required this.settingsRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TranslationRepository>.value(value: translationRepository),
        Provider<SettingsRepository>.value(value: settingsRepository),
        ChangeNotifierProvider<HomeViewModel>(
          create: (_) => HomeViewModel(
            translationRepository: translationRepository,
            settingsRepository: settingsRepository,
          ),
        ),
      ],
      child: MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: AppRoutes.splash,
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    );
  }
}
