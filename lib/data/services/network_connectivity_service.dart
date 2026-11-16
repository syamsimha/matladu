import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Represents the validated network status of the device.
class NetworkState {
  /// Whether the device has an active network connection that has been validated by the OS.
  final bool isConnected;

  /// Whether the network connection has been verified to have internet capability by Android OS.
  final bool isValidated;

  /// Whether the connection is over Wi-Fi.
  final bool isWifi;

  /// Whether the connection is over Cellular data.
  final bool isCellular;

  /// Human-readable network type: 'wifi', 'cellular', 'ethernet', 'none'.
  final String type;

  const NetworkState({
    required this.isConnected,
    required this.isValidated,
    required this.isWifi,
    required this.isCellular,
    required this.type,
  });

  factory NetworkState.disconnected() => const NetworkState(
        isConnected: false,
        isValidated: false,
        isWifi: false,
        isCellular: false,
        type: 'none',
      );

  factory NetworkState.fromMap(Map<dynamic, dynamic> map) {
    return NetworkState(
      isConnected: map['isConnected'] as bool? ?? false,
      isValidated: map['isValidated'] as bool? ?? false,
      isWifi: map['isWifi'] as bool? ?? false,
      isCellular: map['isCellular'] as bool? ?? false,
      type: map['type'] as String? ?? 'none',
    );
  }

  @override
  String toString() =>
      'NetworkState(connected: $isConnected, validated: $isValidated, type: $type)';
}

/// Service providing OS-level validated network connectivity status.
///
/// PRIVACY & PERFORMANCE:
/// - Uses Android's native [ConnectivityManager.NetworkCallback] and [NET_CAPABILITY_VALIDATED].
/// - ZERO external server pinging or network polling.
/// - Never leaks traffic or communicates with third-party analytics.
/// Service providing OS-level validated network connectivity status.
///
/// PRIVACY & PERFORMANCE:
/// - Uses Android's native [ConnectivityManager.NetworkCallback] and [NET_CAPABILITY_VALIDATED].
/// - ZERO external server pinging or network polling.
/// - Never leaks traffic or communicates with third-party analytics.
class NetworkConnectivityService {
  static const MethodChannel _methodChannel = MethodChannel('com.matladu.ai/network_state');
  static const EventChannel _eventChannel = EventChannel('com.matladu.ai/network_state_stream');

  final _stateController = StreamController<NetworkState>.broadcast();
  NetworkState _currentState = NetworkState.disconnected();
  StreamSubscription<dynamic>? _eventSubscription;
  bool _initialized = false;
  int _stateSequence = 0;

  NetworkState get currentState => _currentState;
  bool get isConnected => _currentState.isConnected;
  bool get isValidatedInternet => _currentState.isValidated;
  Stream<NetworkState> get stateStream => _stateController.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (!kIsWeb && Platform.isAndroid) {
      try {
        final initialMap = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('getNetworkState');
        if (initialMap != null) {
          _updateState(NetworkState.fromMap(initialMap));
        }

        _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
          (dynamic event) {
            if (event is Map<dynamic, dynamic>) {
              _updateState(NetworkState.fromMap(event));
            }
          },
          onError: (dynamic error) {
            debugPrint('[NetworkConnectivityService] EventChannel error: $error');
          },
        );
      } catch (e) {
        debugPrint('[NetworkConnectivityService] Failed to bind native connectivity: $e');
        _updateState(NetworkState.disconnected());
      }
    } else {
      // Test / Desktop fallback
      _updateState(NetworkState.disconnected());
    }
  }

  Future<NetworkState> checkConnectivity() async {
    final int seq = ++_stateSequence;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final map = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('getNetworkState');
        if (map != null && seq == _stateSequence) {
          final state = NetworkState.fromMap(map);
          _updateState(state);
          return state;
        }
      } catch (e) {
        debugPrint('[NetworkConnectivityService] checkConnectivity error: $e');
      }
    }
    return _currentState;
  }

  void _updateState(NetworkState newState) {
    _stateSequence++;
    if (_currentState.isConnected == newState.isConnected &&
        _currentState.isValidated == newState.isValidated &&
        _currentState.type == newState.type) {
      return;
    }
    _currentState = newState;
    debugPrint('[NetworkConnectivityService] Connectivity updated: $_currentState');
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  @visibleForTesting
  void updateStateForTesting(NetworkState state) {
    _updateState(state);
  }

  void dispose() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _stateController.close();
  }
}

