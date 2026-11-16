/// Production-grade transcript validator and hallucination detector for on-device ASR.
///
/// Filters out common autoregressive decoder failure modes:
/// 1. Token repetition loops (e.g. "word word word word", "¡Vale para tu! ¡Vale para tu!...").
/// 2. Byte-fallback tokens and unprintable characters (e.g. `<0x9F>`, `\uFFFD`).
/// 3. Character repetition loops (e.g. `1 1 1 1 1`, `↘ ↘ ↘ ↘ ↘`, `ㄟ ㄟ ㄟ ㄟ ㄟ`).
/// 4. Punctuation-only or whitespace-only artifacts.
/// 5. Script mismatch hallucinations (e.g. Bopomofo/CJK characters emitted on Indian speech).
class TranscriptValidator {
  TranscriptValidator._();

  /// Regex matching Telugu unicode block (U+0C00 - U+0C7F).
  static final RegExp teluguScriptRegex = RegExp(r'[\u0C00-\u0C7F]');

  /// Regex matching Devanagari unicode block (U+0900 - U+097F).
  static final RegExp devanagariScriptRegex = RegExp(r'[\u0900-\u097F]');

  /// Regex matching Tamil unicode block (U+0B80 - U+0BFF).
  static final RegExp tamilScriptRegex = RegExp(r'[\u0B80-\u0BFF]');

  /// Regex matching Kannada unicode block (U+0C80 - U+0CFF).
  static final RegExp kannadaScriptRegex = RegExp(r'[\u0C80-\u0CFF]');

  /// Regex matching Bengali / Assamese / Manipuri unicode block (U+0980 - U+09FF).
  static final RegExp bengaliAssameseScriptRegex = RegExp(r'[\u0980-\u09FF]');

  /// Regex matching Gujarati unicode block (U+0A80 - U+0AFF).
  static final RegExp gujaratiScriptRegex = RegExp(r'[\u0A80-\u0AFF]');

  /// Regex matching Gurmukhi (Punjabi) unicode block (U+0A00 - U+0A7F).
  static final RegExp gurmukhiScriptRegex = RegExp(r'[\u0A00-\u0A7F]');

  /// Regex matching Odia unicode block (U+0B00 - U+0B7F).
  static final RegExp odiaScriptRegex = RegExp(r'[\u0B00-\u0B7F]');

  /// Regex matching Malayalam unicode block (U+0D00 - U+0D7F).
  static final RegExp malayalamScriptRegex = RegExp(r'[\u0D00-\u0D7F]');

  /// Regex matching Perso-Arabic (Urdu, Kashmiri, Sindhi) unicode blocks.
  static final RegExp persoArabicScriptRegex = RegExp(r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]');

  /// Regex matching Ol Chiki (Santali) unicode block (U+1C50 - U+1C7F).
  static final RegExp olChikiScriptRegex = RegExp(r'[\u1C50-\u1C7F]');

  /// Regex matching Latin alphabet (English / German / transliteration).
  static final RegExp latinScriptRegex = RegExp(r'[a-zA-Z]');

  /// Regex matching Whisper raw byte tokens like <0x9F>, <0xE0>, etc.
  static final RegExp rawByteTokenRegex = RegExp(r'<0x[0-9a-fA-F]{2}>');

  /// Regex matching CJK / Bopomofo / East Asian characters frequently hallucinated by Whisper Tiny.
  static final RegExp cjkHallucinationRegex = RegExp(
    r'[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\u3100-\u312f\u1100-\u11ff\u3130-\u318f\ua960-\ua97f\ud7b0-\ud7ff]',
  );

  /// High-confidence Romanized Telugu keywords and particles.
  static const Set<String> romanizedTeluguKeywords = {
    'namaste', 'namaskaram', 'ela', 'unnaru', 'unnavu', 'bagunnanu',
    'bagundi', 'baagundi', 'baagunnanu', 'ekkada', 'cheppandi', 'chala',
    'chaala', 'dhanyavadalu', 'meeru', 'nenu', 'andaru', 'kavali',
    'enti', 'emiti', 'eppudu', 'kadu', 'avunu', 'ledu', 'undhi',
    'undi', 'matladandi', 'cheppu', 'ravali', 'vellali',
    'vachanu', 'koddiga', 'koncham', 'manchi',
  };

