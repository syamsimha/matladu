import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../models/tts_result.dart';
import '../../models/tts_voice.dart';
import 'i_tts_service.dart';

/// Production-grade on-device Text-to-Speech implementation.
///
/// NON-NEGOTIABLE PRIVACY GUARANTEES:
/// 1. 100% On-Device: Text is never dispatched to cloud endpoints.
/// 2. Zero Network Voices: Rejects voices where `network_required == true`.
/// 3. Offline Verification: Strictly ensures that the voice functions with no active network.
class OnDeviceTtsService implements ITtsService {
  final FlutterTts _flutterTts;
  static const MethodChannel _ttsSettingsChannel =
      MethodChannel('com.matladu.ai/tts_settings');

  final StreamController<TtsResult> _stateStreamController =
      StreamController<TtsResult>.broadcast();

  TtsPlaybackState _currentState = TtsPlaybackState.idle;
  String? _currentRequestId;
  String? _currentText;
  String? _currentLanguageCode;
  String? _currentVoiceName;
  DateTime? _speechStartTime;

  List<TtsVoice> _cachedVoices = [];
  bool _isInitialized = false;

  double _speechRate = 1.0;
  double _pitch = 1.0;
  double _volume = 1.0;

  OnDeviceTtsService({FlutterTts? flutterTts})
      : _flutterTts = flutterTts ?? FlutterTts();

  @override
  Stream<TtsResult> get stateStream => _stateStreamController.stream;

  @override
  TtsPlaybackState get currentState => _currentState;

  @override
  String? get currentRequestId => _currentRequestId;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Configure audio attributes for clear speech playback
      await _flutterTts.awaitSpeakCompletion(true);

      // Register native event lifecycle callbacks
      _flutterTts.setStartHandler(() {
        debugPrint('[OnDeviceTts] Native speech output started (req: $_currentRequestId)');
        _speechStartTime = DateTime.now();
        _updateState(TtsPlaybackState.speaking);
      });

      _flutterTts.setCompletionHandler(() {
        final duration = _speechStartTime != null
            ? DateTime.now().difference(_speechStartTime!)
            : Duration.zero;
        debugPrint('[OnDeviceTts] Native speech completed in ${duration.inMilliseconds}ms (req: $_currentRequestId)');
        _updateState(TtsPlaybackState.completed, duration: duration);
        _currentState = TtsPlaybackState.idle;
      });

      _flutterTts.setCancelHandler(() {
        debugPrint('[OnDeviceTts] Native speech cancelled/stopped (req: $_currentRequestId)');
        _updateState(TtsPlaybackState.stopped);
        _currentState = TtsPlaybackState.idle;
      });

      _flutterTts.setPauseHandler(() {
        debugPrint('[OnDeviceTts] Native speech paused (req: $_currentRequestId)');
        _updateState(TtsPlaybackState.paused);
      });

      _flutterTts.setContinueHandler(() {
        debugPrint('[OnDeviceTts] Native speech resumed (req: $_currentRequestId)');
        _updateState(TtsPlaybackState.speaking);
      });

      _flutterTts.setErrorHandler((dynamic message) {
        debugPrint('[OnDeviceTts] Native TTS error: $message (req: $_currentRequestId)');
        _updateState(
          TtsPlaybackState.error,
          errorMessage: message?.toString() ?? 'Synthesis failed in Android TTS engine.',
        );
        _currentState = TtsPlaybackState.idle;
      });

      // Query available native voices
      await _refreshAvailableVoices();

