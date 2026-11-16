import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/tts_result.dart';
import '../models/tts_voice.dart';
import '../services/local_storage_service.dart';
import '../services/tts/i_tts_service.dart';

/// Repository managing on-device Text-to-Speech synthesis, offline voice resolution,
/// and automatic translation speech playback lifecycle.
///
/// NON-NEGOTIABLE REQUIREMENTS:
/// - 100% On-Device speech synthesis.
/// - Prevents overlapping playback.
/// - Suppresses empty or error strings.
/// - Persists speech settings (rate, pitch, auto-play) locally.
class TtsRepository {
  final ITtsService _ttsService;
  final LocalStorageService _storageService;

  String? _lastSpokenText;
  String? _lastSpokenLanguageCode;
  String? _activeRequestId;
  bool _userStoppedActive = false;

  TtsRepository({
    required ITtsService ttsService,
    required LocalStorageService storageService,
  })  : _ttsService = ttsService,
        _storageService = storageService;

  ITtsService get service => _ttsService;
  Stream<TtsResult> get stateStream => _ttsService.stateStream;
  TtsPlaybackState get currentState => _ttsService.currentState;
  bool get isSpeaking => _ttsService.currentState == TtsPlaybackState.speaking;
  String? get activeRequestId => _activeRequestId;
  String? get lastSpokenText => _lastSpokenText;
  String? get lastSpokenLanguageCode => _lastSpokenLanguageCode;

  /// Whether automatic translated speech playback is enabled (enabled by default).
  bool get autoPlayEnabled =>
      _storageService.getAppSettings().autoPlayAudio;

  /// Configured speech playback speed multiplier (0.5 to 2.0).
  double get speechRate =>
      _storageService.getAppSettings().speechSpeed;

  /// Initializes the underlying on-device TTS engine and applies persisted settings.
  Future<void> initialize() async {
    await _ttsService.initialize();
    final settings = _storageService.getAppSettings();
    await _ttsService.setSpeechRate(settings.speechSpeed);

    // Map string pitch to multiplier
    double pitchValue = 1.0;
    if (settings.speechPitch == 'Low') {
      pitchValue = 0.8;
    } else if (settings.speechPitch == 'High') {
      pitchValue = 1.2;
    }
    await _ttsService.setPitch(pitchValue);
  }

  /// Speaks translated text using the verified offline voice for [targetLanguageCode].
  ///
  /// If [isAutoPlay] is true, checks [autoPlayEnabled] before speaking.
  /// Generates or attaches a unique [requestId] to prevent duplicate playback.
  Future<bool> speakTranslation({
    required String text,
    required String targetLanguageCode,
    String? requestId,
    bool isAutoPlay = false,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) {
      debugPrint('[TtsRepository] Rejecting empty translation speech request.');
      return false;
    }

    if (isAutoPlay && !autoPlayEnabled) {
      debugPrint('[TtsRepository] Auto-play is disabled by user settings. Skipping auto-playback.');
      return false;
    }

    final reqId = requestId ?? DateTime.now().millisecondsSinceEpoch.toString();

    // If audio is already playing for an older translation, stop it immediately
    if (isSpeaking) {
      debugPrint('[TtsRepository] Stopping active playback before starting new translation audio.');
      await stop();
    }

    _activeRequestId = reqId;
    _lastSpokenText = clean;
    _lastSpokenLanguageCode = targetLanguageCode;
    _userStoppedActive = false;

    debugPrint(
        '[TtsRepository] Requesting TTS speech: lang: $targetLanguageCode, chars: ${clean.length}, auto: $isAutoPlay, reqId: $reqId');

    final selectedVoice = _storageService.getAppSettings().selectedVoiceName;

    final success = await _ttsService.speak(
      text: clean,
      languageCode: targetLanguageCode,
      voiceName: selectedVoice,
      requestId: reqId,
    );

    return success;
  }

  /// Replays the most recently translated text from the beginning.
  Future<bool> replayCurrentTranslation() async {
    if (_lastSpokenText == null || _lastSpokenLanguageCode == null) {
      debugPrint('[TtsRepository] No active translation available to replay.');
      return false;
    }

    return speakTranslation(
      text: _lastSpokenText!,
      targetLanguageCode: _lastSpokenLanguageCode!,
      isAutoPlay: false,
    );
  }

  /// Manually stops current speech playback.
  /// Flags session as user-stopped to prevent accidental auto-resume.
  Future<bool> stop() async {
    _userStoppedActive = true;
    return await _ttsService.stop();
  }

  /// Pauses active speech playback.
  Future<bool> pause() async {
    return await _ttsService.pause();
  }

  /// Resumes paused speech playback.
  Future<bool> resume() async {
    return await _ttsService.resume();
  }

  /// Returns whether user explicitly pressed stop on the current speech session.
  bool get wasStoppedByUser => _userStoppedActive;

  /// Returns all available voices from the native engine.
  Future<List<TtsVoice>> getAvailableVoices() {
    return _ttsService.getAvailableVoices();
  }

  /// Returns only voices certified for 100% offline synthesis.
  Future<List<TtsVoice>> getOfflineVoices() {
    return _ttsService.getOfflineVoices();
  }

  /// Checks if an offline voice is installed and available for [languageCode].
  Future<bool> isOfflineVoiceAvailable(String languageCode) {
    return _ttsService.isOfflineVoiceAvailable(languageCode);
  }

  /// Returns the name of the default native TTS engine.
  Future<String?> getDefaultEngine() {
    return _ttsService.getDefaultEngine();
  }

  /// Configures speech speed and persists to local storage.
  Future<void> updateSpeechRate(double rate) async {
    await _ttsService.setSpeechRate(rate);
    final settings = _storageService.getAppSettings();
    await _storageService.saveAppSettings(settings.copyWith(speechSpeed: rate));
  }

  /// Configures pitch and persists to local storage.
  Future<void> updatePitch(String pitchLabel, double pitchValue) async {
    await _ttsService.setPitch(pitchValue);
    final settings = _storageService.getAppSettings();
    await _storageService.saveAppSettings(settings.copyWith(speechPitch: pitchLabel));
  }

  /// Enables or disables automatic translated speech playback and persists to storage.
  Future<void> setAutoPlayAudio(bool enabled) async {
    final settings = _storageService.getAppSettings();
    await _storageService.saveAppSettings(settings.copyWith(autoPlayAudio: enabled));
  }

  /// Launches the native Android Text-to-Speech system settings.
  Future<bool> openTtsSettings() {
    return _ttsService.openTtsSettings();
  }

  /// Launches the native Android Voice Data installation intent.
  Future<bool> openInstallTtsData() {
    return _ttsService.openInstallTtsData();
  }

  /// Releases native resources.
  Future<void> dispose() async {
    await _ttsService.dispose();
  }
}

