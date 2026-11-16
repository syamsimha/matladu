import 'dart:typed_data';
import '../../models/asr_state.dart';
import '../../models/audio_recording_state.dart';

/// Contract for Automatic Speech Recognition (ASR) engines.
/// Keeps Matladu AI completely decoupled from any specific ASR provider.
abstract class IASRService {
  /// Stream emitting interim (partial) and final recognition results.
  Stream<ASRRecognitionResult> get resultStream;

  /// Stream emitting ASR operational state changes.
  Stream<ASRState> get stateStream;

  /// Current operational state of the ASR engine.
  ASRState get currentState;

  /// The most recent recognition result emitted by the service.
  ASRRecognitionResult? get lastResult;

  /// Whether this ASR engine manages microphone capture natively (e.g. Android SpeechRecognizer).
  /// When true, external audio capture via AudioRepository should NOT be started concurrently
  /// to avoid competing hardware conflicts.
  bool get isNativeCapture;

  /// Initializes the ASR service and pre-warms required resources.
  Future<void> initialize();

  /// Starts real-time streaming recognition by consuming an incoming PCM chunk stream.
  /// Emits partial/interim results to [resultStream] as speech is processed.
  Future<void> startStreamingRecognition(
    Stream<Uint8List> pcmStream, {
    required AudioCaptureConfig audioConfig,
    String? languageCodeHint,
  });

  /// Stops streaming recognition and returns the final stabilized transcript.
  /// Optionally accepts [recordedPcm] full audio buffer captured by the audio repository.
  Future<ASRRecognitionResult> stopStreamingRecognition({Uint8List? recordedPcm});

  /// Transcribes a complete raw 16-bit PCM byte buffer (e.g. from an in-memory recording session).
  Future<ASRRecognitionResult> transcribePcmBuffer(
    Uint8List pcmBytes, {
    required AudioCaptureConfig audioConfig,
    String? languageCodeHint,
  });

  /// Cancels any active recognition session and clears in-flight state.
  Future<void> cancelRecognition();

  /// Resets state and buffers to idle.
  void reset();

  /// Releases resources and closes all streaming controllers.
  Future<void> dispose();
}

