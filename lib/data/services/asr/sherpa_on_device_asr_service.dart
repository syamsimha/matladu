import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../models/asr_state.dart';
import '../../models/audio_recording_state.dart';
import '../../models/language_registry.dart';
import 'i_asr_service.dart';
import 'model_manager_service.dart';
import 'pcm_converter.dart';
import 'transcript_validator.dart';

/// Production-ready on-device speech recognition service powered by `sherpa_onnx`.
///
/// 100% PRIVATE & ON-DEVICE:
/// - Audio NEVER leaves the physical device.
/// - Operates fully offline without internet or cloud APIs.
/// - Ingests 16 kHz Mono 16-bit PCM streaming audio from Phase 2 [AudioRepository].
class SherpaOnDeviceASRService implements IASRService {
  final ModelManagerService _modelManager;
  final IASRService? _fallbackService;

  SherpaOnDeviceASRService({
    required ModelManagerService modelManager,
    IASRService? fallbackService,
  })  : _modelManager = modelManager,
        _fallbackService = fallbackService;

  final _resultController = StreamController<ASRRecognitionResult>.broadcast();
  final _stateController = StreamController<ASRState>.broadcast();

  ASRState _currentState = ASRState.idle;
  ASRRecognitionResult? _lastResult;

  bool _bindingsInitialized = false;
  bool _initAttempted = false;
  String? _loadedLanguageCode;
  sherpa.OfflineRecognizer? _offlineRecognizer;
  sherpa.OnlineRecognizer? _onlineRecognizer;
  sherpa.OnlineStream? _activeOnlineStream;

  StreamSubscription<Uint8List>? _pcmSubscription;
  StreamSubscription<ASRState>? _fallbackStateSub;
  StreamSubscription<ASRRecognitionResult>? _fallbackResultSub;
  final BytesBuilder _bufferedPcm = BytesBuilder(copy: false);
  String? _activeLanguageHint;
  DateTime? _recognitionStartTime;

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

  ModelManagerService get modelManager => _modelManager;

  bool get isNativeReady => _bindingsInitialized;

  @override
  Future<void> initialize() async {
    if (_initAttempted) return;
    _initAttempted = true;

    try {
      if (kIsWeb) {
        await sherpa.initBindingsAsync();
        _bindingsInitialized = true;
      } else if (Platform.isAndroid || Platform.isIOS) {
        sherpa.initBindings();
        _bindingsInitialized = true;
        debugPrint('[SherpaASR] Native mobile sherpa-onnx bindings successfully loaded.');
      } else {
        // Desktop / Host: native ASR library is bundled for Android & iOS targets
        _bindingsInitialized = false;
        debugPrint('[SherpaASR] Desktop environment: native on-device ASR reserved for mobile runtime.');
      }
    } catch (e) {
      _bindingsInitialized = false;
      debugPrint('[SherpaASR] Native bindings could not be loaded: $e');
    }

    if (_fallbackService != null) {
      await _fallbackService.initialize();
    }

    // Pre-warm the multilingual Whisper recognizer so the first microphone tap responds instantly
    if (_bindingsInitialized && !kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      unawaited(_ensureRecognizerReady('auto').catchError((e) {
        debugPrint('[SherpaASR] Pre-warming Whisper recognizer failed: $e');
        return false;
      }));
    }
  }

