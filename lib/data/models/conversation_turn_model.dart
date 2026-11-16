import 'package:flutter/material.dart';
import 'tts_result.dart';

/// Represents the explicit state machine for a single conversation turn in Phase 6.
enum ConversationTurnState {
  /// Ready to listen; microphone is idle and accessible.
  idle,

  /// Actively capturing PCM audio chunks from the microphone.
  listening,

  /// Microphone stream finalized; Whisper speech decoder processing audio.
  processingSpeech,

  /// Determining spoken source language from Whisper LID probabilities.
  recognizingLanguage,

  /// Executing on-device neural translation between resolved language pair.
  translating,

  /// On-device TTS engine is actively speaking the translated text.
  speakingTranslatedAudio,

  /// Turn completed successfully; UI displaying original and translated text.
  completed,

  /// An error occurred (e.g. silence, permission denied, missing voice).
  error;

  String get displayName {
    switch (this) {
      case ConversationTurnState.idle:
        return 'Ready - Tap to Speak';
      case ConversationTurnState.listening:
        return 'Listening...';
      case ConversationTurnState.processingSpeech:
        return 'Processing audio...';
      case ConversationTurnState.recognizingLanguage:
        return 'Detecting language...';
      case ConversationTurnState.translating:
        return 'Translating on-device...';
      case ConversationTurnState.speakingTranslatedAudio:
        return 'Speaking translation...';
      case ConversationTurnState.completed:
        return 'Translation Complete';
      case ConversationTurnState.error:
        return 'Error';
    }
  }

  IconData get icon {
    switch (this) {
      case ConversationTurnState.idle:
        return Icons.mic_none_rounded;
      case ConversationTurnState.listening:
        return Icons.mic_rounded;
      case ConversationTurnState.processingSpeech:
        return Icons.graphic_eq_rounded;
      case ConversationTurnState.recognizingLanguage:
        return Icons.language_rounded;
      case ConversationTurnState.translating:
        return Icons.sync_rounded;
      case ConversationTurnState.speakingTranslatedAudio:
        return Icons.volume_up_rounded;
      case ConversationTurnState.completed:
        return Icons.check_circle_rounded;
      case ConversationTurnState.error:
        return Icons.error_outline_rounded;
    }
  }
}

/// Identifies which speaker in the conversation spoke this turn.
enum ConversationSpeaker {
  speakerA,
  speakerB;

  String get label => this == ConversationSpeaker.speakerA ? 'Speaker 1' : 'Speaker 2';
}

/// Data model representing a complete, atomic conversation turn.
class ConversationTurnModel {
  final String id;
  final int turnNumber;
  final ConversationSpeaker speaker;
  final String sourceLanguageCode;
  final String sourceLanguageName;
  final String targetLanguageCode;
  final String targetLanguageName;
  final String originalText;
  final String translatedText;
  final ConversationTurnState state;
  final TtsPlaybackState playbackState;
  final DateTime timestamp;
  final bool isMock;
  final double confidence;
  final String? errorMessage;
  final Duration audioDuration;

  const ConversationTurnModel({
    required this.id,
    required this.turnNumber,
    required this.speaker,
    required this.sourceLanguageCode,
    required this.sourceLanguageName,
    required this.targetLanguageCode,
    required this.targetLanguageName,
    required this.originalText,
    required this.translatedText,
    this.state = ConversationTurnState.completed,
    this.playbackState = TtsPlaybackState.idle,
    required this.timestamp,
    this.isMock = false,
    this.confidence = 1.0,
    this.errorMessage,
    this.audioDuration = Duration.zero,
  });

  bool get isCompleted => state == ConversationTurnState.completed;
  bool get hasError => state == ConversationTurnState.error || errorMessage != null;

  String get directionLabel => '$sourceLanguageName to $targetLanguageName';

  ConversationTurnModel copyWith({
    String? id,
    int? turnNumber,
    ConversationSpeaker? speaker,
    String? sourceLanguageCode,
    String? sourceLanguageName,
    String? targetLanguageCode,
    String? targetLanguageName,
    String? originalText,
    String? translatedText,
    ConversationTurnState? state,
    TtsPlaybackState? playbackState,
    DateTime? timestamp,
    bool? isMock,
    double? confidence,
    String? errorMessage,
    Duration? audioDuration,
  }) {
    return ConversationTurnModel(
      id: id ?? this.id,
      turnNumber: turnNumber ?? this.turnNumber,
      speaker: speaker ?? this.speaker,
      sourceLanguageCode: sourceLanguageCode ?? this.sourceLanguageCode,
      sourceLanguageName: sourceLanguageName ?? this.sourceLanguageName,
      targetLanguageCode: targetLanguageCode ?? this.targetLanguageCode,
      targetLanguageName: targetLanguageName ?? this.targetLanguageName,
      originalText: originalText ?? this.originalText,
      translatedText: translatedText ?? this.translatedText,
      state: state ?? this.state,
      playbackState: playbackState ?? this.playbackState,
      timestamp: timestamp ?? this.timestamp,
      isMock: isMock ?? this.isMock,
      confidence: confidence ?? this.confidence,
      errorMessage: errorMessage ?? this.errorMessage,
      audioDuration: audioDuration ?? this.audioDuration,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'turnNumber': turnNumber,
        'speaker': speaker.name,
        'sourceLanguageCode': sourceLanguageCode,
        'sourceLanguageName': sourceLanguageName,
        'targetLanguageCode': targetLanguageCode,
        'targetLanguageName': targetLanguageName,
        'originalText': originalText,
        'translatedText': translatedText,
        'state': state.name,
        'playbackState': playbackState.name,
        'timestamp': timestamp.toIso8601String(),
        'isMock': isMock,
        'confidence': confidence,
        'errorMessage': errorMessage,
        'audioDurationMs': audioDuration.inMilliseconds,
      };

  factory ConversationTurnModel.fromJson(Map<String, dynamic> json) {
    return ConversationTurnModel(
      id: json['id'] as String,
      turnNumber: json['turnNumber'] as int? ?? 1,
      speaker: ConversationSpeaker.values.firstWhere(
        (s) => s.name == json['speaker'],
        orElse: () => ConversationSpeaker.speakerA,
      ),
      sourceLanguageCode: json['sourceLanguageCode'] as String,
      sourceLanguageName: json['sourceLanguageName'] as String,
      targetLanguageCode: json['targetLanguageCode'] as String,
      targetLanguageName: json['targetLanguageName'] as String,
      originalText: json['originalText'] as String,
      translatedText: json['translatedText'] as String,
      state: ConversationTurnState.values.firstWhere(
        (s) => s.name == json['state'],
        orElse: () => ConversationTurnState.completed,
      ),
      playbackState: TtsPlaybackState.values.firstWhere(
        (s) => s.name == json['playbackState'],
        orElse: () => TtsPlaybackState.idle,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      isMock: json['isMock'] as bool? ?? false,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      errorMessage: json['errorMessage'] as String?,
      audioDuration: Duration(milliseconds: json['audioDurationMs'] as int? ?? 0),
    );
  }
}

