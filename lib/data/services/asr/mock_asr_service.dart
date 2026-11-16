import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/asr_state.dart';
import '../../models/audio_recording_state.dart';
import 'i_asr_service.dart';

/// Offline mock implementation of [IASRService] for local development and automated testing.
///
/// STRICT GUARANTEES:
/// - 100% offline — zero external HTTP requests, WebSockets, or network sockets.
/// - Zero audio egress — captured PCM chunks never leave memory.
/// - Transparently tags all emitted transcripts with `isMock: true` and a visible `[Mock ASR]` suffix
///   so mock results are never presented as real speech recognition.
class MockASRService implements IASRService {
  ASRState _currentState = ASRState.idle;
  ASRRecognitionResult? _lastResult;

  final StreamController<ASRRecognitionResult> _resultController =
      StreamController<ASRRecognitionResult>.broadcast();
  final StreamController<ASRState> _stateController =
      StreamController<ASRState>.broadcast();

  StreamSubscription<Uint8List>? _streamSubscription;
  int _accumulatedBytes = 0;
  String? _activeLanguageHint;
  int _partialStep = 0;
  Timer? _interimTimer;

  // Realistic sample phrases for offline testing by language
  static const Map<String, List<String>> _mockLanguagePhrases = {
    'te': [
      'నమస్తే...',
      'నమస్తే, మీరు...',
      'నమస్తే, మీరు ఎలా ఉన్నారు? [Mock ASR]',
    ],
    'te-IN': [
      'నమస్తే...',
      'నమస్తే, మీరు...',
      'నమస్తే, మీరు ఎలా ఉన్నారు? [Mock ASR]',
    ],
    'hi': [
      'नमस्ते...',
      'नमस्ते, आप...',
      'नमस्ते, आप कैसे हैं? [Mock ASR]',
    ],
    'hi-IN': [
      'नमस्ते...',
      'नमस्ते, आप...',
      'नमस्ते, आप कैसे हैं? [Mock ASR]',
    ],
    'en': [
      'Hello...',
      'Hello, how...',
      'Hello, how are you? [Mock ASR]',
    ],
    'en-IN': [
      'Hello...',
      'Hello, how...',
      'Hello, how are you? [Mock ASR]',
    ],
    'ta': [
      'வணக்கம்...',
      'வணக்கம், நீங்கள்...',
      'வணக்கம், நீங்கள் எப்படி இருக்கிறீர்கள்? [Mock ASR]',
    ],
    'ta-IN': [
      'வணக்கம்...',
      'வணக்கம், நீங்கள்...',
      'வணக்கம், நீங்கள் எப்படி இருக்கிறீர்கள்? [Mock ASR]',
    ],
    'kn': [
      'ನಮಸ್ಕಾರ...',
      'ನಮಸ್ಕಾರ, ನೀವು...',
      'ನಮಸ್ಕಾರ, ನೀವು ಹೇಗಿದ್ದೀರಿ? [Mock ASR]',
    ],
    'kn-IN': [
      'ನಮಸ್ಕಾರ...',
      'ನಮಸ್ಕಾರ, ನೀವು...',
      'ನಮಸ್ಕಾರ, ನೀವು ಹೇಗಿದ್ದೀರಿ? [Mock ASR]',
    ],
    'tenglish': [
      'Nenu repu...',
      'Nenu repu office ki...',
      'Nenu repu office ki vellali. [Mock ASR]',
    ],
  };

  @override
  Stream<ASRRecognitionResult> get resultStream => _resultController.stream;

  @override
  Stream<ASRState> get stateStream => _stateController.stream;

  @override
  ASRState get currentState => _currentState;

  @override
  ASRRecognitionResult? get lastResult => _lastResult;

  @override
  bool get isNativeCapture => false;

