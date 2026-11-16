import 'package:flutter/foundation.dart';
import '../models/asr_state.dart';
import '../models/audio_recording_state.dart';
import '../services/asr/hybrid_asr_service.dart';
import '../services/asr/i_asr_service.dart';
import '../services/asr/model_manager_service.dart';
import '../services/asr/sherpa_on_device_asr_service.dart';
import 'audio_repository.dart';

/// Repository coordinating microphone audio capture and Automatic Speech Recognition (ASR).
///
/// REUSE INVARIANT:
/// Reuses the existing Phase 2 [AudioRepository] and PCM stream.
/// Never duplicates audio capture hardware or permission management.
class ASRRepository {
  final AudioRepository _audioRepository;
  final IASRService _asrService;

  ASRRepository({
    required AudioRepository audioRepository,
    required IASRService asrService,
  })  : _audioRepository = audioRepository,
        _asrService = asrService;

  // Recognition Streams
  Stream<ASRRecognitionResult> get resultStream => _asrService.resultStream;
  Stream<ASRState> get asrStateStream => _asrService.stateStream;

  // Audio Pass-Through Streams (for UI visualizers)
  Stream<double> get amplitudeStream => _audioRepository.amplitudeStream;
  Stream<AudioCaptureState> get captureStateStream => _audioRepository.stateStream;

  // State Getters
  ASRState get asrState => _asrService.currentState;
  AudioCaptureState get captureState => _audioRepository.state;
  bool get isRecording => _audioRepository.isRecording;
  ASRRecognitionResult? get latestResult => _asrService.lastResult;
  Duration get recordingDuration => _audioRepository.recordingDuration;
  Uint8List get capturedBytes => _audioRepository.capturedBytes;
  AudioCaptureConfig get audioConfig => _audioRepository.config;
  bool get isNativeCapture => _asrService.isNativeCapture;

  ModelManagerService? get modelManager {
    final asr = _asrService;
    if (asr is SherpaOnDeviceASRService) {
      return asr.modelManager;
    }
    if (asr is HybridASRService) {
      return asr.modelManager;
    }
    return null;
  }

  /// Checks if the speech recognition model is installed locally.
  Future<bool> isModelInstalled([String modelId = 'whisper-tiny-multilingual']) async {
    final mm = modelManager;
    if (mm != null) {
      return await mm.isModelInstalled(modelId);
    }
    return true;
  }

  /// Starts both microphone capture and speech recognition streaming.
  /// Pipes the microphone's raw PCM chunk stream directly into the ASR engine.
  Future<bool> startListeningAndRecognition({String? languageCodeHint}) async {
    // 1. Ensure ASR service is initialized
    await _asrService.initialize();

    // 2. Connect raw PCM audio stream into ASR engine BEFORE opening mic stream
    // This guarantees that zero audio chunks are dropped when microphone capture commences
    await _asrService.startStreamingRecognition(
      _audioRepository.audioStream,
      audioConfig: _audioRepository.config,
      languageCodeHint: languageCodeHint,
    );

    if (_asrService.currentState == ASRState.error) {
      debugPrint('[ASRRepository] Speech recognition service reported error state during startup. Aborting capture.');
      return false;
    }

    // 3. If ASR service handles audio capture natively (e.g. Android SpeechRecognizer),
    // do NOT start AudioRepository capture to prevent competing for microphone hardware!
    if (_asrService.isNativeCapture) {
      debugPrint('[ASRRepository] Native ASR service handles microphone capture internally. Avoiding duplicate AudioRecord allocation.');
      return true;
    }

    // 4. Start hardware microphone capture via Phase 2 AudioRepository
    final started = await _audioRepository.startRecording();
    if (!started) {
      debugPrint('[ASRRepository] Failed to start microphone capture.');
      await _asrService.cancelRecognition();
      return false;
    }

    debugPrint('[ASRRepository] Listening and speech recognition streaming active.');
    return true;
  }

  /// Stops microphone capture and finalizes speech recognition.
  /// Returns the completed [ASRRecognitionResult].
  Future<ASRRecognitionResult> stopAndFinalize() async {
    // 1. Stop hardware recording and capture full in-memory buffer if not handled natively
    Uint8List? pcmBytes;
    if (!_asrService.isNativeCapture) {
      pcmBytes = await _audioRepository.stopRecording();
    }

    // 2. Finalize ASR streaming recognition with complete captured buffer
    final result = await _asrService.stopStreamingRecognition(recordedPcm: pcmBytes);

    debugPrint('[ASRRepository] Stopped. Finalized speech recognition (Lang: ${result.detectedLanguageCode}, chars: ${result.text.length}).');
    return result;
  }

  /// Cancels both microphone capture and active speech recognition.
  Future<void> cancel() async {
    if (!_asrService.isNativeCapture) {
      await _audioRepository.cancelRecording();
    }
    await _asrService.cancelRecognition();
    debugPrint('[ASRRepository] Audio and speech recognition cancelled.');
  }

  /// Transcribes a standalone PCM byte buffer (e.g. from history or testing).
  Future<ASRRecognitionResult> transcribeBuffer(
    Uint8List pcmBytes, {
    String? languageCodeHint,
  }) async {
    return await _asrService.transcribePcmBuffer(
      pcmBytes,
      audioConfig: _audioRepository.config,
      languageCodeHint: languageCodeHint,
    );
  }

  /// Checks microphone permission.
  Future<AudioPermissionStatus> checkPermission() =>
      _audioRepository.checkPermission();

  /// Requests microphone permission.
  Future<AudioPermissionStatus> requestPermission() =>
      _audioRepository.requestPermission();

  /// Opens app settings.
  Future<bool> openAppSettings() => _audioRepository.openAppSettings();

  /// Resets state and clear buffers.
  void reset() {
    _audioRepository.clearBuffer();
    _asrService.reset();
  }

  /// Disposes resources.
  Future<void> dispose() async {
    await _audioRepository.dispose();
    await _asrService.dispose();
  }
}
