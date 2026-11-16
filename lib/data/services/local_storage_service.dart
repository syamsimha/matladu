import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings_model.dart';
import '../models/connection_mode_model.dart';
import '../models/translation_item_model.dart';

/// Local persistence service abstracting storage operations via SharedPreferences.
class LocalStorageService {
  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  static const String _keySourceLang = 'matladu_source_lang';
  static const String _keyTargetLang = 'matladu_target_lang';
  static const String _keyConnectionMode = 'matladu_connection_mode';
  static const String _keyHistory = 'matladu_translation_history';
  static const String _keySettings = 'matladu_app_settings';
  static const String _keyDownloadedPacks = 'matladu_downloaded_packs';
  static const String _keyThemeMode = 'matladu_theme_mode';

  // Theme Mode
  String getThemeMode() => _prefs.getString(_keyThemeMode) ?? 'light';
  Future<bool> setThemeMode(String mode) =>
      _prefs.setString(_keyThemeMode, mode);

  // Language Preferences
  String getSourceLanguageCode() => _prefs.getString(_keySourceLang) ?? 'auto';
  Future<bool> setSourceLanguageCode(String code) =>
      _prefs.setString(_keySourceLang, code);

  String getTargetLanguageCode() => _prefs.getString(_keyTargetLang) ?? 'te';
  Future<bool> setTargetLanguageCode(String code) =>
      _prefs.setString(_keyTargetLang, code);

  // Connection Mode: Automatic is default on first installation
  ConnectionModeType getConnectionMode() {
    final raw = _prefs.getString(_keyConnectionMode);
    if (raw == 'onDevice') return ConnectionModeType.onDevice;
    if (raw == 'cloudAi') return ConnectionModeType.cloudAi;
    if (raw == 'peerToPeer') return ConnectionModeType.peerToPeer;
    return ConnectionModeType.automatic;
  }

  Future<bool> setConnectionMode(ConnectionModeType mode) {
    return _prefs.setString(_keyConnectionMode, mode.name);
  }

  // App Settings
  AppSettingsModel getAppSettings() {
    final raw = _prefs.getString(_keySettings);
    if (raw == null) return const AppSettingsModel();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AppSettingsModel.fromJson(map);
    } catch (_) {
      return const AppSettingsModel();
    }
  }

  Future<bool> saveAppSettings(AppSettingsModel settings) {
    return _prefs.setString(_keySettings, jsonEncode(settings.toJson()));
  }

  // Translation History
  List<TranslationItemModel> getTranslationHistory() {
    final rawList = _prefs.getStringList(_keyHistory);
    if (rawList == null) return [];
    try {
      return rawList
          .map((item) =>
              TranslationItemModel.fromJson(jsonDecode(item) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveTranslation(TranslationItemModel item) async {
    final list = getTranslationHistory();
    list.insert(0, item);
    // Keep last 50 items
    final trimmed = list.take(50).toList();
    final jsonList = trimmed.map((e) => jsonEncode(e.toJson())).toList();
    return _prefs.setStringList(_keyHistory, jsonList);
  }

  Future<bool> clearHistory() {
    return _prefs.remove(_keyHistory);
  }

  // Offline Packs: on fresh installation, packs are NOT downloaded by default
  List<String> getDownloadedPackCodes() {
    return _prefs.getStringList(_keyDownloadedPacks) ?? <String>[];
  }

  Future<bool> setDownloadedPackCodes(List<String> codes) {
    return _prefs.setStringList(_keyDownloadedPacks, codes);
  }

  // Quota Exhaustion Persistence
  static const String _keyQuotaExhaustedAt = 'matladu_quota_exhausted_at';

  DateTime? getQuotaExhaustedAt() {
    final raw = _prefs.getString(_keyQuotaExhaustedAt);
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateTime.parse(raw).toUtc();
    } catch (_) {
      return null;
    }
  }

  Future<bool> setQuotaExhaustedAt(DateTime? timestamp) {
    if (timestamp == null) {
      return _prefs.remove(_keyQuotaExhaustedAt);
    }
    return _prefs.setString(_keyQuotaExhaustedAt, timestamp.toUtc().toIso8601String());
  }
}

