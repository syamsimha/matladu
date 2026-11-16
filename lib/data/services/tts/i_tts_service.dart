import 'dart:async';
import '../../models/tts_result.dart';
import '../../models/tts_voice.dart';

/// Contract defining on-device Text-to-Speech synthesis.
///
/// MANDATORY PRIVACY STRICTURES:
/// 1. 100% On-Device: Text is never sent over any network socket or cloud API.
/// 2. Only genuinely offline voices (where isNetworkRequired == false) are permitted.
/// 3. Network-dependent cloud voices must be filtered out and rejected.
abstract class ITtsService {
  /// Asynchronously connects to the local Android TextToSpeech engine and discovers voices.
  Future<void> initialize();

  /// Returns all voices exposed by the installed TTS engine(s).
  Future<List<TtsVoice>> getAvailableVoices();

  /// Returns only voices certified to function 100% offline without network connectivity.
  Future<List<TtsVoice>> getOfflineVoices();

  /// Checks if the engine supports synthesizing the given language code (e.g. 'en', 'te', 'hi').
  Future<bool> isLanguageSupported(String languageCode);

  /// Checks if a compatible, verified offline voice is installed on this device for [languageCode].
  Future<bool> isOfflineVoiceAvailable(String languageCode);

  /// Resolves the optimal offline voice for the given target language.
  Future<TtsVoice?> getBestOfflineVoice(String languageCode);

  /// Speaks [text] on-device using a compatible offline voice.
  ///
  /// Rejects empty text, error messages, and network-dependent voices.
  Future<bool> speak({
    required String text,
    required String languageCode,
    String? voiceName,
    String? requestId,
  });

  /// Immediately halts active speech output.
  Future<bool> stop();

  /// Pauses active speech output (if supported by native engine).
  Future<bool> pause();

  /// Resumes paused speech output.
  Future<bool> resume();

  /// Configures speech rate multiplier (0.5x to 2.0x, 1.0 is normal).
  Future<void> setSpeechRate(double rate);

  /// Configures pitch multiplier (0.5 to 2.0, 1.0 is normal).
  Future<void> setPitch(double pitch);

  /// Configures output volume (0.0 to 1.0).
  Future<void> setVolume(double volume);

  /// Returns the name of the active native Android TTS engine package.
  Future<String?> getDefaultEngine();

  /// Returns list of all installed Android TTS engines.
  Future<List<String>> getEngines();

  /// Launches the native Android Text-to-Speech system settings.
  Future<bool> openTtsSettings();

  /// Launches the native Android Voice Data installation intent.
  Future<bool> openInstallTtsData();

  /// Emits real-time playback state updates.
  Stream<TtsResult> get stateStream;

  /// Current playback state of the TTS engine.
  TtsPlaybackState get currentState;

  /// Active request identifier, if speech is currently in progress.
  String? get currentRequestId;

  /// Cleans up native engine resources and stream subscriptions.
  Future<void> dispose();
}

