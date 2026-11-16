import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../../models/asr_state.dart';
import '../../models/audio_recording_state.dart';
import 'i_asr_service.dart';
import 'pcm_converter.dart';

/// Online Cloud Speech Recognition Service.
///
/// COMPLIANCE & PRIVACY:
/// - Used ONLY when the user explicitly selects Online Mode.
/// - Does NOT require downloading the 103.6 MB Whisper multilingual model pack.
/// - Clearly discloses cloud speech recognition processing when audio leaves the device.
/// - Zero hardcoded secret keys in the APK.
/// - If a cloud ASR backend endpoint is not configured, it honestly reports that
///   online speech recognition requires a backend service, and directs the user
///   to switch to 100% On-Device Offline Mode with Whisper.
class OnlineASRService implements IASRService {
  final String? cloudEndpointUrl;

  final _resultController = StreamController<ASRRecognitionResult>.broadcast();
  final _stateController = StreamController<ASRState>.broadcast();
  ASRState _currentState = ASRState.idle;
  ASRRecognitionResult? _lastResult;

  final BytesBuilder _audioBuffer = BytesBuilder(copy: false);
  String? _activeLanguageHint;
  StreamSubscription<Uint8List>? _pcmSubscription;
  DateTime? _recordingStartTime;

  OnlineASRService({this.cloudEndpointUrl});

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

  void _setState(ASRState newState) {
    _currentState = newState;
    _stateController.add(newState);
  }

  @override
  Future<void> initialize() async {
    _setState(ASRState.idle);
    debugPrint(
      '[OnlineASRService] Initialized. Endpoint: ${cloudEndpointUrl ?? "Not configured (Offline Whisper recommended)"}',
    );
  }

  @override
  Future<void> startStreamingRecognition(
    Stream<Uint8List> pcmAudioStream, {
    required AudioCaptureConfig audioConfig,
    String? languageCodeHint,
  }) async {
    _audioBuffer.clear();
    _activeLanguageHint = languageCodeHint;
    _recordingStartTime = DateTime.now();
    _setState(ASRState.listening);

    _pcmSubscription = pcmAudioStream.listen((chunk) {
      _audioBuffer.add(chunk);
    });

    debugPrint(
      '[OnlineASRService] Streaming recognition started (Online Mode, LangHint: $languageCodeHint).',
    );
  }

  @override
  Future<ASRRecognitionResult> stopStreamingRecognition({Uint8List? recordedPcm}) async {
    await _pcmSubscription?.cancel();
    _pcmSubscription = null;

    final bytes = recordedPcm ?? _audioBuffer.takeBytes();
    if (bytes.isEmpty) {
      _setState(ASRState.error);
      final err = ASRRecognitionResult.error(
        errorMessage: 'No speech detected. Please speak clearly into the microphone.',
      );
      _lastResult = err;
      _resultController.add(err);
      return err;
    }

    _setState(ASRState.transcribing);
    final duration = _recordingStartTime != null
        ? DateTime.now().difference(_recordingStartTime!)
        : PCMConverter.calculateDuration(bytes.length ~/ 2);

    // Measure RMS audio energy to ensure audio signal contains genuine speech
    final rms = PCMConverter.computeRms(bytes);
    final nonZeroBytes = PCMConverter.countNonZeroBytes(bytes);

    // Silence gating threshold
    if ((rms < 0.0001 && bytes.length < 16000) || nonZeroBytes == 0) {
      _setState(ASRState.error);
      final err = ASRRecognitionResult.error(
        errorMessage: 'No speech detected. Please speak clearly into the microphone.',
      );
      _lastResult = err;
      _resultController.add(err);
      return err;
    }

    // Check if cloud ASR backend endpoint is configured
    final endpoint = cloudEndpointUrl;
    if (endpoint == null || endpoint.trim().isEmpty) {
      debugPrint('[OnlineASRService] No external Cloud ASR endpoint configured.');
      _setState(ASRState.error);
      final err = ASRRecognitionResult.error(
        errorMessage:
            'Cloud speech-recognition provider not configured. Please switch to Offline Mode to transcribe locally with on-device Whisper, or configure a Cloud ASR endpoint URL.',
      );
      _lastResult = err;
      _resultController.add(err);
      return err;
    }

    // Execute genuine HTTP request to configured Cloud ASR backend
    return await _executeCloudTranscription(
      pcmBytes: bytes,
      duration: duration,
      endpoint: endpoint,
      languageHint: _activeLanguageHint,
    );
  }

