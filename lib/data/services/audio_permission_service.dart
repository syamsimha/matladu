import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/audio_recording_state.dart';

/// Abstract contract for managing microphone runtime permissions.
abstract class IAudioPermissionService {
  /// Checks current microphone permission status without requesting.
  Future<AudioPermissionStatus> checkPermission();

  /// Requests microphone permission from the user at runtime.
  Future<AudioPermissionStatus> requestPermission();

  /// Checks if microphone permission is currently granted.
  Future<bool> hasPermission();

  /// Opens the operating system's application settings page.
  Future<bool> openSettings();
}

/// Concrete implementation utilizing `permission_handler` for Android & iOS.
class AudioPermissionService implements IAudioPermissionService {
  const AudioPermissionService();

  @override
  Future<AudioPermissionStatus> checkPermission() async {
    try {
      final status = await Permission.microphone.status;
      return _mapPermissionStatus(status);
    } catch (e) {
      debugPrint('[AudioPermissionService] Error checking permission: $e');
      return AudioPermissionStatus.undetermined;
    }
  }

  @override
  Future<AudioPermissionStatus> requestPermission() async {
    try {
      final status = await Permission.microphone.request();
      return _mapPermissionStatus(status);
    } catch (e) {
      debugPrint('[AudioPermissionService] Error requesting permission: $e');
      return AudioPermissionStatus.denied;
    }
  }

  @override
  Future<bool> hasPermission() async {
    final status = await checkPermission();
    return status == AudioPermissionStatus.granted;
  }

  @override
  Future<bool> openSettings() async {
    try {
      return await openAppSettings();
    } catch (e) {
      debugPrint('[AudioPermissionService] Error opening app settings: $e');
      return false;
    }
  }

  AudioPermissionStatus _mapPermissionStatus(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
        return AudioPermissionStatus.granted;
      case PermissionStatus.denied:
        return AudioPermissionStatus.denied;
      case PermissionStatus.permanentlyDenied:
        return AudioPermissionStatus.permanentlyDenied;
      case PermissionStatus.restricted:
        return AudioPermissionStatus.restricted;
      case PermissionStatus.provisional:
        return AudioPermissionStatus.granted;
    }
  }
}