  void _setState(ASRState state) {
    if (_currentState == state) return;
    _currentState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  void _emitResult(ASRRecognitionResult result) {
    _lastResult = result;
    if (!_resultController.isClosed) {
      _resultController.add(result);
    }
  }

  @override
  Future<void> initialize() async {
    _setState(ASRState.idle);
    debugPrint('[MockASRService] Initialized (Offline Mode, 0 network egress).');
  }

  @override
  Future<void> startStreamingRecognition(
    Stream<Uint8List> pcmStream, {
    required AudioCaptureConfig audioConfig,
    String? languageCodeHint,
  }) async {
    await _streamSubscription?.cancel();
    _interimTimer?.cancel();

    _accumulatedBytes = 0;
    _partialStep = 0;
    _activeLanguageHint = languageCodeHint;
    _setState(ASRState.listening);

    final langKey = _resolveLanguageKey(languageCodeHint);
    final phrases = _mockLanguagePhrases[langKey] ?? _mockLanguagePhrases['en']!;

    _streamSubscription = pcmStream.listen((chunk) {
      _accumulatedBytes += chunk.length;

      // Simulate partial interim recognition after sufficient audio frames arrive (> 16,000 bytes = 0.5s)
      if (_accumulatedBytes > 16000 && _partialStep == 0) {
        _partialStep = 1;
        _emitResult(
          ASRRecognitionResult(
            text: phrases[0],
            isFinal: false,
            confidence: 0.85,
            detectedLanguageCode: langKey,
            detectedLanguageName: _resolveLanguageName(langKey),
            audioDuration: Duration(milliseconds: (_accumulatedBytes / 32).round()),
            timestamp: DateTime.now(),
            isMock: true,
          ),
        );
      } else if (_accumulatedBytes > 32000 && _partialStep == 1) {
        _partialStep = 2;
        _emitResult(
          ASRRecognitionResult(
            text: phrases[1],
            isFinal: false,
            confidence: 0.90,
            detectedLanguageCode: langKey,
            detectedLanguageName: _resolveLanguageName(langKey),
            audioDuration: Duration(milliseconds: (_accumulatedBytes / 32).round()),
            timestamp: DateTime.now(),
            isMock: true,
          ),
        );
      }
    });

    debugPrint('[MockASRService] Streaming recognition started for language hint: $languageCodeHint');
  }

  @override
  Future<ASRRecognitionResult> stopStreamingRecognition({Uint8List? recordedPcm}) async {
    _setState(ASRState.transcribing);
    _interimTimer?.cancel();
    await _streamSubscription?.cancel();
    _streamSubscription = null;

    final totalBytes = (recordedPcm != null && recordedPcm.isNotEmpty)
        ? recordedPcm.length
        : _accumulatedBytes;
    final duration = Duration(milliseconds: (totalBytes / 32).round());

    // Check for silence or insufficient audio (< 200 ms or < 6,400 bytes)
    if (totalBytes < 6400) {
      final silenceResult = ASRRecognitionResult(
        text: '',
        isFinal: true,
        confidence: 0.0,
        audioDuration: duration,
        timestamp: DateTime.now(),
        isMock: true,
        errorMessage: 'No speech detected. Please speak into the microphone. [Mock ASR]',
      );
      _setState(ASRState.error);
      _emitResult(silenceResult);
      return silenceResult;
    }

    final langKey = _resolveLanguageKey(_activeLanguageHint);
    final phrases = _mockLanguagePhrases[langKey] ?? _mockLanguagePhrases['en']!;
    final finalText = phrases.last;

    final finalResult = ASRRecognitionResult(
      text: finalText,
      isFinal: true,
      confidence: 0.96,
      detectedLanguageCode: langKey,
      detectedLanguageName: _resolveLanguageName(langKey),
      audioDuration: duration,
      timestamp: DateTime.now(),
      isMock: true,
    );

    _setState(ASRState.completed);
    _emitResult(finalResult);

    debugPrint('[MockASRService] Streaming recognition finalized: $finalResult');
    return finalResult;
  }

  @override
  Future<ASRRecognitionResult> transcribePcmBuffer(
    Uint8List pcmBytes, {
    required AudioCaptureConfig audioConfig,
    String? languageCodeHint,
  }) async {
    _setState(ASRState.transcribing);

    final duration = Duration(milliseconds: (pcmBytes.length / (audioConfig.bytesPerSecond / 1000)).round());

    if (pcmBytes.length < 6400) {
      final silenceResult = ASRRecognitionResult(
        text: '',
        isFinal: true,
        confidence: 0.0,
        audioDuration: duration,
        timestamp: DateTime.now(),
        isMock: true,
        errorMessage: 'Audio buffer contains insufficient speech data. [Mock ASR]',
      );
      _setState(ASRState.error);
      _emitResult(silenceResult);
      return silenceResult;
    }

    final langKey = _resolveLanguageKey(languageCodeHint);
    final phrases = _mockLanguagePhrases[langKey] ?? _mockLanguagePhrases['en']!;
    final finalText = phrases.last;

    final result = ASRRecognitionResult(
      text: finalText,
      isFinal: true,
      confidence: 0.95,
      detectedLanguageCode: langKey,
      detectedLanguageName: _resolveLanguageName(langKey),
      audioDuration: duration,
      timestamp: DateTime.now(),
      isMock: true,
    );

    _setState(ASRState.completed);
    _emitResult(result);
    return result;
  }

  @override
  Future<void> cancelRecognition() async {
    _interimTimer?.cancel();
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    _accumulatedBytes = 0;
    _partialStep = 0;
    _setState(ASRState.idle);
    debugPrint('[MockASRService] Recognition cancelled.');
  }

  @override
  void reset() {
    cancelRecognition();
    _lastResult = null;
  }

  @override
  Future<void> dispose() async {
    await cancelRecognition();
    if (!_resultController.isClosed) await _resultController.close();
    if (!_stateController.isClosed) await _stateController.close();
  }

  String _resolveLanguageKey(String? code) {
    if (code == null || code == 'auto') return 'te';
    final lower = code.toLowerCase().trim();
    if (lower.startsWith('te')) return 'te';
    if (lower.startsWith('hi')) return 'hi';
    if (lower.startsWith('ta')) return 'ta';
    if (lower.startsWith('kn')) return 'kn';
    if (lower.startsWith('en')) return 'en';
    return lower;
  }

  String _resolveLanguageName(String key) {
    switch (key) {
      case 'te':
      case 'te-IN':
        return 'Telugu';
      case 'hi':
      case 'hi-IN':
        return 'Hindi';
      case 'ta':
      case 'ta-IN':
        return 'Tamil';
      case 'kn':
      case 'kn-IN':
        return 'Kannada';
      case 'en':
      case 'en-IN':
        return 'English';
      default:
        return 'English';
    }
  }
}