  @override
  Future<void> startStreamingRecognition(
    Stream<Uint8List> pcmStream, {
    required AudioCaptureConfig audioConfig,
    String? languageCodeHint,
  }) async {
    _activeLanguageHint = languageCodeHint;
    _bufferedPcm.clear();

    // 1. Try to initialize native recognizer with installed on-device model
    final initialized = await _ensureRecognizerReady(languageCodeHint);
    _recognitionStartTime = DateTime.now();

    if (!initialized) {
      if (_fallbackService != null) {
        debugPrint('[SherpaASR] Falling back to configured fallback ASR adapter.');
        await _cancelFallbackSubs();
        _fallbackStateSub = _fallbackService.stateStream.listen((state) => _updateState(state));
        _fallbackResultSub = _fallbackService.resultStream.listen((res) => _emitResult(res));
        await _fallbackService.startStreamingRecognition(
          pcmStream,
          audioConfig: audioConfig,
          languageCodeHint: languageCodeHint,
        );
        return;
      }

      _updateState(ASRState.error);
      _emitResult(
        ASRRecognitionResult.error(
          errorMessage: 'On-device model pack not installed. Please download an offline pack.',
          isMock: false,
        ),
      );
      return;
    }

    _updateState(ASRState.listening);

    // 2. Consume real-time incoming 16-bit PCM chunks
    _pcmSubscription = pcmStream.listen(
      (chunk) {
        if (chunk.isEmpty) return;
        _bufferedPcm.add(chunk);

        // Feed samples to online stream if streaming recognizer is active
        if (_onlineRecognizer != null && _activeOnlineStream != null) {
          final floatSamples = PCMConverter.pcm16ToFloat32(chunk);
          _activeOnlineStream!.acceptWaveform(
            samples: floatSamples,
            sampleRate: audioConfig.sampleRate,
          );

          while (_onlineRecognizer!.isReady(_activeOnlineStream!)) {
            _onlineRecognizer!.decode(_activeOnlineStream!);
          }

          final partialResult = _onlineRecognizer!.getResult(_activeOnlineStream!);
          if (partialResult.text.isNotEmpty) {
            _emitResult(
              ASRRecognitionResult(
                text: partialResult.text,
                isFinal: false,
                confidence: 0.90,
                detectedLanguageCode: _activeLanguageHint ?? 'te',
                detectedLanguageName: _resolveLanguageName(_activeLanguageHint),
                audioDuration: DateTime.now().difference(_recognitionStartTime!),
                timestamp: DateTime.now(),
                isMock: false,
              ),
            );
          }
        }
      },
      onError: (e) {
        debugPrint('[SherpaASR] PCM audio stream error: $e');
        _updateState(ASRState.error);
      },
    );
  }

