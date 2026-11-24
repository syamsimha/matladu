import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../models/asr_state.dart';
import '../../models/audio_recording_state.dart';
import '../../models/language_registry.dart';
import 'i_asr_service.dart';

/// Platform-native Android SpeechRecognizer service (Google Speech Services).
///
/// COMPLIANCE & PRIVACY:
/// - Used ONLY in Online Mode for verified supported languages.
/// - Requires explicit user consent before audio is captured or transmitted.
/// - Never claimed as "zero audio egress" (audio is processed by Google's cloud servers).
/// - If consent is revoked or language is unsupported, speech recognition routes to on-device Whisper.
class AndroidSpeechRecognizerService implements IASRService {
  static const MethodChannel _channel = MethodChannel('com.matladu.ai/speech_recognizer');

  /// The 12 verified languages supported by Google Speech Services on Android.
  static Set<String> get verifiedSupportedLanguages =>
      LanguageRegistry.googleSpeechSupportedCodes;

  final _resultController = StreamController<ASRRecognitionResult>.broadcast();
  final _stateController = StreamController<ASRState>.broadcast();

  ASRState _currentState = ASRState.idle;
  ASRRecognitionResult? _lastResult;
  Completer<ASRRecognitionResult>? _finalResultCompleter;
  String? _activeLanguageCode;
  DateTime? _recognitionStartTime;

  AndroidSpeechRecognizerService() {
    try {
      _channel.setMethodCallHandler(_handleMethodCall);
    } catch (_) {}
  }

  @override
  Stream<ASRRecognitionResult> get resultStream => _resultController.stream;

  @override
  Stream<ASRState> get stateStream => _stateController.stream;

  @override
  ASRState get currentState => _currentState;

  @override
  ASRRecognitionResult? get lastResult => _lastResult;

  @override
  bool get isNativeCapture => true;

  static bool isLanguageSupported(String? languageCode) {
    if (languageCode == null || languageCode.isEmpty || languageCode == 'auto') {
      return false; // Auto-detection requires on-device Whisper acoustic LID
    }
    final cap = LanguageRegistry.getCapability(languageCode);
    return cap?.isGoogleSpeechSupported ?? false;
  }

  static String resolveLocale(String languageCode) {
    return LanguageRegistry.getGoogleSpeechLocale(languageCode);
  }

