import 'language_model.dart';
import 'conversation_turn_model.dart';
import '../services/asr/transcript_validator.dart';

/// Resolved direction for a two-way conversation turn.
class TwoWayDirectionResult {
  final LanguageModel sourceLanguage;
  final LanguageModel targetLanguage;
  final ConversationSpeaker speaker;
  final bool isOutsidePair;
  final bool isUncertain;
  final String? warningMessage;
  final bool canTranslate;

  const TwoWayDirectionResult({
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.speaker,
    this.isOutsidePair = false,
    this.isUncertain = false,
    this.warningMessage,
    this.canTranslate = true,
  });

  String get directionKey => '${sourceLanguage.code}_to_${targetLanguage.code}';
}

/// Helper and manager for two-way conversation language direction resolution.
/// Ensures reliable alternating turns between Language A and Language B,
/// and dynamically resolves speaker language when Auto Detect is active.
class TwoWayDirectionManager {
  LanguageModel _languageA;
  LanguageModel _languageB;
  LanguageModel _partnerLanguage;
  bool _manualOverride = false;
  bool _preferAtoB = true;

  TwoWayDirectionManager({
    required LanguageModel languageA,
    required LanguageModel languageB,
  })  : _languageA = languageA,
        _languageB = languageB,
        _partnerLanguage = (languageA.code == 'auto' || languageA.code == 'und')
            ? (LanguageModel.fromCode('en') ?? const LanguageModel(code: 'en', name: 'English', nativeName: 'English'))
            : languageA;

  LanguageModel get languageA => _languageA;
  LanguageModel get languageB => _languageB;
  LanguageModel get partnerLanguage => _partnerLanguage;
  bool get manualOverride => _manualOverride;
  bool get preferAtoB => _preferAtoB;

  void updateLanguages({required LanguageModel languageA, required LanguageModel languageB}) {
    _languageA = languageA;
    _languageB = languageB;
    if (_languageA.code != 'auto' && _languageA.code != 'und') {
      _partnerLanguage = _languageA;
    }
  }

  /// Manually swaps the current preferred translation direction.
  void swapDirection() {
    _preferAtoB = !_preferAtoB;
    _manualOverride = true;
  }

  /// Clears manual override so automatic spoken-language detection determines direction.
  void clearManualOverride() {
    _manualOverride = false;
  }

