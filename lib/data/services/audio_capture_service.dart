import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import '../models/audio_recording_state.dart';

/// Contract for real-time microphone capture and audio streaming.
abstract class IAudioCaptureService {
  /// Stream emitting raw 16-bit PCM audio chunks as they arrive from the microphone.
  Stream<Uint8List> get audioStream;

  /// Stream emitting normalized volume levels (0.0 to 1.0) for visualizers.
  Stream<double> get amplitudeStream;

  /// Stream emitting changes to the audio recording state.
  Stream<AudioCaptureState> get stateStream;

  /// Current operational state of the capture service.
  AudioCaptureState get currentState;

  /// Whether the microphone is currently capturing audio.
  bool get isRecording;

  /// Active capture configuration parameters.
  AudioCaptureConfig get config;

  /// In-memory captured PCM audio bytes from the current/most recent recording session.
  Uint8List get capturedAudioBytes;

  /// Total number of audio bytes captured in the current session.
  int get totalBytesCaptured;

  /// Total duration of the current/most recent recording session.
  Duration get recordingDuration;

  /// Starts real-time microphone streaming.
  /// Returns `true` if recording commenced successfully.
  Future<bool> startCapture({AudioCaptureConfig? config});

  /// Stops microphone capture and returns the complete in-memory captured audio buffer.
  Future<Uint8List?> stopCapture();

  /// Cancels recording immediately and discards any buffered audio.
  Future<void> cancelCapture();

  /// Clears the in-memory audio buffer without affecting recording status.
  void resetBuffer();

  /// Disposes all streaming controllers and releases native audio hardware.
  Future<void> dispose();
}

/// Production implementation of audio capture powered by `package:record`.
class RecordAudioCaptureService implements IAudioCaptureService {
  final AudioRecorder _recorder;

  RecordAudioCaptureService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  AudioCaptureConfig _config = const AudioCaptureConfig();
  AudioCaptureState _currentState = AudioCaptureState.idle;

  final BytesBuilder _buffer = BytesBuilder(copy: false);
  DateTime? _recordingStartTime;
  Duration _lastRecordedDuration = Duration.zero;
  int _chunkCount = 0;

  StreamSubscription<Uint8List>? _rawStreamSubscription;

  final StreamController<Uint8List> _audioStreamController =
      StreamController<Uint8List>.broadcast();
  final StreamController<double> _amplitudeStreamController =
      StreamController<double>.broadcast();
  final StreamController<AudioCaptureState> _stateStreamController =
      StreamController<AudioCaptureState>.broadcast();

  @override
  Stream<Uint8List> get audioStream => _audioStreamController.stream;

  @override
  Stream<double> get amplitudeStream => _amplitudeStreamController.stream;

  @override
  Stream<AudioCaptureState> get stateStream => _stateStreamController.stream;

  @override
  AudioCaptureState get currentState => _currentState;

  @override
  bool get isRecording => _currentState == AudioCaptureState.recording;

  @override
  AudioCaptureConfig get config => _config;

  @override
  Uint8List get capturedAudioBytes => _buffer.toBytes();

  @override
  int get totalBytesCaptured => _buffer.length;

  @override
  Duration get recordingDuration {
    if (_currentState == AudioCaptureState.recording) {
      if (_config.bytesPerSecond > 0 && _buffer.length > 0) {
        return Duration(milliseconds: (_buffer.length * 1000) ~/ _config.bytesPerSecond);
      }
      if (_recordingStartTime != null) {
        return DateTime.now().difference(_recordingStartTime!);
      }
    }
    return _lastRecordedDuration;
  }

  void _setState(AudioCaptureState state) {
    if (_currentState == state) return;
    _currentState = state;
    if (!_stateStreamController.isClosed) {
      _stateStreamController.add(state);
    }
  }

