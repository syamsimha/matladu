import 'package:flutter/material.dart';
import '../../../../data/models/connection_mode_model.dart';
import '../../../../data/models/language_model.dart';
import '../../../../data/models/translation_item_model.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../../data/repositories/translation_repository.dart';

/// ViewModel managing state for the Home / Translator Screen.
class HomeViewModel extends ChangeNotifier {
  final TranslationRepository _translationRepository;
  final SettingsRepository _settingsRepository;

  HomeViewModel({
    required TranslationRepository translationRepository,
    required SettingsRepository settingsRepository,
  })  : _translationRepository = translationRepository,
        _settingsRepository = settingsRepository {
    _init();
  }

  late LanguageModel _sourceLanguage;
  late LanguageModel _targetLanguage;
  late ConnectionModeModel _connectionMode;

  bool _isListening = false;
  int _currentTab = 0; // 0: Home, 1: Offline, 2: History, 3: Settings
  List<TranslationItemModel> _history = [];

  // Getters
  LanguageModel get sourceLanguage => _sourceLanguage;
  LanguageModel get targetLanguage => _targetLanguage;
  ConnectionModeModel get connectionMode => _connectionMode;
  bool get isListening => _isListening;
  int get currentTab => _currentTab;
  List<TranslationItemModel> get history => _history;

  void _init() {
    _sourceLanguage = _settingsRepository.getSourceLanguage();
    _targetLanguage = _settingsRepository.getTargetLanguage();
    _connectionMode = _settingsRepository.getConnectionMode();
    _history = _translationRepository.getHistory();
    notifyListeners();
  }

  void refreshFromSettings() {
    _sourceLanguage = _settingsRepository.getSourceLanguage();
    _targetLanguage = _settingsRepository.getTargetLanguage();
    _connectionMode = _settingsRepository.getConnectionMode();
    _history = _translationRepository.getHistory();
    notifyListeners();
  }

  void setTab(int index) {
    _currentTab = index;
    notifyListeners();
  }

  Future<void> setSourceLanguage(LanguageModel language) async {
    _sourceLanguage = language;
    await _settingsRepository.setSourceLanguage(language);
    notifyListeners();
  }

  Future<void> setTargetLanguage(LanguageModel language) async {
    _targetLanguage = language;
    await _settingsRepository.setTargetLanguage(language);
    notifyListeners();
  }

  Future<void> swapLanguages() async {
    final temp = _sourceLanguage;
    _sourceLanguage = _targetLanguage;
    _targetLanguage = temp;

    await _settingsRepository.setSourceLanguage(_sourceLanguage);
    await _settingsRepository.setTargetLanguage(_targetLanguage);
    notifyListeners();
  }

  void startListening(VoidCallback onDone) {
    _isListening = true;
    notifyListeners();

    // Simulate voice listening and navigate to Live Translation screen (Screen 3)
    Future.delayed(const Duration(milliseconds: 1200), () {
      _isListening = false;
      notifyListeners();
      onDone();
    });
  }

  Future<void> clearHistory() async {
    await _translationRepository.clearHistory();
    _history = [];
    notifyListeners();
  }
}