  /// Resolves the source and target languages for a spoken transcript.
  /// Uses Whisper's detected language code to automatically select the matching direction.
  TwoWayDirectionResult resolve({
    required String? detectedLanguageCode,
    double? confidence,
    String? spokenText,
  }) {
    var normDetected = _normalizeCode(detectedLanguageCode);
    final normA = _normalizeCode(_languageA.code);
    final normB = _normalizeCode(_languageB.code);

    // If spokenText is provided, check for Romanized Telugu/Hindi and script validation
    if (spokenText != null && spokenText.trim().isNotEmpty) {
      if (TranscriptValidator.isRomanizedTelugu(spokenText)) {
        normDetected = 'te';
      } else if (TranscriptValidator.isRomanizedHindi(spokenText)) {
        normDetected = 'hi';
      } else if (normDetected.isEmpty || normDetected == 'auto' || normDetected == 'und') {
        final validation = TranscriptValidator.validate(spokenText);
        if (validation.isValid && validation.resolvedScript != 'unknown') {
          normDetected = validation.resolvedScript;
        }
      }
    }

    // If manual override was explicitly set by user, honor it
    if (_manualOverride) {
      final src = _preferAtoB ? _languageA : _languageB;
      final tgt = _preferAtoB ? _languageB : _languageA;
      final spk = _preferAtoB ? ConversationSpeaker.speakerA : ConversationSpeaker.speakerB;
      return TwoWayDirectionResult(
        sourceLanguage: src,
        targetLanguage: tgt,
        speaker: spk,
        canTranslate: true,
      );
    }

    // 1. Handle uncertain, unknown, or low-confidence language detection (DO NOT GUESS)
    if (normDetected.isEmpty ||
        normDetected == 'auto' ||
        normDetected == 'und' ||
        (confidence != null && confidence < 0.35)) {
      final currentSrc = _preferAtoB ? _languageA : _languageB;
      final currentTgt = _preferAtoB ? _languageB : _languageA;
      final currentSpeaker =
          _preferAtoB ? ConversationSpeaker.speakerA : ConversationSpeaker.speakerB;

      return TwoWayDirectionResult(
        sourceLanguage: currentSrc,
        targetLanguage: currentTgt,
        speaker: currentSpeaker,
        isUncertain: true,
        canTranslate: false,
        warningMessage:
            'Spoken language could not be determined with confidence. Tap Try Again or select your language.',
      );
    }

    // 2. DYNAMIC AUTO DETECT MODE (Language A is Auto Detect):
    if (normA == 'auto' || normA == 'und') {
      if (normDetected == normB) {
        // Speaker is speaking Target Language (Language B).
        // Translate from Target (Language B) -> Partner Language.
        final partner = (_partnerLanguage.code != normB && _partnerLanguage.code != 'auto')
            ? _partnerLanguage
            : (LanguageModel.fromCode('en') ?? const LanguageModel(code: 'en', name: 'English', nativeName: 'English'));

        return TwoWayDirectionResult(
          sourceLanguage: _languageB,
          targetLanguage: partner,
          speaker: ConversationSpeaker.speakerB,
          canTranslate: true,
        );
      } else {
        // Speaker is speaking a language other than Target Language.
        // Update partner language to this detected language.
        final detectedModel = LanguageModel.fromCode(normDetected) ??
            LanguageModel(
              code: normDetected,
              name: normDetected.toUpperCase(),
              nativeName: normDetected.toUpperCase(),
            );
        _partnerLanguage = detectedModel;

        // Disallow self-translation if detected matches target
        if (normDetected == normB) {
          return TwoWayDirectionResult(
            sourceLanguage: detectedModel,
            targetLanguage: _languageB,
            speaker: ConversationSpeaker.speakerA,
            canTranslate: false,
            warningMessage:
                'Source and target languages are identical (${detectedModel.name}). Please select a different target language.',
          );
        }

        return TwoWayDirectionResult(
          sourceLanguage: detectedModel,
          targetLanguage: _languageB,
          speaker: ConversationSpeaker.speakerA,
          canTranslate: true,
        );
      }
    }

    // 3. EXPLICIT LANGUAGE PAIR: Check if detected language matches Language A
    if (normDetected == normA) {
      _preferAtoB = false; // Next speaker will likely respond in B
      return TwoWayDirectionResult(
        sourceLanguage: _languageA,
        targetLanguage: _languageB,
        speaker: ConversationSpeaker.speakerA,
        canTranslate: true,
      );
    }

    // 4. EXPLICIT LANGUAGE PAIR: Check if detected language matches Language B
    if (normDetected == normB) {
      _preferAtoB = true; // Next speaker will likely respond in A
      return TwoWayDirectionResult(
        sourceLanguage: _languageB,
        targetLanguage: _languageA,
        speaker: ConversationSpeaker.speakerB,
        canTranslate: true,
      );
    }

    // 5. Detected language is outside the selected language pair (e.g. Hindi detected when pair is En - Te)
    // PRESERVE SELECTED LANGUAGE PAIR — DO NOT SILENTLY DEFAULT TO LANGUAGE B
    final detectedModel = LanguageModel.fromCode(normDetected) ??
        LanguageModel(
          code: normDetected,
          name: normDetected.toUpperCase(),
          nativeName: normDetected.toUpperCase(),
        );

    final preservedSrc = _preferAtoB ? _languageA : _languageB;
    final preservedTgt = _preferAtoB ? _languageB : _languageA;
    final preservedSpeaker =
        _preferAtoB ? ConversationSpeaker.speakerA : ConversationSpeaker.speakerB;

    return TwoWayDirectionResult(
      sourceLanguage: preservedSrc,
      targetLanguage: preservedTgt,
      speaker: preservedSpeaker,
      isOutsidePair: true,
      canTranslate: false,
      warningMessage:
          'Detected ${detectedModel.name}, which is outside the active ${_languageA.name} to ${_languageB.name} conversation. Tap Try Again or switch languages.',
    );
  }

  static String _normalizeCode(String? code) {
    if (code == null || code.isEmpty) return '';
    final clean = code.replaceAll('<|', '').replaceAll('|>', '').toLowerCase().trim();
    if (clean == 'auto') return 'auto';
    if (clean == 'und') return 'und';
    if (clean.startsWith('te')) return 'te';
    if (clean.startsWith('hi')) return 'hi';
    if (clean.startsWith('en')) return 'en';
    if (clean.startsWith('ta')) return 'ta';
    if (clean.startsWith('kn')) return 'kn';
    if (clean.startsWith('mr')) return 'mr';
    if (clean.startsWith('bn')) return 'bn';
    if (clean.startsWith('de')) return 'de';
    return clean.split('-').first;
  }
}