  @override
  Future<bool> startCapture({AudioCaptureConfig? config}) async {
    // Concurrency guard: If a previous recording session is lingering, cleanly reset it first
    if (_currentState == AudioCaptureState.recording || _currentState == AudioCaptureState.initializing) {
      debugPrint('[AudioCaptureService] Lingering recording session detected. Resetting previous session.');
      try {
        await cancelCapture();
      } catch (_) {}
    }

    _config = config ?? const AudioCaptureConfig();
    _setState(AudioCaptureState.initializing);
    _buffer.clear();
    _chunkCount = 0;

    try {
      final hasPerm = await _recorder.hasPermission();
      if (!hasPerm) {
        debugPrint('[AudioCaptureService] package:record reports permission not granted.');
        _setState(AudioCaptureState.error);
        return false;
      }

      RecordConfig recordConfig = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _config.sampleRate,
        numChannels: _config.numChannels,
        autoGain: _config.autoGain,
        echoCancel: _config.echoCancellation,
        noiseSuppress: _config.noiseSuppression,
      );

      Stream<Uint8List> rawStream;
      try {
        rawStream = await _recorder.startStream(recordConfig);
      } catch (streamErr) {
        debugPrint('[AudioCaptureService] startStream with effects failed: $streamErr. Retrying without hardware audio effects.');
        // Retry with pure raw PCM config without hardware AEC / NS flags
        final fallbackConfig = RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _config.sampleRate,
          numChannels: _config.numChannels,
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
        );
        rawStream = await _recorder.startStream(fallbackConfig);
      }

      _recordingStartTime = DateTime.now();
      _setState(AudioCaptureState.recording);

      _rawStreamSubscription?.cancel();
      _rawStreamSubscription = rawStream.listen(
        _onAudioChunkReceived,
        onError: _onAudioStreamError,
        onDone: _onAudioStreamDone,
        cancelOnError: false,
      );