  void _setState(ASRState newState) {
    _currentState = newState;
    _stateController.add(newState);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPartialResult':
        final text = call.arguments as String? ?? '';
        final elapsed = _recognitionStartTime != null
            ? DateTime.now().difference(_recognitionStartTime!)
            : Duration.zero;
        final interim = ASRRecognitionResult(
          text: text,
          isFinal: false,
          confidence: 0.85,
          detectedLanguageCode: _activeLanguageCode,
          audioDuration: elapsed,
          timestamp: DateTime.now(),
          isMock: false,
        );
        _lastResult = interim;
        _resultController.add(interim);
        break;

      case 'onFinalResult':
        final args = call.arguments as Map<dynamic, dynamic>? ?? {};
        final text = args['text'] as String? ?? '';
        final conf = (args['confidence'] as num?)?.toDouble() ?? 0.95;
        final elapsed = _recognitionStartTime != null
            ? DateTime.now().difference(_recognitionStartTime!)
            : Duration.zero;
        final finalRes = ASRRecognitionResult(
          text: text,
          isFinal: true,
          confidence: conf,
          detectedLanguageCode: _activeLanguageCode,
          audioDuration: elapsed,
          timestamp: DateTime.now(),
          isMock: false,
        );
        _lastResult = finalRes;
        _resultController.add(finalRes);
        _setState(ASRState.completed);
        if (_finalResultCompleter != null && !_finalResultCompleter!.isCompleted) {
          _finalResultCompleter!.complete(finalRes);
        }
        break;

      case 'onError':
        final errMsg = call.arguments as String? ?? 'Speech recognition error';
        final elapsed = _recognitionStartTime != null
            ? DateTime.now().difference(_recognitionStartTime!)
            : Duration.zero;
        final errRes = ASRRecognitionResult.error(
          errorMessage: errMsg,
          audioDuration: elapsed,
          isMock: false,
        );
        _lastResult = errRes;
        _resultController.add(errRes);
        _setState(ASRState.error);
        if (_finalResultCompleter != null && !_finalResultCompleter!.isCompleted) {
          _finalResultCompleter!.complete(errRes);
        }
        break;

      case 'onStateChanged':
        final st = call.arguments as String? ?? '';
        if (st == 'listening') {
          _setState(ASRState.listening);
        } else if (st == 'transcribing') {
          _setState(ASRState.transcribing);
        }
        break;
    }
  }

  @override
  Future<void> initialize() async {
    _setState(ASRState.idle);
  }

  @override
  Future<void> startStreamingRecognition(
    Stream<Uint8List> pcmStream, {
    required AudioCaptureConfig audioConfig,
    String? languageCodeHint,
  }) async {
    _recognitionStartTime = DateTime.now();
    _activeLanguageCode = languageCodeHint;
    _finalResultCompleter = Completer<ASRRecognitionResult>();
    _setState(ASRState.listening);

    final locale = resolveLocale(languageCodeHint ?? 'en');
    debugPrint(
      '[AndroidSpeechRecognizerService] Starting speech recognition (Locale: $locale). Notice: Audio processed via Google Speech Services.',
    );

    try {
      await _channel.invokeMethod('startListening', {'locale': locale});
    } on MissingPluginException {
      // Mock / non-Android environment: emit completed mock transcript
      debugPrint('[AndroidSpeechRecognizerService] MissingPluginException: native recognizer unavailable.');
      _setState(ASRState.completed);
    } catch (e) {
      debugPrint('[AndroidSpeechRecognizerService] Error starting native speech recognition: $e');
      _setState(ASRState.error);
    }
  }

  @override
  Future<ASRRecognitionResult> stopStreamingRecognition({Uint8List? recordedPcm}) async {
    _setState(ASRState.transcribing);
    try {
      await _channel.invokeMethod('stopListening');
    } catch (_) {}

    if (_finalResultCompleter != null) {
      try {
        return await _finalResultCompleter!.future.timeout(
          const Duration(seconds: 4),
          onTimeout: () {
            final res = _lastResult ??
                ASRRecognitionResult.error(
                  errorMessage: 'Speech recognition timed out.',
                  isMock: false,
                );
            return res;
          },
        );
      } catch (_) {}
    }

    final fallback = _lastResult ??
        ASRRecognitionResult.error(
          errorMessage: 'No speech recognized.',
          isMock: false,
        );
    _setState(fallback.hasError ? ASRState.error : ASRState.completed);
    return fallback;
  }

  @override
  Future<ASRRecognitionResult> transcribePcmBuffer(
    Uint8List pcmBytes, {
    required AudioCaptureConfig audioConfig,
    String? languageCodeHint,
  }) async {
    // Android SpeechRecognizer operates on live microphone intent; standalone buffer fallback
    return ASRRecognitionResult.error(
      errorMessage: 'Standalone buffer transcription requires on-device Whisper model.',
      isMock: false,
    );
  }

  @override
  Future<void> cancelRecognition() async {
    try {
      await _channel.invokeMethod('cancel');
    } catch (_) {}
    _setState(ASRState.idle);
    if (_finalResultCompleter != null && !_finalResultCompleter!.isCompleted) {
      _finalResultCompleter!.complete(ASRRecognitionResult.empty());
    }
  }

  @override
  void reset() {
    _lastResult = null;
    _activeLanguageCode = null;
    _setState(ASRState.idle);
  }

  @override
  Future<void> dispose() async {
    try {
      await _channel.invokeMethod('cancel');
    } catch (_) {}
    await _resultController.close();
    await _stateController.close();
  }
}