  Future<ASRRecognitionResult> _executeCloudTranscription({
    required Uint8List pcmBytes,
    required Duration duration,
    required String endpoint,
    String? languageHint,
  }) async {
    debugPrint(
      '[OnlineASRService] Transmitting ${pcmBytes.length} bytes audio to external Cloud ASR: $endpoint',
    );

    try {
      final wavBytes = PCMConverter.pcm16ToWav(pcmBytes);
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      final uri = Uri.parse(endpoint);
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'audio/wav');
      if (languageHint != null && languageHint.isNotEmpty) {
        request.headers.set('X-Language-Hint', languageHint);
      }
      request.add(wavBytes);

      final response = await request.close().timeout(const Duration(seconds: 15));

      if (response.statusCode == HttpStatus.ok) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final transcript = (json['text'] ?? json['transcript'] ?? '').toString().trim();
        final detectedLang = (json['language'] ?? json['detectedLanguageCode'] ?? languageHint ?? 'en').toString();
        final confidence = (json['confidence'] as num?)?.toDouble() ?? 0.95;

        if (transcript.isEmpty) {
          _setState(ASRState.error);
          final err = ASRRecognitionResult.error(
            errorMessage: 'Cloud speech recognition returned an empty transcript.',
          );
          _lastResult = err;
          _resultController.add(err);
          return err;
        }

        _setState(ASRState.completed);
        final result = ASRRecognitionResult(
          text: transcript,
          isFinal: true,
          confidence: confidence,
          detectedLanguageCode: detectedLang,
          detectedLanguageName: _resolveLanguageName(detectedLang),
          audioDuration: duration,
          timestamp: DateTime.now(),
          isMock: false,
        );
        _lastResult = result;
        _resultController.add(result);
        return result;
      } else if (response.statusCode == HttpStatus.tooManyRequests) {
        _setState(ASRState.error);
        final err = ASRRecognitionResult.error(
          errorMessage: 'Cloud speech-recognition rate limit reached. Please switch to Offline Mode.',
        );
        _lastResult = err;
        _resultController.add(err);
        return err;
      } else {
        _setState(ASRState.error);
        final err = ASRRecognitionResult.error(
          errorMessage: 'Cloud speech-recognition server returned HTTP ${response.statusCode}.',
        );
        _lastResult = err;
        _resultController.add(err);
        return err;
      }
    } catch (e) {
      debugPrint('[OnlineASRService] Cloud ASR network error: $e');
      _setState(ASRState.error);
      final err = ASRRecognitionResult.error(
        errorMessage: 'Cloud speech-recognition network error: $e',
      );
      _lastResult = err;
      _resultController.add(err);
      return err;
    }
  }

  String _resolveLanguageName(String code) {
    final lower = code.toLowerCase();
    if (lower.startsWith('te')) return 'Telugu';
    if (lower.startsWith('hi')) return 'Hindi';
    if (lower.startsWith('en')) return 'English';
    if (lower.startsWith('ta')) return 'Tamil';
    if (lower.startsWith('kn')) return 'Kannada';
    return code.toUpperCase();
  }

  @override
  Future<void> cancelRecognition() async {
    await _pcmSubscription?.cancel();
    _pcmSubscription = null;
    _audioBuffer.clear();
    _setState(ASRState.idle);
  }

  @override
  void reset() {
    _audioBuffer.clear();
    _setState(ASRState.idle);
  }

  @override
  Future<ASRRecognitionResult> transcribePcmBuffer(
    Uint8List pcmBytes, {
    required AudioCaptureConfig audioConfig,
    String? languageCodeHint,
  }) async {
    _recordingStartTime = DateTime.now();
    return await stopStreamingRecognition(recordedPcm: pcmBytes);
  }

  @override
  Future<void> dispose() async {
    await _pcmSubscription?.cancel();
    await _resultController.close();
    await _stateController.close();
  }
}