  @override
  Future<ASRRecognitionResult> stopStreamingRecognition({Uint8List? recordedPcm}) async {
    await _pcmSubscription?.cancel();
    _pcmSubscription = null;

    if (_fallbackService != null && (_onlineRecognizer == null && _offlineRecognizer == null)) {
      final res = await _fallbackService.stopStreamingRecognition(recordedPcm: recordedPcm);
      _emitResult(res);
      _updateState(ASRState.completed);
      await _cancelFallbackSubs();
      return res;
    }

    _updateState(ASRState.transcribing);

    // Prioritize audio buffer from AudioRepository if provided (guarantees zero dropped chunks)
    final capturedBytes = (recordedPcm != null && recordedPcm.isNotEmpty)
        ? recordedPcm
        : _bufferedPcm.takeBytes();
    final duration = Duration(milliseconds: (capturedBytes.length * 1000) ~/ 32000);

    if (capturedBytes.isEmpty) {
      final emptyResult = ASRRecognitionResult(
        text: '',
        isFinal: true,
        confidence: 0.0,
        detectedLanguageCode: _activeLanguageHint,
        detectedLanguageName: _resolveLanguageName(_activeLanguageHint),
        audioDuration: duration,
        timestamp: DateTime.now(),
        isMock: false,
      );
      _emitResult(emptyResult);
      _updateState(ASRState.completed);
      return emptyResult;
    }

    // Compute audio diagnostic metrics on captured buffer
    final peakAmplitude = PCMConverter.computePeakAmplitude(capturedBytes);
    final nonZeroBytes = PCMConverter.countNonZeroBytes(capturedBytes);
    final rms = PCMConverter.computeRms(capturedBytes);
    final maxWinRms = PCMConverter.computeMaxWindowRms(capturedBytes);

    debugPrint('[SherpaASR] Audio Analysis: length=${capturedBytes.length} bytes (${duration.inMilliseconds}ms), peak=$peakAmplitude/32767, nonZeroBytes=$nonZeroBytes/${capturedBytes.length}, rms=${rms.toStringAsFixed(6)}, maxWinRms=${maxWinRms.toStringAsFixed(6)}');

    // Silence detection: prevent Whisper hallucination only on true digital silence or sub-syllable blips (<100ms)
    final isTooShort = capturedBytes.length < 3200;
    final isPureSilence = nonZeroBytes == 0 || (peakAmplitude < 40 && maxWinRms < 0.0003);

    if (isTooShort || isPureSilence) {
      debugPrint('[SherpaASR] True silence/insufficient audio detected (length: ${capturedBytes.length}, peak: $peakAmplitude, maxWinRms: ${maxWinRms.toStringAsFixed(6)}). Returning empty transcription.');
      final emptyResult = ASRRecognitionResult(
        text: '',
        isFinal: true,
        confidence: 0.0,
        detectedLanguageCode: _activeLanguageHint,
        detectedLanguageName: _resolveLanguageName(_activeLanguageHint),
        audioDuration: duration,
        timestamp: DateTime.now(),
        isMock: false,
      );
      _emitResult(emptyResult);
      _updateState(ASRState.completed);
      return emptyResult;
    }

    try {
      // Dynamic range optimization: normalize low microphone signals (common on Android devices like Vivo)
      final rawFloatSamples = PCMConverter.pcm16ToFloat32(capturedBytes);
      final floatSamples = (peakAmplitude > 40 && peakAmplitude < 14000)
          ? PCMConverter.optimizeDynamicRange(rawFloatSamples)
          : rawFloatSamples;
      final (minFloat, maxFloat) = PCMConverter.computeFloatMinMax(floatSamples);
      final floatRms = PCMConverter.computeFloatRms(floatSamples);

      debugPrint('=== [SherpaASR] PRE-FLIGHT NATIVE INFERENCE METRICS ===');
      debugPrint('  Input PCM Bytes: ${capturedBytes.length}');
      debugPrint('  Float Samples: ${floatSamples.length} (sampleRate=16000)');
      debugPrint('  Int16 Peak: $peakAmplitude / 32767 (${(peakAmplitude / 327.67).toStringAsFixed(1)}% full scale)');
      debugPrint('  Non-zero Bytes: $nonZeroBytes / ${capturedBytes.length} (${(nonZeroBytes * 100 / capturedBytes.length).toStringAsFixed(1)}%)');
      debugPrint('  Float Min/Max: [${minFloat.toStringAsFixed(6)}, ${maxFloat.toStringAsFixed(6)}]');
      debugPrint('  RMS (PCM): ${rms.toStringAsFixed(6)}, RMS (Float): ${floatRms.toStringAsFixed(6)}');
      debugPrint('  Max Window RMS: ${maxWinRms.toStringAsFixed(6)}');
      debugPrint('  Acoustic Duration: ${duration.inMilliseconds} ms');
      debugPrint('  Language Hint: "$_activeLanguageHint"');
      debugPrint('  Active Recognizer: ${_offlineRecognizer != null ? "OfflineWhisper" : (_onlineRecognizer != null ? "Online" : "NONE")}');
      debugPrint('=======================================================');

      // Concurrency/state recovery: If recognizer is not ready, attempt initialization
      if (_offlineRecognizer == null && _onlineRecognizer == null) {
        debugPrint('[SherpaASR] Recognizer uninitialized at stop. Attempting recovery...');
        await _ensureRecognizerReady(_activeLanguageHint);
      }

      if (_offlineRecognizer == null && _onlineRecognizer == null) {
        debugPrint('[SherpaASR] ERROR: No native ASR recognizer available. Model files missing or corrupted.');
        final err = ASRRecognitionResult.error(
          errorMessage: 'On-device speech recognition model not installed or loaded.',
          audioDuration: duration,
          isMock: false,
        );
        _emitResult(err);
        _updateState(ASRState.error);
        return err;
      }

      String finalText = '';
      String detectedLang = (_activeLanguageHint == null || _activeLanguageHint == 'auto') ? 'und' : _activeLanguageHint!;
      double detectionConfidence = 0.0;
      String? errorMessage;
      if (_offlineRecognizer != null) {
        final decodeStopwatch = Stopwatch()..start();
        final stream = _offlineRecognizer!.createStream();

        // 1. Explicit per-stream language hint: When user selects Telugu/Hindi/English,
        // force Whisper to decode in that language rather than hallucinating foreign syllables.
        if (_activeLanguageHint != null &&
            _activeLanguageHint != 'auto' &&
            _activeLanguageHint!.isNotEmpty) {
          try {
            stream.setOption(key: 'language', value: _activeLanguageHint!);
          } catch (e) {
            debugPrint('[SherpaASR] stream.setOption language failed: $e');
          }
        }
        try {
          stream.setOption(key: 'task', value: 'transcribe');
        } catch (_) {}

        stream.acceptWaveform(samples: floatSamples, sampleRate: 16000);
        _offlineRecognizer!.decode(stream);
        final res = _offlineRecognizer!.getResult(stream);
        decodeStopwatch.stop();

        // 2. Production transcript validation & hallucination detection
        final valResult = TranscriptValidator.validate(
          res.text,
          expectedLanguageCode: _activeLanguageHint,
        );

        finalText = valResult.isValid ? valResult.cleanedText : '';

        // 3. Grounded Acoustic Language Identification Strategy:
        // Priority 1: User explicit manual source selection (e.g. 'te', 'hi', 'en', 'de').
        // Priority 2: Whisper acoustic language classification (<|te|>, <|hi|>, <|ta|>, <|kn|>, <|en|>, <|de|>, etc.).
        // Priority 3: Native script verification across all 24 supported languages.
        // RULE: Unicode script inspection must NEVER override acoustic detection to force English
        // for Romanized Indic words. If acoustic detection is uncertain, return explicit 'und'.
        final validSupported = LanguageRegistry.allLanguageCodes;
        final validIndic = LanguageRegistry.allLanguageCodes.where((c) => c != 'en' && c != 'de').toSet();

        if (_activeLanguageHint != null &&
            _activeLanguageHint != 'auto' &&
            _activeLanguageHint!.isNotEmpty) {
          detectedLang = _activeLanguageHint!;
          detectionConfidence = 0.95;
        } else if (res.lang.isNotEmpty) {
          final rawModelLang = res.lang.replaceAll('<|', '').replaceAll('|>', '').trim().toLowerCase();
          if (validSupported.contains(rawModelLang)) {
            detectedLang = rawModelLang;
            detectionConfidence = 0.90;
          } else if (LanguageRegistry.isLanguageSupported(valResult.resolvedScript)) {
            detectedLang = valResult.resolvedScript;
            detectionConfidence = 0.88;
          } else {
            detectedLang = 'und';
            detectionConfidence = 0.0;
            errorMessage = 'Language detection ambiguous. Please select your source language manually.';
          }
        } else if (LanguageRegistry.isLanguageSupported(valResult.resolvedScript)) {
          detectedLang = valResult.resolvedScript;
          detectionConfidence = 0.88;
        } else {
          detectedLang = 'und';
          detectionConfidence = 0.0;
          errorMessage = 'Language detection ambiguous. Please select your source language manually.';
        }

        // Acoustic second-pass decoding: If Whisper acoustically detected an Indian language (e.g. 'te', 'hi', 'ta', 'kn')
        // but the unconstrained first-pass emitted Romanized text, re-decode constrained to the detected acoustic language!
        if ((_activeLanguageHint == null || _activeLanguageHint == 'auto') &&
            validIndic.contains(detectedLang) &&
            valResult.resolvedScript != detectedLang) {
          debugPrint('[SherpaASR] Second-pass decoding constrained to acoustic language: $detectedLang');
          final secondStream = _offlineRecognizer!.createStream();
          try {
            secondStream.setOption(key: 'language', value: detectedLang);
            secondStream.setOption(key: 'task', value: 'transcribe');
            secondStream.acceptWaveform(samples: floatSamples, sampleRate: 16000);
            _offlineRecognizer!.decode(secondStream);
            final secondRes = _offlineRecognizer!.getResult(secondStream);
            final secondVal = TranscriptValidator.validate(
              secondRes.text,
              expectedLanguageCode: detectedLang,
            );
            if (secondVal.isValid && secondVal.cleanedText.isNotEmpty) {
              finalText = secondVal.cleanedText;
              detectionConfidence = 0.94;
              debugPrint('[SherpaASR] Second-pass succeeded: "$finalText" (Lang: $detectedLang)');
            }
          } catch (e) {
            debugPrint('[SherpaASR] Second-pass failed: $e');
          } finally {
            secondStream.free();
          }
        }

        if ((_activeLanguageHint == null || _activeLanguageHint == 'auto') &&
            (detectedLang == 'und' || res.tokens.isEmpty)) {
          errorMessage = 'Language detection ambiguous. Please select your source language manually.';
        }

        if (!valResult.isValid && valResult.isHallucination) {
          errorMessage = 'Speech unclear — please speak clearly into the microphone.';
          debugPrint('[SherpaASR] Hallucination loop detected and suppressed: ${valResult.reason}');
        }

        debugPrint('=== [SherpaASR] NATIVE WHISPER DECODE RESULT ===');
        debugPrint('  Inference Latency: ${decodeStopwatch.elapsedMilliseconds} ms');
        debugPrint('  Decoded Raw Text: "${res.text}"');
        debugPrint('  Cleaned Valid Text: "$finalText" (Valid: ${valResult.isValid})');
        debugPrint('  Raw Model Lang: "${res.lang}" -> Resolved: "$detectedLang"');
        debugPrint('  Resolved Script: ${valResult.resolvedScript}');
        debugPrint('  Tokens Count: ${res.tokens.length}');
        debugPrint('  Tokens: ${res.tokens}');
        debugPrint('================================================');

        stream.free();
      } else if (_onlineRecognizer != null && _activeOnlineStream != null) {
        _activeOnlineStream!.inputFinished();
        while (_onlineRecognizer!.isReady(_activeOnlineStream!)) {
          _onlineRecognizer!.decode(_activeOnlineStream!);
        }
        final rawOnline = _onlineRecognizer!.getResult(_activeOnlineStream!).text.trim();
        final val = TranscriptValidator.validate(rawOnline, expectedLanguageCode: _activeLanguageHint);
        finalText = val.isValid ? val.cleanedText : '';
        detectedLang = (_activeLanguageHint != null && _activeLanguageHint != 'auto') ? _activeLanguageHint! : 'en';
        detectionConfidence = finalText.isNotEmpty ? 0.90 : 0.0;
      }

      final isInvalidResult = errorMessage != null ||
          (finalText.isEmpty && capturedBytes.isNotEmpty) ||
          detectedLang == 'und';

      final result = isInvalidResult
          ? ASRRecognitionResult(
              text: '',
              isFinal: true,
              confidence: 0.0,
              detectedLanguageCode: detectedLang,
              detectedLanguageName: _resolveLanguageName(detectedLang),
              audioDuration: duration,
              timestamp: DateTime.now(),
              isMock: false,
              errorMessage: errorMessage ?? 'No clear speech detected. Please speak clearly into the microphone.',
            )
          : ASRRecognitionResult(
              text: finalText,
              isFinal: true,
              confidence: detectionConfidence,
              detectedLanguageCode: detectedLang,
              detectedLanguageName: _resolveLanguageName(detectedLang),
              audioDuration: duration,
              timestamp: DateTime.now(),
              isMock: false,
            );

      _emitResult(result);
      _updateState(ASRState.completed);
      return result;
    } catch (e) {
      debugPrint('[SherpaASR] Recognition error: $e');
      final err = ASRRecognitionResult.error(
        errorMessage: 'Recognition failed: $e',
        audioDuration: duration,
        isMock: false,
      );
      _emitResult(err);
      _updateState(ASRState.error);
      return err;
    }
  }

