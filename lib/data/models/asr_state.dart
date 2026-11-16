/// Current operational state of the Automatic Speech Recognition (ASR) engine.
enum ASRState {
  /// Engine is resting; no audio processing active.
  idle,

  /// Actively receiving audio stream chunks and performing real-time speech analysis.
  listening,

  /// Finalizing transcription on captured audio buffer.
  transcribing,

  /// Speech recognition finished successfully with a final transcript.
  completed,

  /// Recognition failed (unclear speech, silence, audio error, or cancellation).
  error,
}

/// Represents the output of a speech recognition operation,
/// including partial (interim) and final results, confidence, and language detection.
class ASRRecognitionResult {
  /// The transcribed spoken text in original script or transliteration.
  final String text;

  /// Whether this is a finalized transcription or an interim/partial result.
  final bool isFinal;

  /// Confidence score between 0.0 (uncertain) and 1.0 (absolute confidence).
  final double confidence;

  /// BCP-47 language code detected by the engine (e.g. 'te-IN', 'hi-IN', 'en-IN').
  final String? detectedLanguageCode;

  /// Human-readable language name (e.g. 'Telugu', 'Hindi', 'English').
  final String? detectedLanguageName;

  /// Duration of audio analyzed for this recognition result.
  final Duration audioDuration;

  /// Timestamp when this result was generated.
  final DateTime timestamp;

  /// Explicit flag identifying whether this result was produced by an offline mock adapter.
  /// Never present mock transcription as actual live AI recognition.
  final bool isMock;

  /// Descriptive error message if recognition encountered an issue.
  final String? errorMessage;

  const ASRRecognitionResult({
    required this.text,
    required this.isFinal,
    this.confidence = 1.0,
    this.detectedLanguageCode,
    this.detectedLanguageName,
    required this.audioDuration,
    required this.timestamp,
    this.isMock = false,
    this.errorMessage,
  });

  /// Creates an empty/resting result.
  factory ASRRecognitionResult.empty() => ASRRecognitionResult(
        text: '',
        isFinal: true,
        confidence: 0.0,
        audioDuration: Duration.zero,
        timestamp: DateTime.now(),
        isMock: false,
      );

  /// Creates a failed recognition result.
  factory ASRRecognitionResult.error({
    required String errorMessage,
    Duration? audioDuration,
    bool isMock = false,
  }) =>
      ASRRecognitionResult(
        text: '',
        isFinal: true,
        confidence: 0.0,
        audioDuration: audioDuration ?? Duration.zero,
        timestamp: DateTime.now(),
        isMock: isMock,
        errorMessage: errorMessage,
      );

  /// Whether non-empty speech text was recognized.
  bool get hasText => text.trim().isNotEmpty;

  /// Whether an error occurred.
  bool get hasError => errorMessage != null;

  /// Copy with modifications.
  ASRRecognitionResult copyWith({
    String? text,
    bool? isFinal,
    double? confidence,
    String? detectedLanguageCode,
    String? detectedLanguageName,
    Duration? audioDuration,
    DateTime? timestamp,
    bool? isMock,
    String? errorMessage,
  }) {
    return ASRRecognitionResult(
      text: text ?? this.text,
      isFinal: isFinal ?? this.isFinal,
      confidence: confidence ?? this.confidence,
      detectedLanguageCode: detectedLanguageCode ?? this.detectedLanguageCode,
      detectedLanguageName: detectedLanguageName ?? this.detectedLanguageName,
      audioDuration: audioDuration ?? this.audioDuration,
      timestamp: timestamp ?? this.timestamp,
      isMock: isMock ?? this.isMock,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  String toString() =>
      'ASRRecognitionResult(text: "$text", isFinal: $isFinal, lang: $detectedLanguageCode, confidence: ${confidence.toStringAsFixed(2)}, isMock: $isMock)';
}

/// Configuration parameters for Automatic Speech Recognition.
class ASREngineConfig {
  /// Target or expected language code hint (e.g. 'te-IN', 'hi-IN', 'en-IN', or null for auto-detect).
  final String? languageCodeHint;

  /// Whether the engine should emit interim/partial results during active streaming.
  final bool enableInterimResults;

  /// Maximum silence duration before the engine auto-stops.
  final Duration silenceTimeout;

  /// Punctuation insertion preference.
  final bool enablePunctuation;

  const ASREngineConfig({
    this.languageCodeHint,
    this.enableInterimResults = true,
    this.silenceTimeout = const Duration(milliseconds: 1800),
    this.enablePunctuation = true,
  });

  ASREngineConfig copyWith({
    String? languageCodeHint,
    bool? enableInterimResults,
    Duration? silenceTimeout,
    bool? enablePunctuation,
  }) {
    return ASREngineConfig(
      languageCodeHint: languageCodeHint ?? this.languageCodeHint,
      enableInterimResults: enableInterimResults ?? this.enableInterimResults,
      silenceTimeout: silenceTimeout ?? this.silenceTimeout,
      enablePunctuation: enablePunctuation ?? this.enablePunctuation,
    );
  }
}
