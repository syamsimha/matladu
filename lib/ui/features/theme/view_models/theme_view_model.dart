import 'package:flutter/material.dart';
import '../../../../data/repositories/settings_repository.dart';

/// ViewModel managing theme state (Light vs Dark Mode) and persistence.
class ThemeViewModel extends ChangeNotifier {
  final SettingsRepository _settingsRepository;

  ThemeViewModel({required SettingsRepository settingsRepository})
      : _settingsRepository = settingsRepository {
    _themeMode = _settingsRepository.getThemeMode();
  }

  late ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isDark => isDarkMode;

  /// Toggles between light and dark mode with immediate persistence.
  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await _settingsRepository.setThemeMode(_themeMode);
    notifyListeners();
  }

  /// Sets an explicit theme mode with immediate persistence.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    await _settingsRepository.setThemeMode(mode);
    notifyListeners();
  }
}