  @override
  Future<ASRRecognitionResult> transcribePcmBuffer(
    Uint8List pcmBytes, {
    required AudioCaptureConfig audioConfig,
    String? languageCodeHint,
  }) async {
    if (pcmBytes.isEmpty) {
      return ASRRecognitionResult.empty();
    }

    final ready = await _ensureRecognizerReady(languageCodeHint);
    if (!ready) {
      if (_fallbackService != null) {
        return await _fallbackService.transcribePcmBuffer(
          pcmBytes,
          audioConfig: audioConfig,
          languageCodeHint: languageCodeHint,
        );
      }
      return ASRRecognitionResult.error(
        errorMessage: 'Offline model pack not installed.',
        isMock: false,
      );
    }

    // Direct raw 16-bit to float32 linear conversion without artificial gain distortion
    final floatSamples = PCMConverter.pcm16ToFloat32(pcmBytes);
    final (minFloat, maxFloat) = PCMConverter.computeFloatMinMax(floatSamples);
    final floatRms = PCMConverter.computeFloatRms(floatSamples);
    final peakAmplitude = PCMConverter.computePeakAmplitude(pcmBytes);
    final nonZeroBytes = PCMConverter.countNonZeroBytes(pcmBytes);
    final rms = PCMConverter.computeRms(pcmBytes);
    final duration = PCMConverter.calculateDuration(
      floatSamples.length,
      sampleRate: audioConfig.sampleRate,
    );

    debugPrint('=== [SherpaASR] TRANSCRIBE_BUFFER NATIVE PRE-FLIGHT ===');
    debugPrint('  PCM Bytes: ${pcmBytes.length}');
    debugPrint('  Float Samples: ${floatSamples.length} (sampleRate=${audioConfig.sampleRate})');
    debugPrint('  Int16 Peak: $peakAmplitude / 32767 (${(peakAmplitude / 327.67).toStringAsFixed(1)}% full scale)');
    debugPrint('  Non-zero Bytes: $nonZeroBytes / ${pcmBytes.length} (${(nonZeroBytes * 100 / pcmBytes.length).toStringAsFixed(1)}%)');
    debugPrint('  Float Min/Max: [${minFloat.toStringAsFixed(6)}, ${maxFloat.toStringAsFixed(6)}]');
    debugPrint('  RMS (PCM): ${rms.toStringAsFixed(6)}, RMS (Float): ${floatRms.toStringAsFixed(6)}');
    debugPrint('  Acoustic Duration: ${duration.inMilliseconds} ms');
    debugPrint('  Language Hint: "$languageCodeHint"');
    debugPrint('========================================================');

    try {
      String text = '';
      String detectedLang = languageCodeHint ?? 'te';
      if (_offlineRecognizer != null) {
        final decodeStopwatch = Stopwatch()..start();
        final stream = _offlineRecognizer!.createStream();

        if (languageCodeHint != null &&
            languageCodeHint != 'auto' &&
            languageCodeHint.isNotEmpty) {
          try {
            stream.setOption(key: 'language', value: languageCodeHint);
          } catch (_) {}
        }
        try {
          stream.setOption(key: 'task', value: 'transcribe');
        } catch (_) {}

        stream.acceptWaveform(samples: floatSamples, sampleRate: audioConfig.sampleRate);
        _offlineRecognizer!.decode(stream);
        final res = _offlineRecognizer!.getResult(stream);
        decodeStopwatch.stop();

        final valResult = TranscriptValidator.validate(
          res.text,
          expectedLanguageCode: languageCodeHint,
        );

        text = valResult.isValid ? valResult.cleanedText : '';
        const validSupported = {'en', 'te', 'hi', 'ta', 'kn', 'ml', 'bn', 'mr', 'gu', 'pa'};
        if (languageCodeHint != null && languageCodeHint != 'auto' && languageCodeHint.isNotEmpty) {
          detectedLang = languageCodeHint;
        } else if (res.lang.isNotEmpty) {
          final rawModelLang = res.lang.replaceAll('<|', '').replaceAll('|>', '').trim().toLowerCase();
          if (validSupported.contains(rawModelLang)) {
            detectedLang = rawModelLang;
          } else if (valResult.resolvedScript == 'te' ||
                     valResult.resolvedScript == 'hi' ||
                     valResult.resolvedScript == 'ta' ||
                     valResult.resolvedScript == 'kn') {
            detectedLang = valResult.resolvedScript;
          } else {
            detectedLang = 'und';
          }
        } else if (valResult.resolvedScript == 'te' ||
                   valResult.resolvedScript == 'hi' ||
                   valResult.resolvedScript == 'ta' ||
                   valResult.resolvedScript == 'kn') {
          detectedLang = valResult.resolvedScript;
        } else {
          detectedLang = 'und';
        }

        debugPrint('=== [SherpaASR] TRANSCRIBE_BUFFER WHISPER RESULT ===');
        debugPrint('  Inference Latency: ${decodeStopwatch.elapsedMilliseconds} ms');
        debugPrint('  Decoded Raw Text: "${res.text}"');
        debugPrint('  Cleaned Valid Text: "$text"');
        debugPrint('  Raw Model Lang: "${res.lang}" -> Resolved: "$detectedLang"');
        debugPrint('  Tokens Count: ${res.tokens.length}');
        debugPrint('  Tokens: ${res.tokens}');
        debugPrint('====================================================');

        stream.free();
      } else if (_onlineRecognizer != null) {
        final stream = _onlineRecognizer!.createStream();
        stream.acceptWaveform(samples: floatSamples, sampleRate: audioConfig.sampleRate);
        stream.inputFinished();
        while (_onlineRecognizer!.isReady(stream)) {
          _onlineRecognizer!.decode(stream);
        }
        final raw = _onlineRecognizer!.getResult(stream).text.trim();
        final val = TranscriptValidator.validate(raw, expectedLanguageCode: languageCodeHint);
        text = val.isValid ? val.cleanedText : '';
        stream.free();
      }

      return ASRRecognitionResult(
        text: text,
        isFinal: true,
        confidence: text.isNotEmpty ? 0.95 : 0.0,
        detectedLanguageCode: detectedLang,
        detectedLanguageName: _resolveLanguageName(detectedLang),
        audioDuration: duration,
        timestamp: DateTime.now(),
        isMock: false,
      );
    } catch (e) {
      return ASRRecognitionResult.error(
        errorMessage: 'Offline transcription failed: $e',
        audioDuration: duration,
        isMock: false,
      );
    }
  }