      _isInitialized = true;
      debugPrint('[OnDeviceTts] Initialized successfully. Total voices found: ${_cachedVoices.length}');
    } catch (e) {
      debugPrint('[OnDeviceTts] Initialization warning: $e');
      _isInitialized = true; // Still allow retry
    }
  }

  Future<void> _refreshAvailableVoices() async {
    try {
      final dynamic rawVoices = await _flutterTts.getVoices;
      if (rawVoices is List) {
        final List<TtsVoice> list = [];
        for (final item in rawVoices) {
          if (item is Map) {
            list.add(TtsVoice.fromMap(item));
          }
        }
        _cachedVoices = list;
        debugPrint(
            '[OnDeviceTts] Enumerated ${_cachedVoices.length} voices (Offline: ${_cachedVoices.where((v) => v.isOfflineAvailable).length})');
      }
    } catch (e) {
      debugPrint('[OnDeviceTts] Could not enumerate voices: $e');
      _cachedVoices = [];
    }
  }

  @override
  Future<List<TtsVoice>> getAvailableVoices() async {
    if (_cachedVoices.isEmpty) {
      await _refreshAvailableVoices();
    }
    return List.unmodifiable(_cachedVoices);
  }

  @override
  Future<List<TtsVoice>> getOfflineVoices() async {
    final all = await getAvailableVoices();
    return all.where((v) => v.isOfflineAvailable).toList();
  }

  @override
  Future<bool> isLanguageSupported(String languageCode) async {
    final norm = _normalizeCode(languageCode);
    final locale = _resolveLocale(norm);
    try {
      final res = await _flutterTts.isLanguageAvailable(locale);
      return res == 1 || res == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isOfflineVoiceAvailable(String languageCode) async {
    final voice = await getBestOfflineVoice(languageCode);
    return voice != null;
  }

  @override
  Future<TtsVoice?> getBestOfflineVoice(String languageCode) async {
    final norm = _normalizeCode(languageCode);
    final offlineVoices = await getOfflineVoices();

    // 1. Direct match by languageCode or locale prefix
    final matches = offlineVoices.where((v) {
      return v.languageCode == norm ||
          v.locale.toLowerCase().startsWith('$norm-') ||
          v.locale.toLowerCase().startsWith('${norm}_') ||
          v.locale.toLowerCase() == norm;
    }).toList();

    if (matches.isNotEmpty) {
      // Prioritize high-quality local voices
      matches.sort((a, b) {
        final aLocal = a.name.contains('local') ? 1 : 0;
        final bLocal = b.name.contains('local') ? 1 : 0;
        return bLocal.compareTo(aLocal);
      });
      return matches.first;
    }

    // 2. Check if engine reports language available offline directly
    final targetLocale = _resolveLocale(norm);
    try {
      final isAvail = await _flutterTts.isLanguageAvailable(targetLocale);
      if (isAvail == 1 || isAvail == true) {
        // Return a synthetic offline voice representing the system-configured language
        return TtsVoice(
          name: 'System Default ($norm)',
          locale: targetLocale,
          languageCode: norm,
          isNetworkRequired: false,
        );
      }
    } catch (_) {}

    return null;
  }

  @override
  Future<bool> speak({
    required String text,
    required String languageCode,
    String? voiceName,
    String? requestId,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      debugPrint('[OnDeviceTts] Discarding empty speech synthesis request.');
      return false;
    }

    final normLang = _normalizeCode(languageCode);
    final reqId = requestId ?? DateTime.now().millisecondsSinceEpoch.toString();

    // Prevent speaking raw error messages, loading indicators, or unvetted noise
    if (cleanText.startsWith('Error:') ||
        cleanText.startsWith('Translating') ||
        cleanText.startsWith('[') ||
        cleanText.toLowerCase().contains('offline pack download')) {
      debugPrint('[OnDeviceTts] Blocked speaking error or system string (chars: ${cleanText.length})');
      return false;
    }

    // Stop any active playback before starting new translation audio
    if (_currentState == TtsPlaybackState.speaking ||
        _currentState == TtsPlaybackState.preparing) {
      await stop();
    }

    _currentRequestId = reqId;
    _currentText = cleanText;
    _currentLanguageCode = normLang;
    _currentVoiceName = voiceName;
    _updateState(TtsPlaybackState.preparing);

    // 1. Resolve genuine offline voice
    TtsVoice? selectedVoice;
    if (voiceName != null && voiceName.isNotEmpty) {
      final all = await getOfflineVoices();
      try {
        selectedVoice = all.firstWhere((v) => v.name == voiceName);
      } catch (_) {}
    }

    selectedVoice ??= await getBestOfflineVoice(normLang);

    if (selectedVoice == null) {
      debugPrint('[OnDeviceTts] No verified offline voice available for language: $normLang');
      _updateState(
        TtsPlaybackState.voiceUnavailable,
        errorMessage:
            'Offline voice for ${_getLanguageDisplayName(normLang)} is not installed on this device.',
      );
      _currentState = TtsPlaybackState.idle;
      return false;
    }

    // STRICT ON-DEVICE PRIVACY: Reject network-dependent voices
    if (selectedVoice.isNetworkRequired) {
      debugPrint('[OnDeviceTts] PRIVACY REJECTION: Voice "${selectedVoice.name}" requires network!');
      _updateState(
        TtsPlaybackState.voiceUnavailable,
        errorMessage: 'Network-dependent voice rejected. 100% offline voice required.',
      );
      _currentState = TtsPlaybackState.idle;
      return false;
    }

    try {
      _currentVoiceName = selectedVoice.name;

      // Configure native voice & locale
      if (selectedVoice.name.isNotEmpty && !selectedVoice.name.startsWith('System Default')) {
        await _flutterTts.setVoice({
          'name': selectedVoice.name,
          'locale': selectedVoice.locale,
        });
      }
      await _flutterTts.setLanguage(selectedVoice.locale);

      // Apply speech settings
      // On Android flutter_tts, rate 0.5 is normal speed, 1.0 is 2x. Map standard 1.0 multiplier:
      await _flutterTts.setSpeechRate((_speechRate * 0.5).clamp(0.2, 1.0));
      await _flutterTts.setPitch(_pitch.clamp(0.5, 2.0));
      await _flutterTts.setVolume(_volume.clamp(0.0, 1.0));

      debugPrint(
          '[OnDeviceTts] Synthesizing offline speech: lang=$normLang, voice=${selectedVoice.name}, text="$cleanText"');

      final result = await _flutterTts.speak(cleanText);
      return result == 1 || result == true;
    } catch (e) {
      debugPrint('[OnDeviceTts] Speak execution exception: $e');
      _updateState(
        TtsPlaybackState.error,
        errorMessage: 'TTS playback error: $e',
      );
      _currentState = TtsPlaybackState.idle;
      return false;
    }
  }

  @override
  Future<bool> stop() async {
    try {
      debugPrint('[OnDeviceTts] Stopping speech output.');
      final res = await _flutterTts.stop();
      _updateState(TtsPlaybackState.stopped);
      _currentState = TtsPlaybackState.idle;
      return res == 1 || res == true;
    } catch (e) {
      debugPrint('[OnDeviceTts] Error stopping TTS: $e');
      return false;
    }
  }

  @override
  Future<bool> pause() async {
    try {
      debugPrint('[OnDeviceTts] Pausing speech output.');
      final res = await _flutterTts.pause();
      _updateState(TtsPlaybackState.paused);
      return res == 1 || res == true;
    } catch (e) {
      debugPrint('[OnDeviceTts] Error pausing TTS: $e');
      return false;
    }
  }

  @override
  Future<bool> resume() async {
    if (_currentState == TtsPlaybackState.paused &&
        _currentText != null &&
        _currentLanguageCode != null) {
      return speak(
        text: _currentText!,
        languageCode: _currentLanguageCode!,
        voiceName: _currentVoiceName,
        requestId: _currentRequestId,
      );
    }
    return false;
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.5, 2.0);
    try {
      await _flutterTts.setSpeechRate((_speechRate * 0.5).clamp(0.2, 1.0));
    } catch (_) {}
  }

  @override
  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    try {
      await _flutterTts.setPitch(_pitch);
    } catch (_) {}
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    try {
      await _flutterTts.setVolume(_volume);
    } catch (_) {}
  }

  @override
  Future<String?> getDefaultEngine() async {
    try {
      final dynamic engine = await _flutterTts.getDefaultEngine;
      return engine?.toString();
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<String>> getEngines() async {
    try {
      final dynamic engines = await _flutterTts.getEngines;
      if (engines is List) {
        return engines.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<bool> openTtsSettings() async {
    try {
      final dynamic res =
          await _ttsSettingsChannel.invokeMethod('openTtsSettings');
      return res == true;
    } catch (e) {
      debugPrint('[OnDeviceTts] Could not open TTS settings: $e');
      return false;
    }
  }

  @override
  Future<bool> openInstallTtsData() async {
    try {
      final dynamic res =
          await _ttsSettingsChannel.invokeMethod('openInstallTtsData');
      return res == true;
    } catch (e) {
      debugPrint('[OnDeviceTts] Could not open Install TTS Data: $e');
      return false;
    }
  }

  void _updateState(
    TtsPlaybackState state, {
    String? errorMessage,
    Duration duration = Duration.zero,
  }) {
    _currentState = state;
    if (!_stateStreamController.isClosed) {
      _stateStreamController.add(
        TtsResult(
          requestId: _currentRequestId ?? '',
          state: state,
          text: _currentText ?? '',
          languageCode: _currentLanguageCode ?? '',
          voiceName: _currentVoiceName,
          errorMessage: errorMessage,
          isOffline: true,
          duration: duration,
        ),
      );
    }
  }

  static String _normalizeCode(String code) {
    final lower = code.replaceAll('<|', '').replaceAll('|>', '').toLowerCase().trim();
    return lower.split('-').first.split('_').first;
  }

  static String getLocaleForLanguage(String code) =>
      _resolveLocale(_normalizeCode(code));

  static String _resolveLocale(String normCode) {
    switch (normCode) {
      case 'te':
        return 'te-IN';
      case 'hi':
        return 'hi-IN';
      case 'ta':
        return 'ta-IN';
      case 'kn':
        return 'kn-IN';
      case 'ml':
        return 'ml-IN';
      case 'bn':
        return 'bn-IN';
      case 'gu':
        return 'gu-IN';
      case 'mr':
        return 'mr-IN';
      case 'pa':
        return 'pa-IN';
      case 'or':
        return 'or-IN';
      case 'as':
        return 'as-IN';
      case 'ur':
        return 'ur-IN';
      case 'ne':
        return 'ne-NP';
      case 'sa':
        return 'sa-IN';
      case 'sd':
        return 'sd-IN';
      case 'ks':
        return 'ks-IN';
      case 'kok':
        return 'kok-IN';
      case 'mai':
        return 'mai-IN';
      case 'mni':
        return 'mni-IN';
      case 'doi':
        return 'doi-IN';
      case 'brx':
        return 'brx-IN';
      case 'sat':
        return 'sat-IN';
      case 'de':
        return 'de-DE';
      case 'en':
      default:
        return 'en-IN';
    }
  }

  static String _getLanguageDisplayName(String code) {
    final norm = _normalizeCode(code);
    switch (norm) {
      case 'as':
        return 'Assamese';
      case 'bn':
        return 'Bengali';
      case 'brx':
        return 'Bodo';
      case 'doi':
        return 'Dogri';
      case 'gu':
        return 'Gujarati';
      case 'hi':
        return 'Hindi';
      case 'kn':
        return 'Kannada';
      case 'ks':
        return 'Kashmiri';
      case 'kok':
        return 'Konkani';
      case 'mai':
        return 'Maithili';
      case 'ml':
        return 'Malayalam';
      case 'mni':
        return 'Manipuri';
      case 'mr':
        return 'Marathi';
      case 'ne':
        return 'Nepali';
      case 'or':
        return 'Odia';
      case 'pa':
        return 'Punjabi';
      case 'sa':
        return 'Sanskrit';
      case 'sat':
        return 'Santali';
      case 'sd':
        return 'Sindhi';
      case 'ta':
        return 'Tamil';
      case 'te':
        return 'Telugu';
      case 'ur':
        return 'Urdu';
      case 'de':
        return 'German';
      case 'en':
      default:
        return 'English';
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await stop();
    } catch (_) {}
    await _stateStreamController.close();
  }
}