  static const Set<String> _commonEnglishWords = {
    'welcome', 'to', 'the', 'hello', 'how', 'are', 'you', 'good', 'morning',
    'evening', 'night', 'thank', 'thanks', 'what', 'where', 'when', 'why',
    'is', 'this', 'that', 'please', 'help', 'translate', 'speak', 'connect',
  };

  /// Determines if a Latin-script text represents Romanized Telugu.
  static bool isRomanizedTelugu(String text) {
    final words = text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').split(RegExp(r'\s+'));
    if (words.any((w) => _commonEnglishWords.contains(w))) {
      return false; // Contains explicit English vocabulary
    }
    for (final word in words) {
      if (romanizedTeluguKeywords.contains(word)) {
        return true;
      }
    }
    return false;
  }

  /// Validates whether the translated text matches the expected target language script.
  /// Rejects outputs that contain Indic scripts when the target is European (e.g. German, English).
  static bool isScriptValidForTarget(String text, String targetLangCode) {
    final clean = text.trim();
    if (clean.isEmpty) return true;
    final normTgt = targetLangCode.toLowerCase().trim().split('-').first.split('_').first;

    // European / Latin-script targets (German, English, Spanish, French)
    if (normTgt == 'de' || normTgt == 'en' || normTgt == 'es' || normTgt == 'fr') {
      final hasIndic = teluguScriptRegex.hasMatch(clean) ||
          devanagariScriptRegex.hasMatch(clean) ||
          tamilScriptRegex.hasMatch(clean) ||
          kannadaScriptRegex.hasMatch(clean) ||
          bengaliAssameseScriptRegex.hasMatch(clean) ||
          gujaratiScriptRegex.hasMatch(clean) ||
          gurmukhiScriptRegex.hasMatch(clean) ||
          odiaScriptRegex.hasMatch(clean) ||
          malayalamScriptRegex.hasMatch(clean);
      if (hasIndic) {
        return false;
      }
    }

    return true;
  }