  Future<void> _cancelFallbackSubs() async {
    await _fallbackStateSub?.cancel();
    _fallbackStateSub = null;
    await _fallbackResultSub?.cancel();
    _fallbackResultSub = null;
  }

  @override
  Future<void> cancelRecognition() async {
    await _pcmSubscription?.cancel();
    _pcmSubscription = null;
    _bufferedPcm.clear();
    await _cancelFallbackSubs();

    if (_activeOnlineStream != null) {
      _activeOnlineStream!.free();
      _activeOnlineStream = null;
    }

    if (_fallbackService != null) {
      await _fallbackService.cancelRecognition();
    }

    _updateState(ASRState.idle);
  }

  @override
  void reset() {
    _pcmSubscription?.cancel();
    _pcmSubscription = null;
    _cancelFallbackSubs();
    _bufferedPcm.clear();
    _lastResult = null;
    _fallbackService?.reset();
    _updateState(ASRState.idle);
  }

  @override
  Future<void> dispose() async {
    await cancelRecognition();
    await _cancelFallbackSubs();
    _activeOnlineStream?.free();
    _activeOnlineStream = null;
    _onlineRecognizer?.free();
    _onlineRecognizer = null;
    _offlineRecognizer?.free();
    _offlineRecognizer = null;
    _loadedLanguageCode = null;
    await _fallbackService?.dispose();
    await _resultController.close();
    await _stateController.close();
  }

