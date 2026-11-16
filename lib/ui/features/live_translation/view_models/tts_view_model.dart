import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../data/models/tts_result.dart';
import '../../../../data/models/tts_voice.dart';
import '../../../../data/repositories/tts_repository.dart';

/// ViewModel exposing on-device Text-to-Speech state and controls to the UI.
/// Supports both automatic speech playback on translation completion and manual replay/stop.
class TtsViewModel extends ChangeNotifier {
  final TtsRepository _ttsRepository;

  StreamSubscription<TtsResult>? _stateSubscription;
  TtsPlaybackState _playbackState = TtsPlaybackState.idle;
  String? _errorMessage;
  String? _activeRequestId;
  bool _isCheckingVoices = false;
  List<TtsVoice> _offlineVoices = [];

  TtsViewModel({required TtsRepository ttsRepository})
      : _ttsRepository = ttsRepository {
    _init();
  }

  void _init() {
    _stateSubscription = _ttsRepository.stateStream.listen((result) {
      _playbackState = result.state;
      _errorMessage = result.errorMessage;
      _activeRequestId = result.requestId;
      notifyListeners();
    });
    refreshVoices();
  }

  // Getters
  TtsPlaybackState get playbackState => _playbackState;
  bool get isSpeaking => _playbackState == TtsPlaybackState.speaking;
  bool get isPaused => _playbackState == TtsPlaybackState.paused;
  bool get isVoiceUnavailable =>
      _playbackState == TtsPlaybackState.voiceUnavailable;
  bool get hasError => _playbackState == TtsPlaybackState.error;
  String? get errorMessage => _errorMessage;
  String? get activeRequestId => _activeRequestId;
  bool get autoPlayEnabled => _ttsRepository.autoPlayEnabled;
  double get speechRate => _ttsRepository.speechRate;
  List<TtsVoice> get offlineVoices => _offlineVoices;
  bool get isCheckingVoices => _isCheckingVoices;

  /// Refreshes the list of certified offline voices.
  Future<void> refreshVoices() async {
    _isCheckingVoices = true;
    notifyListeners();
    try {
      _offlineVoices = await _ttsRepository.getOfflineVoices();
    } catch (_) {
      _offlineVoices = [];
    } finally {
      _isCheckingVoices = false;
      notifyListeners();
    }
  }

  /// Checks if an offline voice is available for [languageCode].
  Future<bool> isOfflineVoiceAvailable(String languageCode) {
    return _ttsRepository.isOfflineVoiceAvailable(languageCode);
  }

  /// Automatically or manually speaks translated text.
  Future<bool> speakTranslation({
    required String text,
    required String targetLanguageCode,
    String? requestId,
    bool isAutoPlay = false,
  }) {
    return _ttsRepository.speakTranslation(
      text: text,
      targetLanguageCode: targetLanguageCode,
      requestId: requestId,
      isAutoPlay: isAutoPlay,
    );
  }

  /// Replays the current translation.
  Future<bool> replay() {
    return _ttsRepository.replayCurrentTranslation();
  }

  /// Stops current speech output immediately.
  Future<bool> stop() {
    return _ttsRepository.stop();
  }

  /// Pauses active speech output.
  Future<bool> pause() {
    return _ttsRepository.pause();
  }

  /// Resumes paused speech output.
  Future<bool> resume() {
    return _ttsRepository.resume();
  }

  /// Updates speech speed multiplier.
  Future<void> updateSpeechRate(double rate) async {
    await _ttsRepository.updateSpeechRate(rate);
    notifyListeners();
  }

  /// Updates auto-play setting.
  Future<void> setAutoPlayAudio(bool enabled) async {
    await _ttsRepository.setAutoPlayAudio(enabled);
    notifyListeners();
  }

  /// Opens Android system TTS settings.
  Future<bool> openTtsSettings() {
    return _ttsRepository.openTtsSettings();
  }

  /// Opens Android voice data install screen.
  Future<bool> openInstallTtsData() {
    return _ttsRepository.openInstallTtsData();
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    super.dispose();
  }
}