      debugPrint('[AudioCaptureService] Successfully started PCM audio capture: $_config');
      return true;
    } catch (e, stack) {
      debugPrint('[AudioCaptureService] Error starting audio capture: $e\n$stack');
      _setState(AudioCaptureState.error);
      return false;
    }
  }

  void _onAudioChunkReceived(Uint8List chunk) {
    if (_currentState != AudioCaptureState.recording) return;

    _chunkCount++;

    // Buffer audio chunk in memory
    _buffer.add(chunk);

    // Forward raw audio chunk to listeners
    if (!_audioStreamController.isClosed) {
      _audioStreamController.add(chunk);
    }

    // Compute live audio amplitude level from PCM 16-bit samples
    final normalized = _calculatePcmRms(chunk);
    if (!_amplitudeStreamController.isClosed) {
      _amplitudeStreamController.add(normalized);
    }
  }

  void _onAudioStreamError(Object error) {
    debugPrint('[AudioCaptureService] Stream error received: $error');
    _setState(AudioCaptureState.error);
  }

  void _onAudioStreamDone() {
    debugPrint('[AudioCaptureService] Audio stream ended.');
    if (_currentState == AudioCaptureState.recording) {
      _setState(AudioCaptureState.idle);
    }
  }

  /// Calculates the Root Mean Square (RMS) of 16-bit little-endian PCM samples,
  /// normalized to a 0.0 – 1.0 range with logarithmic perceptual scaling for visualizers.
  double _calculatePcmRms(Uint8List chunk) {
    if (chunk.length < 2) return 0.0;

    final int sampleCount = chunk.length ~/ 2;
    double sumOfSquares = 0.0;
    final ByteData byteData = ByteData.sublistView(chunk);

    for (int i = 0; i < sampleCount; i++) {
      final int sample = byteData.getInt16(i * 2, Endian.little);
      sumOfSquares += sample * sample;
    }

    final double rms = sqrt(sumOfSquares / sampleCount);

    // Maximum 16-bit amplitude is 32768.
    // Apply a logarithmic perceptual gain curve so normal speech produces 0.3 - 0.8 on visualizer.
    final double linear = (rms / 32768.0).clamp(0.0, 1.0);
    final double scaled = min(1.0, pow(linear, 0.45) * 1.8).toDouble();

    return scaled;
  }

  @override
  Future<Uint8List?> stopCapture() async {
    if (_currentState != AudioCaptureState.recording) {
      debugPrint('[AudioCaptureService] Not currently recording (state: $_currentState).');
      return _buffer.length > 0 ? _buffer.toBytes() : null;
    }

    _setState(AudioCaptureState.stopping);

    try {
      // 1. Stop native AudioRecord first so all buffered audio is flushed through the stream
      await _recorder.stop();

      // 2. Allow any in-flight chunk emitted right at stop to be captured
      await Future<void>.delayed(const Duration(milliseconds: 60));

      // 3. Now safely cancel the Dart stream subscription
      await _rawStreamSubscription?.cancel();
      _rawStreamSubscription = null;

      final result = _buffer.toBytes();
      if (_config.bytesPerSecond > 0 && result.isNotEmpty) {
        _lastRecordedDuration = Duration(milliseconds: (result.length * 1000) ~/ _config.bytesPerSecond);
      } else if (_recordingStartTime != null) {
        _lastRecordedDuration = DateTime.now().difference(_recordingStartTime!);
      }
      _recordingStartTime = null;

      _setState(AudioCaptureState.idle);

      // Reset amplitude visualizer to resting 0
      if (!_amplitudeStreamController.isClosed) {
        _amplitudeStreamController.add(0.0);
      }

      // Compute comprehensive diagnostics on the captured buffer
      int nonZeroCount = 0;
      int peak = 0;
      final sampleCount = result.length ~/ 2;
      final byteData = ByteData.sublistView(result);
      double sumSquares = 0.0;
      for (int i = 0; i < sampleCount; i++) {
        final sample = byteData.getInt16(i * 2, Endian.little);
        final absSample = sample.abs();
        if (absSample > peak) peak = absSample;
        final norm = sample / 32768.0;
        sumSquares += norm * norm;
      }
      for (int i = 0; i < result.length; i++) {
        if (result[i] != 0) nonZeroCount++;
      }
      final calculatedRms = sampleCount > 0 ? sqrt(sumSquares / sampleCount) : 0.0;

      debugPrint('=== [AudioCaptureService] SESSION DIAGNOSTICS ===');
      debugPrint('  Chunks received: $_chunkCount');
      debugPrint('  Total buffer: ${result.length} bytes ($sampleCount samples, ${_lastRecordedDuration.inMilliseconds} ms)');
      debugPrint('  Format: ${_config.sampleRate} Hz, ${_config.numChannels} ch, ${_config.bitDepth}-bit PCM');
      debugPrint('  Peak amplitude: $peak / 32767 (${(peak / 327.67).toStringAsFixed(1)}% full scale)');
      debugPrint('  Non-zero bytes: $nonZeroCount / ${result.length} (${result.isNotEmpty ? ((nonZeroCount / result.length) * 100).toStringAsFixed(1) : 0}%)');
      debugPrint('  RMS energy: ${calculatedRms.toStringAsFixed(6)}');
      debugPrint('================================================');

      return result;
    } catch (e) {
      debugPrint('[AudioCaptureService] Error stopping audio capture: $e');
      _setState(AudioCaptureState.error);
      return null;
    }
  }

  @override
  Future<void> cancelCapture() async {
    _setState(AudioCaptureState.stopping);
    try {
      await _rawStreamSubscription?.cancel();
      _rawStreamSubscription = null;

      await _recorder.cancel();
      _buffer.clear();
      _recordingStartTime = null;
      _lastRecordedDuration = Duration.zero;

      _setState(AudioCaptureState.idle);
      if (!_amplitudeStreamController.isClosed) {
        _amplitudeStreamController.add(0.0);
      }
    } catch (e) {
      debugPrint('[AudioCaptureService] Error cancelling capture: $e');
      _setState(AudioCaptureState.error);
    }
  }

  @override
  void resetBuffer() {
    _buffer.clear();
    _lastRecordedDuration = Duration.zero;
  }

  @override
  Future<void> dispose() async {
    try {
      await _rawStreamSubscription?.cancel();
      _rawStreamSubscription = null;

      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
      await _recorder.dispose();

      await _audioStreamController.close();
      await _amplitudeStreamController.close();
      await _stateStreamController.close();
      _buffer.clear();
    } catch (e) {
      debugPrint('[AudioCaptureService] Error during dispose: $e');
    }
  }
}