  Future<bool> _ensureRecognizerReady(String? languageCode) async {
    if (!_bindingsInitialized) {
      await initialize();
    }
    if (!_bindingsInitialized) {
      return false;
    }

    final targetLang = (languageCode == null || languageCode == 'auto') ? '' : languageCode;

    if (_offlineRecognizer != null) {
      if (_loadedLanguageCode == targetLang) {
        return true;
      }
      _offlineRecognizer?.free();
      _offlineRecognizer = null;
    }

    if (_onlineRecognizer != null) {
      return true;
    }

    // Check if an offline model is available
    final modelMeta = await _modelManager.findInstalledModelForLanguage(languageCode);
    if (modelMeta == null) {
      debugPrint('[SherpaASR] No installed offline model found for $languageCode.');
      return false;
    }

    try {
      final paths = await _modelManager.getModelFilePaths(modelMeta.id);

      if (modelMeta.modelType == 'whisper') {
        final encoderPath = paths['tiny-encoder.int8.onnx'] ?? '';
        final decoderPath = paths['tiny-decoder.int8.onnx'] ?? '';
        final tokensPath = paths['tiny-tokens.txt'] ?? '';

        debugPrint('[SherpaASR] Initializing Offline Whisper with:');
        debugPrint('  encoder: $encoderPath (${File(encoderPath).existsSync() ? "${File(encoderPath).lengthSync()} bytes" : "MISSING"})');
        debugPrint('  decoder: $decoderPath (${File(decoderPath).existsSync() ? "${File(decoderPath).lengthSync()} bytes" : "MISSING"})');
        debugPrint('  tokens: $tokensPath (${File(tokensPath).existsSync() ? "${File(tokensPath).lengthSync()} bytes" : "MISSING"})');
        debugPrint('  target language: "$targetLang"');

        final whisperConfig = sherpa.OfflineWhisperModelConfig(
          encoder: encoderPath,
          decoder: decoderPath,
          language: targetLang,
          task: 'transcribe',
        );

        final modelConfig = sherpa.OfflineModelConfig(
          whisper: whisperConfig,
          tokens: tokensPath,
          modelType: 'whisper',
          numThreads: 2,
        );

        final config = sherpa.OfflineRecognizerConfig(model: modelConfig);
        _offlineRecognizer = sherpa.OfflineRecognizer(config);
        _loadedLanguageCode = targetLang;
        debugPrint('[SherpaASR] Offline Whisper Recognizer initialized successfully for ${modelMeta.id} (Lang: "$targetLang").');
        return true;
      } else if (modelMeta.modelType == 'zipformer') {
        final transducerConfig = sherpa.OnlineTransducerModelConfig(
          encoder: paths['encoder-epoch-99-avg-1.int8.onnx'] ?? '',
          decoder: paths['decoder-epoch-99-avg-1.onnx'] ?? '',
          joiner: paths['joiner-epoch-99-avg-1.int8.onnx'] ?? '',
        );

        final modelConfig = sherpa.OnlineModelConfig(
          transducer: transducerConfig,
          tokens: paths['tokens.txt'] ?? '',
          modelType: 'zipformer2',
          numThreads: 2,
        );

        final config = sherpa.OnlineRecognizerConfig(model: modelConfig);
        _onlineRecognizer = sherpa.OnlineRecognizer(config);
        _activeOnlineStream = _onlineRecognizer!.createStream();
        debugPrint('[SherpaASR] Online Streaming Zipformer Recognizer initialized.');
        return true;
      }
    } catch (e) {
      debugPrint('[SherpaASR] Error building recognizer from model files: $e');
    }

    return false;
  }

  void _updateState(ASRState newState) {
    _currentState = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  void _emitResult(ASRRecognitionResult result) {
    _lastResult = result;
    if (!_resultController.isClosed) {
      _resultController.add(result);
    }
  }

  String? _resolveLanguageName(String? code) {
    if (code == null) return null;
    return LanguageRegistry.getLanguageName(code);
  }
}

