import 'package:flutter/material.dart';
import '../../../../data/models/app_settings_model.dart';
import '../../../../data/models/connection_mode_model.dart';
import '../../../../data/repositories/settings_repository.dart';

/// ViewModel managing state for the Settings Screen (Screen 6).
class SettingsViewModel extends ChangeNotifier {
  final SettingsRepository _settingsRepository;

  SettingsViewModel({required SettingsRepository settingsRepository})
      : _settingsRepository = settingsRepository {
    _loadSettings();
  }

  late AppSettingsModel _settings;
  late ConnectionModeModel _connectionMode;
  bool _isOnlineActive = true;
  double _cacheSizeMB = 24.5;

  AppSettingsModel get settings => _settings;
  ConnectionModeModel get connectionMode => _connectionMode;
  bool get isOnlineActive => _isOnlineActive;
  double get cacheSizeMB => _cacheSizeMB;

  void _loadSettings() {
    _settings = _settingsRepository.getAppSettings();
    _connectionMode = _settingsRepository.getConnectionMode();
    _isOnlineActive = _connectionMode.type == ConnectionModeType.cloudAi;
    notifyListeners();
  }

  Future<void> toggleOnlineMode(bool value) async {
    _isOnlineActive = value;
    final newMode = value ? ConnectionModeType.cloudAi : ConnectionModeType.onDevice;
    await _settingsRepository.setConnectionMode(newMode);
    _connectionMode = _settingsRepository.getConnectionMode();
    notifyListeners();
  }

  Future<void> updateSpeechSpeed(double speed) async {
    _settings = _settings.copyWith(speechSpeed: speed);
    await _settingsRepository.saveAppSettings(_settings);
    notifyListeners();
  }

  Future<void> updateAutoDetect(bool value) async {
    _settings = _settings.copyWith(autoDetectLanguage: value);
    await _settingsRepository.saveAppSettings(_settings);
    notifyListeners();
  }

  Future<void> updateNoiseSuppression(bool value) async {
    _settings = _settings.copyWith(noiseSuppression: value);
    await _settingsRepository.saveAppSettings(_settings);
    notifyListeners();
  }

  void clearCache() {
    _cacheSizeMB = 0.0;
    notifyListeners();
  }

  Future<void> resetSettings() async {
    await _settingsRepository.resetAllSettings();
    _cacheSizeMB = 0.0;
    _loadSettings();
  }
}

