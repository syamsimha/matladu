import 'package:flutter/foundation.dart';
import '../models/audio_recording_state.dart';
import '../services/audio_capture_service.dart';
import '../services/audio_permission_service.dart';

/// Repository that orchestrates microphone permissions, audio streaming, and buffer lifecycle.
/// Serves as the single source of truth for voice capture across Matladu AI.
class AudioRepository {
  final IAudioCaptureService _captureService;
  final IAudioPermissionService _permissionService;

  AudioRepository({
    required IAudioCaptureService captureService,
    required IAudioPermissionService permissionService,
  })  : _captureService = captureService,
        _permissionService = permissionService;

  // Streams
  Stream<Uint8List> get audioStream => _captureService.audioStream;
  Stream<double> get amplitudeStream => _captureService.amplitudeStream;
  Stream<AudioCaptureState> get stateStream => _captureService.stateStream;

  // State Getters
  AudioCaptureState get state => _captureService.currentState;
  bool get isRecording => _captureService.isRecording;
  Uint8List get capturedBytes => _captureService.capturedAudioBytes;
  Duration get recordingDuration => _captureService.recordingDuration;
  int get totalBytesCaptured => _captureService.totalBytesCaptured;
  bool get hasCapturedAudio => _captureService.totalBytesCaptured > 0;
  AudioCaptureConfig get config => _captureService.config;

  /// Checks whether microphone permission is currently granted.
  Future<AudioPermissionStatus> checkPermission() =>
      _permissionService.checkPermission();

  /// Requests microphone permission from the user.
  Future<AudioPermissionStatus> requestPermission() =>
      _permissionService.requestPermission();

  /// Opens the device settings page for Matladu AI.
  Future<bool> openAppSettings() => _permissionService.openSettings();

  /// Starts real-time microphone capture after confirming runtime permissions.
  /// Returns `true` if recording commenced, `false` otherwise (e.g. permission denied or device busy).
  Future<bool> startRecording({AudioCaptureConfig? config}) async {
    // 1. Verify / Request runtime permissions
    var permissionStatus = await _permissionService.checkPermission();
    if (permissionStatus != AudioPermissionStatus.granted) {
      permissionStatus = await _permissionService.requestPermission();
    }

    if (permissionStatus != AudioPermissionStatus.granted) {
      debugPrint('[AudioRepository] Cannot start recording: Permission is $permissionStatus');
      return false;
    }

    // 2. Start hardware audio stream
    return await _captureService.startCapture(config: config);
  }

  /// Stops active recording and returns the captured PCM byte buffer.
  Future<Uint8List?> stopRecording() async {
    return await _captureService.stopCapture();
  }

  /// Cancels active recording and discards buffered audio.
  Future<void> cancelRecording() async {
    await _captureService.cancelCapture();
  }

  /// Clears buffered audio chunks in preparation for the next session.
  void clearBuffer() {
    _captureService.resetBuffer();
  }

  /// Disposes audio capture resources.
  Future<void> dispose() async {
    await _captureService.dispose();
  }
}
