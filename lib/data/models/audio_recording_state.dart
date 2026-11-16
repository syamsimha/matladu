import 'dart:typed_data';

/// Represents the current operational state of real-time microphone capture.
enum AudioCaptureState {
  /// Audio capture is inactive and resources are resting.
  idle,

  /// Initializing audio capture hardware, buffers, and session.
  initializing,

  /// Actively streaming raw PCM audio chunks from the microphone.
  recording,

  /// Safely stopping audio capture and finalizing the audio buffer.
  stopping,

  /// An error occurred during capture (e.g. permission denied, device disconnected).
  error,
}

/// Status of microphone runtime permissions.
enum AudioPermissionStatus {
  /// Permission has been granted by the user.
  granted,

  /// Permission was denied by the user (temporary).
  denied,

  /// Permission was permanently denied ("Never ask again"). Settings must be opened.
  permanentlyDenied,

  /// Restricted by system policy (e.g. parental controls).
  restricted,

  /// Permission status has not yet been determined.
  undetermined,
}

/// Configuration parameters for microphone audio capture.
class AudioCaptureConfig {
  /// Sample rate in Hz. Whisper and modern ASR engines require 16,000 Hz.
  final int sampleRate;

  /// Number of audio channels. 1 = Mono, 2 = Stereo. Mono is standard for speech.
  final int numChannels;

  /// Audio bit depth. 16-bit PCM is standard for speech recognition.
  final int bitDepth;

  /// Enable Automatic Gain Control where supported by the platform.
  final bool autoGain;

  /// Enable acoustic echo cancellation where supported by the platform.
  final bool echoCancellation;

  /// Enable acoustic noise suppression where supported by the platform.
  final bool noiseSuppression;

  const AudioCaptureConfig({
    this.sampleRate = 16000,
    this.numChannels = 1,
    this.bitDepth = 16,
    this.autoGain = true,
    this.echoCancellation = false,
    this.noiseSuppression = false,
  });

  /// Bytes per second = sampleRate * numChannels * (bitDepth / 8).
  /// For 16 kHz Mono 16-bit = 16000 * 1 * 2 = 32,000 bytes/sec.
  int get bytesPerSecond => sampleRate * numChannels * (bitDepth ~/ 8);

  @override
  String toString() =>
      'AudioCaptureConfig(${sampleRate}Hz, ${numChannels == 1 ? 'Mono' : 'Stereo'}, $bitDepth-bit PCM)';
}

/// A captured audio chunk received from the microphone stream.
class AudioChunk {
  /// Raw PCM 16-bit little-endian audio bytes.
  final Uint8List bytes;

  /// Timestamp when this chunk was received.
  final DateTime timestamp;

  /// Normalized audio amplitude level (0.0 silent to 1.0 maximum volume).
  final double normalizedLevel;

  /// Root Mean Square (RMS) decibel level (typically -160.0 to 0.0 dB).
  final double decibels;

  const AudioChunk({
    required this.bytes,
    required this.timestamp,
    required this.normalizedLevel,
    required this.decibels,
  });

  /// Duration of this chunk based on standard 16kHz mono 16-bit (32,000 bytes/sec).
  Duration get duration {
    const bytesPerMs = 32; // 32 bytes per millisecond
    return Duration(milliseconds: bytes.length ~/ bytesPerMs);
  }
}