  /// Validates and cleans a raw ASR transcript.
  ///
  /// Returns a [TranscriptValidationResult] containing the cleaned text,
  /// whether it is valid for downstream translation, detected script,
  /// and any hallucination or repetition flags.
  static TranscriptValidationResult validate(
    String rawText, {
    String? expectedLanguageCode,
  }) {
    if (rawText.trim().isEmpty) {
      return const TranscriptValidationResult(
        cleanedText: '',
        isValid: false,
        reason: 'Empty transcript',
      );
    }

    var text = rawText.trim();

    // 1. Check for raw byte tokens (e.g. <0x9F>)
    if (rawByteTokenRegex.hasMatch(text)) {
      text = text.replaceAll(rawByteTokenRegex, '').trim();
      if (text.isEmpty) {
        return const TranscriptValidationResult(
          cleanedText: '',
          isValid: false,
          isHallucination: true,
          reason: 'Contained only corrupted byte tokens',
        );
      }
    }

    // 2. Remove unicode replacement character (\uFFFD)
    text = text.replaceAll('\uFFFD', '').trim();

    // 3. Detect and remove CJK / Bopomofo hallucinations (e.g. ㄟ U+311F)
    if (cjkHallucinationRegex.hasMatch(text)) {
      // If expected language is Indian or English, CJK characters are 100% hallucinations
      final hasLegitScript = teluguScriptRegex.hasMatch(text) ||
          devanagariScriptRegex.hasMatch(text) ||
          tamilScriptRegex.hasMatch(text) ||
          kannadaScriptRegex.hasMatch(text) ||
          bengaliAssameseScriptRegex.hasMatch(text) ||
          gujaratiScriptRegex.hasMatch(text) ||
          gurmukhiScriptRegex.hasMatch(text) ||
          odiaScriptRegex.hasMatch(text) ||
          malayalamScriptRegex.hasMatch(text) ||
          persoArabicScriptRegex.hasMatch(text) ||
          olChikiScriptRegex.hasMatch(text) ||
          latinScriptRegex.hasMatch(text);
      if (!hasLegitScript) {
        return const TranscriptValidationResult(
          cleanedText: '',
          isValid: false,
          isHallucination: true,
          reason: 'Contained only Asian/Bopomofo hallucination tokens',
        );
      }
      text = text.replaceAll(cjkHallucinationRegex, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    // 4. Check for punctuation/symbol-only text
    final alphanumericCount = RegExp(r'[\p{L}\p{N}]', unicode: true).allMatches(text).length;
    if (alphanumericCount == 0) {
      return const TranscriptValidationResult(
        cleanedText: '',
        isValid: false,
        reason: 'Punctuation or symbols only',
      );
    }

    // 5. Detect and clean character repetition loops (e.g. "1 1 1 1 1", "↘ ↘ ↘ ↘", "aaaaa")
    final cleanedCharRepetition = _cleanCharacterLoops(text);
    if (cleanedCharRepetition.isEmpty) {
      return const TranscriptValidationResult(
        cleanedText: '',
        isValid: false,
        isHallucination: true,
        reason: 'Single character repetition loop',
      );
    }
    text = cleanedCharRepetition;

    // 6. Detect and clean phrase / word repetition loops (e.g. "¡Vale para tu! ¡Vale para tu!...")
    final cleanedPhraseRepetition = _cleanPhraseLoops(text);
    if (cleanedPhraseRepetition.isEmpty) {
      return const TranscriptValidationResult(
        cleanedText: '',
        isValid: false,
        isHallucination: true,
        reason: 'Phrase repetition loop',
      );
    }
    text = cleanedPhraseRepetition;

    // 7. Check for incomplete or fragmented speech input (e.g. "nd", "th", "d")
    final lower = text.toLowerCase().trim();
    if (lower.length <= 2 && latinScriptRegex.hasMatch(lower)) {
      const validShortWords = {
        'a', 'i', 'in', 'on', 'at', 'to', 'is', 'it', 'he', 'we', 'me', 'my',
        'up', 'so', 'no', 'go', 'do', 'hi', 'ok', 'by', 'as', 'if', 'or', 'an',
        'ja', 'du', 'er', 'es', 'da', 'am', 'wo'
      };
      if (!validShortWords.contains(lower)) {
        return const TranscriptValidationResult(
          cleanedText: '',
          isValid: false,
          reason: 'Incomplete or fragmented speech input. Please tap and speak clearly.',
        );
      }
    }

    if (text.isEmpty) {
      return const TranscriptValidationResult(
        cleanedText: '',
        isValid: false,
        reason: 'Cleaned text is empty',
      );
    }

    // 8. Script analysis
    // NOTE: Unicode script inspection is only an auxiliary check.
    // It must NEVER override Whisper's acoustic language detection,
    // as Romanized Indic speech (e.g. "Namaskaram") contains Latin script.
    final hasTelugu = teluguScriptRegex.hasMatch(text);
    final hasDevanagari = devanagariScriptRegex.hasMatch(text);
    final hasTamil = tamilScriptRegex.hasMatch(text);
    final hasKannada = kannadaScriptRegex.hasMatch(text);
    final hasBengaliAssamese = bengaliAssameseScriptRegex.hasMatch(text);
    final hasGujarati = gujaratiScriptRegex.hasMatch(text);
    final hasGurmukhi = gurmukhiScriptRegex.hasMatch(text);
    final hasOdia = odiaScriptRegex.hasMatch(text);
    final hasMalayalam = malayalamScriptRegex.hasMatch(text);
    final hasPersoArabic = persoArabicScriptRegex.hasMatch(text);
    final hasOlChiki = olChikiScriptRegex.hasMatch(text);
    final hasLatin = latinScriptRegex.hasMatch(text);
    final isRomanizedTe = hasLatin && isRomanizedTelugu(text);

    String resolvedScript = 'unknown';
    if (hasTelugu || isRomanizedTe) {
      resolvedScript = 'te';
    } else if (hasDevanagari) {
      resolvedScript = (expectedLanguageCode == 'mr' ||
              expectedLanguageCode == 'ne' ||
              expectedLanguageCode == 'sa' ||
              expectedLanguageCode == 'mai' ||
              expectedLanguageCode == 'kok' ||
              expectedLanguageCode == 'doi' ||
              expectedLanguageCode == 'brx')
          ? expectedLanguageCode!
          : 'hi';
    } else if (hasTamil) {
      resolvedScript = 'ta';
    } else if (hasKannada) {
      resolvedScript = 'kn';
    } else if (hasBengaliAssamese) {
      resolvedScript = (expectedLanguageCode == 'as' || expectedLanguageCode == 'mni')
          ? expectedLanguageCode!
          : 'bn';
    } else if (hasGujarati) {
      resolvedScript = 'gu';
    } else if (hasGurmukhi) {
      resolvedScript = 'pa';
    } else if (hasOdia) {
      resolvedScript = 'or';
    } else if (hasMalayalam) {
      resolvedScript = 'ml';
    } else if (hasPersoArabic) {
      resolvedScript = (expectedLanguageCode == 'ks' || expectedLanguageCode == 'sd')
          ? expectedLanguageCode!
          : 'ur';
    } else if (hasOlChiki) {
      resolvedScript = 'sat';
    } else if (hasLatin) {
      resolvedScript = (expectedLanguageCode == 'de') ? 'de' : 'en';
    }

    return TranscriptValidationResult(
      cleanedText: text,
      isValid: true,
      resolvedScript: resolvedScript,
      isRomanized: isRomanizedTe,
    );
  }

  /// Collapses and eliminates character repetition loops like "1 1 1 1 1" or "a a a a a".
  static String _cleanCharacterLoops(String input) {
    // Check if input is a sequence of identical single characters separated by spaces
    final tokens = input.split(RegExp(r'\s+'));
    if (tokens.length >= 3) {
      final first = tokens.first;
      final allSame = tokens.every((t) => t == first);
      if (allSame) {
        // Entire sequence is just a single token repeated 3+ times
        return '';
      }
    }

    // Collapse character streaks like "aaaaaaa" -> "aa"
    final regex = RegExp(r'(.)\1{4,}');
    if (regex.hasMatch(input)) {
      // If the streak represents more than 60% of the string, it's a loop failure
      final loopLength = regex.firstMatch(input)!.group(0)!.length;
      if (loopLength >= input.length * 0.6) {
        return '';
      }
      return input.replaceAllMapped(regex, (m) => '${m.group(1)}${m.group(1)}').trim();
    }

    return input;
  }

  /// Detects and eliminates repeated n-gram phrases (e.g. "¡Vale para tu! ¡Vale para tu!...").
  static String _cleanPhraseLoops(String input) {
    final words = input.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length < 4) return input;

    // Test phrase sizes from 1 to 5 words
    for (int phraseLen = 1; phraseLen <= 5; phraseLen++) {
      if (words.length < phraseLen * 3) continue;

      for (int i = 0; i <= words.length - (phraseLen * 3); i++) {
        final phrase = words.sublist(i, i + phraseLen).join(' ').toLowerCase();
        int repetitions = 1;
        int nextIdx = i + phraseLen;

        while (nextIdx + phraseLen <= words.length) {
          final nextPhrase = words.sublist(nextIdx, nextIdx + phraseLen).join(' ').toLowerCase();
          if (nextPhrase == phrase) {
            repetitions++;
            nextIdx += phraseLen;
          } else {
            break;
          }
        }

        if (repetitions >= 3) {
          // If the repetition spans the entire text or almost all of it, reject as loop
          final loopWords = repetitions * phraseLen;
          if (loopWords >= words.length * 0.7) {
            return '';
          }
          // Otherwise, retain only 1 occurrence of the phrase and trim the loop
          final prefix = words.sublist(0, i);
          final kept = words.sublist(i, i + phraseLen);
          final suffix = words.sublist(nextIdx);
          final reconstructed = [...prefix, ...kept, ...suffix].join(' ');
          return reconstructed.trim();
        }
      }
    }

    return input;
  }
}

/// Result of transcript validation.
class TranscriptValidationResult {
  final String cleanedText;
  final bool isValid;
  final bool isHallucination;
  final String? reason;
  final String resolvedScript;
  final bool isRomanized;

  const TranscriptValidationResult({
    required this.cleanedText,
    required this.isValid,
    this.isHallucination = false,
    this.reason,
    this.resolvedScript = 'unknown',
    this.isRomanized = false,
  });
}

