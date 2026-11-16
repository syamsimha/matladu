import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../data/models/app_settings_model.dart';
import '../../../../data/models/connection_mode_model.dart';
import '../../../../data/models/tts_voice.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../../data/repositories/tts_repository.dart';
import '../../../../data/services/engine/engine_selection_manager.dart';

/// ViewModel managing state for the Settings Screen (Screen 6).
class SettingsViewModel extends ChangeNotifier {
  final SettingsRepository _settingsRepository;
  final TtsRepository? _ttsRepository;
  final EngineSelectionManager? _engineSelectionManager;

  SettingsViewModel({
    required SettingsRepository settingsRepository,
    TtsRepository? ttsRepository,
    EngineSelectionManager? engineSelectionManager,
  })  : _settingsRepository = settingsRepository,
        _ttsRepository = ttsRepository,
        _engineSelectionManager = engineSelectionManager {
    _loadSettings();
    _loadVoices();
    _engineSelectionManager?.addListener(_onEngineManagerChanged);
  }

  void _onEngineManagerChanged() {
    final mode = _engineSelectionManager?.activeMode;
    if (mode != null && mode != _connectionMode.type) {
      _connectionMode = _settingsRepository.getConnectionMode();
      _isOnlineActive = mode == ConnectionModeType.cloudAi || mode == ConnectionModeType.automatic;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _engineSelectionManager?.removeListener(_onEngineManagerChanged);
    super.dispose();
  }

  late AppSettingsModel _settings;
  late ConnectionModeModel _connectionMode;
  bool _isOnlineActive = true;
  double _cacheSizeMB = 24.5;
  List<TtsVoice> _availableVoices = [];

  AppSettingsModel get settings => _settings;
  ConnectionModeModel get connectionMode => _connectionMode;
  bool get isOnlineActive => _isOnlineActive;
  double get cacheSizeMB => _cacheSizeMB;
  List<TtsVoice> get availableVoices => _availableVoices;
  String? get selectedVoiceName => _settings.selectedVoiceName;
  double get speechSpeed => _settings.speechSpeed;
  bool get cloudSpeechConsentGranted => _settings.cloudSpeechConsentGranted;

  void _loadSettings() {
    _settings = _settingsRepository.getAppSettings();
    _connectionMode = _settingsRepository.getConnectionMode();
    _isOnlineActive = _connectionMode.type == ConnectionModeType.cloudAi ||
        _connectionMode.type == ConnectionModeType.automatic;
    notifyListeners();
  }

  Future<void> loadVoices() => _loadVoices();

  Future<void> _loadVoices() async {
    final tts = _ttsRepository;
    if (tts != null) {
      try {
        final voices = await tts.getAvailableVoices();
        _availableVoices = voices;
        notifyListeners();
      } catch (_) {}
    }
  }

  Future<void> updateSelectedVoice(String? voiceName) async {
    _settings = _settings.copyWith(selectedVoiceName: voiceName);
    await _settingsRepository.saveAppSettings(_settings);
    notifyListeners();
  }

  Future<void> previewVoice({
    String? voiceName,
    String? sampleText,
    String? languageCode,
  }) async {
    final tts = _ttsRepository;
    if (tts != null) {
      final name = voiceName ?? _settings.selectedVoiceName;
      final text = sampleText ?? 'Matladu: Listen. Convert. Translate.';
      final lang = languageCode ?? 'en';
      await tts.service.speak(
        text: text,
        languageCode: lang,
        voiceName: name,
      );
    }
  }

  Future<void> setConnectionMode(ConnectionModeType mode) async {
    _engineSelectionManager?.setUserMode(mode);
    await _settingsRepository.setConnectionMode(mode);
    _connectionMode = _settingsRepository.getConnectionMode();
    _isOnlineActive = mode == ConnectionModeType.cloudAi || mode == ConnectionModeType.automatic;
    notifyListeners();
  }

  Future<void> toggleOnlineMode(bool value) async {
    _isOnlineActive = value;
    final newMode = value ? ConnectionModeType.cloudAi : ConnectionModeType.onDevice;
    _engineSelectionManager?.setUserMode(newMode);
    await _settingsRepository.setConnectionMode(newMode);
    _connectionMode = _settingsRepository.getConnectionMode();
    notifyListeners();
  }

  Future<void> updateSpeechSpeed(double speed) async {
    _settings = _settings.copyWith(speechSpeed: speed);
    await _settingsRepository.saveAppSettings(_settings);
    notifyListeners();
  }

  Future<void> updateSpeechPitch(String pitch) async {
    _settings = _settings.copyWith(speechPitch: pitch);
    await _settingsRepository.saveAppSettings(_settings);
    notifyListeners();
  }

  Future<void> updateAutoPlayAudio(bool value) async {
    _settings = _settings.copyWith(autoPlayAudio: value);
    await _settingsRepository.saveAppSettings(_settings);
    notifyListeners();
  }

  Future<void> updateAutoDetect(bool value) async {
    _settings = _settings.copyWith(autoDetectLanguage: value);
    await _settingsRepository.saveAppSettings(_settings);
    notifyListeners();
  }

  Future<void> updateCloudSpeechConsent(bool value) async {
    _settings = _settings.copyWith(cloudSpeechConsentGranted: value);
    await _settingsRepository.saveAppSettings(_settings);
    notifyListeners();
  }

  Future<void> updateNoiseSuppression(bool value) async {
    _settings = _settings.copyWith(noiseSuppression: value);
    await _settingsRepository.saveAppSettings(_settings);
    notifyListeners();
  }

  /// Securely purges temporary audio cache and scratch files from disk.
  Future<void> clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        final entities = tempDir.listSync(recursive: true);
        for (final entity in entities) {
          try {
            if (entity is File) {
              entity.deleteSync();
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
    _cacheSizeMB = 0.0;
    notifyListeners();
  }

  Future<void> resetSettings() async {
    await _settingsRepository.resetAllSettings();
    await clearCache();
    _loadSettings();
  }
}
