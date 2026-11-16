/// Execution states for on-device Text-to-Speech synthesis and playback.
enum TtsPlaybackState {
  /// Engine is idle and ready to synthesize.
  idle,

  /// Preparing offline voice and audio stream.
  preparing,

  /// Active speech output via speaker/headphones.
  speaking,

  /// Audio playback is paused.
  paused,

  /// Speech synthesis completed successfully.
  completed,

  /// Audio output manually stopped by user or interrupted.
  stopped,

  /// Required language voice is not installed offline on this device.
  voiceUnavailable,

  /// An error occurred during native synthesis or audio routing.
  error,
}

/// Result metadata for a Text-to-Speech playback request.
class TtsResult {
  final String requestId;
  final TtsPlaybackState state;
  final String text;
  final String languageCode;
  final String? voiceName;
  final String? errorMessage;
  final bool isOffline;
  final Duration duration;

  const TtsResult({
    required this.requestId,
    required this.state,
    required this.text,
    required this.languageCode,
    this.voiceName,
    this.errorMessage,
    this.isOffline = true,
    this.duration = Duration.zero,
  });

  bool get isSpeaking => state == TtsPlaybackState.speaking;
  bool get isCompleted => state == TtsPlaybackState.completed;
  bool get isVoiceUnavailable => state == TtsPlaybackState.voiceUnavailable;
  bool get hasError => state == TtsPlaybackState.error;

  TtsResult copyWith({
    String? requestId,
    TtsPlaybackState? state,
    String? text,
    String? languageCode,
    String? voiceName,
    String? errorMessage,
    bool? isOffline,
    Duration? duration,
  }) {
    return TtsResult(
      requestId: requestId ?? this.requestId,
      state: state ?? this.state,
      text: text ?? this.text,
      languageCode: languageCode ?? this.languageCode,
      voiceName: voiceName ?? this.voiceName,
      errorMessage: errorMessage ?? this.errorMessage,
      isOffline: isOffline ?? this.isOffline,
      duration: duration ?? this.duration,
    );
  }

  @override
  String toString() =>
      'TtsResult(req: $requestId, state: $state, lang: $languageCode, voice: $voiceName, offline: $isOffline)';
}

