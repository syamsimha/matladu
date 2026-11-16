import 'dart:async';
import 'package:flutter/material.dart';
import '../models/app_settings_model.dart';
import '../models/connection_mode_model.dart';
import '../models/language_model.dart';
import '../models/offline_pack_model.dart';
import '../services/local_storage_service.dart';

/// Repository managing user preferences, languages, connection modes, and offline packages.
class SettingsRepository {
  final LocalStorageService _storageService;
  final _connectionModeController = StreamController<ConnectionModeType>.broadcast();

  SettingsRepository({required LocalStorageService storageService})
      : _storageService = storageService;

  Stream<ConnectionModeType> get connectionModeStream => _connectionModeController.stream;

  // Language Preferences
  LanguageModel getSourceLanguage() {
    final code = _storageService.getSourceLanguageCode();
    if (code == 'auto') return LanguageModel.autoDetect;
    return LanguageModel.defaultLanguages.firstWhere(
      (l) => l.code == code,
      orElse: () => LanguageModel.autoDetect, // Auto Detect default
    );
  }

  Future<void> setSourceLanguage(LanguageModel lang) async {
    await _storageService.setSourceLanguageCode(lang.code);
  }

  LanguageModel getTargetLanguage() {
    final code = _storageService.getTargetLanguageCode();
    return LanguageModel.defaultLanguages.firstWhere(
      (l) => l.code == code,
      orElse: () => LanguageModel.defaultLanguages[1], // Telugu default
    );
  }

  Future<void> setTargetLanguage(LanguageModel lang) async {
    await _storageService.setTargetLanguageCode(lang.code);
  }

  // Connection Mode
  ConnectionModeModel getConnectionMode() {
    final mode = _storageService.getConnectionMode();
    return ConnectionModeModel.availableModes.firstWhere(
      (m) => m.type == mode,
      orElse: () => ConnectionModeModel.availableModes.first,
    );
  }

  Future<void> setConnectionMode(ConnectionModeType mode) async {
    await _storageService.setConnectionMode(mode);
    if (!_connectionModeController.isClosed) {
      _connectionModeController.add(mode);
    }
  }

  // App Settings
  AppSettingsModel getAppSettings() {
    return _storageService.getAppSettings();
  }

  Future<void> saveAppSettings(AppSettingsModel settings) async {
    await _storageService.saveAppSettings(settings);
  }

  // Cloud Speech Recognition Consent (Google Speech Services in Online Mode)
  bool getCloudSpeechConsent() {
    return _storageService.getAppSettings().cloudSpeechConsentGranted;
  }

  Future<void> setCloudSpeechConsent(bool granted) async {
    final current = _storageService.getAppSettings();
    await _storageService.saveAppSettings(
      current.copyWith(cloudSpeechConsentGranted: granted),
    );
  }

  // Offline Packs
  List<OfflinePackModel> getOfflinePacks() {
    final downloaded = _storageService.getDownloadedPackCodes();

    // Telugu, Hindi, Tamil, Kannada as available in reference Screen 5
    final targetPacks = [
      {'code': 'te', 'name': 'Telugu Pack', 'size': 25},
      {'code': 'hi', 'name': 'Hindi Pack', 'size': 28},
      {'code': 'ta', 'name': 'Tamil Pack', 'size': 30},
      {'code': 'kn', 'name': 'Kannada Pack', 'size': 30},
    ];

    return targetPacks.map((item) {
      final code = item['code'] as String;
      final isDownloaded = downloaded.contains(code);
      return OfflinePackModel(
        id: code,
        languageName: item['name'] as String,
        languageCode: code,
        flagEmoji: '🇮🇳',
        sizeInMB: item['size'] as int,
        isDownloaded: isDownloaded,
      );
    }).toList();
  }

  List<String> getDownloadedPackCodes() {
    return _storageService.getDownloadedPackCodes();
  }

  Future<void> addDownloadedPack(String code) async {
    final downloaded = List<String>.from(_storageService.getDownloadedPackCodes());
    if (!downloaded.contains(code)) {
      downloaded.add(code);
      await _storageService.setDownloadedPackCodes(downloaded);
    }
  }

  Future<void> togglePackDownload(String code) async {
    final downloaded = List<String>.from(_storageService.getDownloadedPackCodes());
    if (downloaded.contains(code)) {
      downloaded.remove(code);
    } else {
      downloaded.add(code);
    }
    await _storageService.setDownloadedPackCodes(downloaded);
  }

  Future<void> deleteDownloadedPack(String code) async {
    final downloaded = List<String>.from(_storageService.getDownloadedPackCodes());
    downloaded.remove(code);
    await _storageService.setDownloadedPackCodes(downloaded);
  }

  // Theme Mode
  ThemeMode getThemeMode() {
    final mode = _storageService.getThemeMode();
    return mode == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _storageService.setThemeMode(mode == ThemeMode.dark ? 'dark' : 'light');
  }

  Future<void> resetAllSettings() async {
    await _storageService.saveAppSettings(const AppSettingsModel());
    await _storageService.setSourceLanguageCode('auto');
    await _storageService.setTargetLanguageCode('te');
    await _storageService.setConnectionMode(ConnectionModeType.automatic);
    await _storageService.setDownloadedPackCodes(<String>[]);
    await _storageService.setThemeMode('light');
  }
}
