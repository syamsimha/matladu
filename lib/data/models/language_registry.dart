/// Authoritative Centralized Registry for all 24 supported languages in Matladu AI.
///
/// SCOPE:
/// - All 22 Indian Scheduled Languages (Eighth Schedule of the Constitution of India).
/// - English (Global / Bridge language).
/// - German (European language).
/// Total: 24 Languages, yielding 24 * 23 = 552 directed translation pairs.
class LanguageCapability {
  final String code;
  final String name;
  final String nativeName;
  final String scriptName;
  final RegExp scriptRegex;
  final String googleSpeechLocale;
  final bool isGoogleSpeechSupported;
  final String whisperCode;
  final bool isWhisperLidSupported;
  final bool isMlKitOfflineSupported;
  final String myMemoryCode;
  final String ttsLocale;
  final bool isTtsSupported;

  const LanguageCapability({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.scriptName,
    required this.scriptRegex,
    required this.googleSpeechLocale,
    this.isGoogleSpeechSupported = true,
    required this.whisperCode,
    this.isWhisperLidSupported = true,
    required this.isMlKitOfflineSupported,
    required this.myMemoryCode,
    required this.ttsLocale,
    this.isTtsSupported = true,
  });
}

class LanguageRegistry {
  LanguageRegistry._();

  // Shared Script RegExps
  static final RegExp devanagariRegex = RegExp(r'[\u0900-\u097F]');
  static final RegExp bengaliAssameseRegex = RegExp(r'[\u0980-\u09FF]');
  static final RegExp gurmukhiRegex = RegExp(r'[\u0A00-\u0A7F]');
  static final RegExp gujaratiRegex = RegExp(r'[\u0A80-\u0AFF]');
  static final RegExp odiaRegex = RegExp(r'[\u0B00-\u0B7F]');
  static final RegExp tamilRegex = RegExp(r'[\u0B80-\u0BFF]');
  static final RegExp teluguRegex = RegExp(r'[\u0C00-\u0C7F]');
  static final RegExp kannadaRegex = RegExp(r'[\u0C80-\u0CFF]');
  static final RegExp malayalamRegex = RegExp(r'[\u0D00-\u0D7F]');
  static final RegExp persoArabicRegex = RegExp(r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]');
  static final RegExp olChikiRegex = RegExp(r'[\u1C50-\u1C7F]');
  static final RegExp latinRegex = RegExp(r'[a-zA-ZäöüÄÖÜß]');

  /// Master Map of all 24 product languages.
  static final Map<String, LanguageCapability> _capabilities = {
    // 1. Assamese
    'as': LanguageCapability(
      code: 'as',
      name: 'Assamese',
      nativeName: 'অসমীয়া',
      scriptName: 'Bengali/Assamese',
      scriptRegex: bengaliAssameseRegex,
      googleSpeechLocale: 'as-IN',
      isGoogleSpeechSupported: false,
      whisperCode: 'as',
      isMlKitOfflineSupported: false,
      myMemoryCode: 'as',
      ttsLocale: 'as-IN',
    ),

    // 2. Bengali
    'bn': LanguageCapability(
      code: 'bn',
      name: 'Bengali',
      nativeName: 'বাংলা',
      scriptName: 'Bengali',
      scriptRegex: bengaliAssameseRegex,
      googleSpeechLocale: 'bn-IN',
      isGoogleSpeechSupported: true,
      whisperCode: 'bn',
      isMlKitOfflineSupported: true,
      myMemoryCode: 'bn',
      ttsLocale: 'bn-IN',
    ),

    // 3. Bodo
    'brx': LanguageCapability(
      code: 'brx',
      name: 'Bodo',
      nativeName: 'बड़ो',
      scriptName: 'Devanagari',
      scriptRegex: devanagariRegex,
      googleSpeechLocale: 'brx-IN',
      isGoogleSpeechSupported: false,
      whisperCode: 'hi',
      isMlKitOfflineSupported: false,
      myMemoryCode: 'brx',
      ttsLocale: 'brx-IN',
    ),

    // 4. Dogri
    'doi': LanguageCapability(
      code: 'doi',
      name: 'Dogri',
      nativeName: 'डोगरी',
      scriptName: 'Devanagari',
      scriptRegex: devanagariRegex,
      googleSpeechLocale: 'doi-IN',
      isGoogleSpeechSupported: false,
      whisperCode: 'hi',
      isMlKitOfflineSupported: false,
      myMemoryCode: 'doi',
      ttsLocale: 'doi-IN',
    ),

    // 5. Gujarati
    'gu': LanguageCapability(
      code: 'gu',
      name: 'Gujarati',
      nativeName: 'ગુજરાતી',
      scriptName: 'Gujarati',
      scriptRegex: gujaratiRegex,
      googleSpeechLocale: 'gu-IN',
      isGoogleSpeechSupported: true,
      whisperCode: 'gu',
      isMlKitOfflineSupported: true,
      myMemoryCode: 'gu',
      ttsLocale: 'gu-IN',
    ),

    // 6. Hindi
    'hi': LanguageCapability(
      code: 'hi',
      name: 'Hindi',
      nativeName: 'हिन्दी',
      scriptName: 'Devanagari',
      scriptRegex: devanagariRegex,
      googleSpeechLocale: 'hi-IN',
      isGoogleSpeechSupported: true,
      whisperCode: 'hi',
      isMlKitOfflineSupported: true,
      myMemoryCode: 'hi',
      ttsLocale: 'hi-IN',
    ),

    // 7. Kannada
    'kn': LanguageCapability(
      code: 'kn',
      name: 'Kannada',
      nativeName: 'ಕನ್ನಡ',
      scriptName: 'Kannada',
      scriptRegex: kannadaRegex,
      googleSpeechLocale: 'kn-IN',
      isGoogleSpeechSupported: true,
      whisperCode: 'kn',
      isMlKitOfflineSupported: true,
      myMemoryCode: 'kn',
      ttsLocale: 'kn-IN',
    ),

    // 8. Kashmiri
    'ks': LanguageCapability(
      code: 'ks',
      name: 'Kashmiri',
      nativeName: 'کٲشُر',
      scriptName: 'Perso-Arabic',
      scriptRegex: persoArabicRegex,
      googleSpeechLocale: 'ks-IN',
      isGoogleSpeechSupported: false,
      whisperCode: 'ur',
      isMlKitOfflineSupported: false,
      myMemoryCode: 'ks',
      ttsLocale: 'ks-IN',
    ),

    // 9. Konkani
    'kok': LanguageCapability(
      code: 'kok',
      name: 'Konkani',
      nativeName: 'कोंकणी',
      scriptName: 'Devanagari',
      scriptRegex: devanagariRegex,
      googleSpeechLocale: 'kok-IN',
      isGoogleSpeechSupported: false,
      whisperCode: 'mr',
      isMlKitOfflineSupported: false,
      myMemoryCode: 'kok',
      ttsLocale: 'kok-IN',
    ),

    // 10. Maithili
    'mai': LanguageCapability(
      code: 'mai',
      name: 'Maithili',
      nativeName: 'मैथिली',
      scriptName: 'Devanagari',
      scriptRegex: devanagariRegex,
      googleSpeechLocale: 'mai-IN',
      isGoogleSpeechSupported: false,
      whisperCode: 'hi',
      isMlKitOfflineSupported: false,
      myMemoryCode: 'mai',
      ttsLocale: 'mai-IN',
    ),

    // 11. Malayalam
    'ml': LanguageCapability(
      code: 'ml',
      name: 'Malayalam',
      nativeName: 'മലയാളം',
      scriptName: 'Malayalam',
      scriptRegex: malayalamRegex,
      googleSpeechLocale: 'ml-IN',
      isGoogleSpeechSupported: true,
      whisperCode: 'ml',
      isMlKitOfflineSupported: false,
      myMemoryCode: 'ml',
      ttsLocale: 'ml-IN',
    ),

    // 12. Manipuri
    'mni': LanguageCapability(
      code: 'mni',
      name: 'Manipuri',
      nativeName: 'মৈতৈলোন্',
      scriptName: 'Bengali/Meetei',
      scriptRegex: bengaliAssameseRegex,
      googleSpeechLocale: 'mni-IN',
      isGoogleSpeechSupported: false,
      whisperCode: 'mni',
      isMlKitOfflineSupported: false,
      myMemoryCode: 'mni',
      ttsLocale: 'mni-IN',
    ),

    // 13. Marathi
    'mr': LanguageCapability(
      code: 'mr',
      name: 'Marathi',
      nativeName: 'मराठी',
      scriptName: 'Devanagari',
      scriptRegex: devanagariRegex,
      googleSpeechLocale: 'mr-IN',
      isGoogleSpeechSupported: true,
      whisperCode: 'mr',
      isMlKitOfflineSupported: true,
      myMemoryCode: 'mr',
      ttsLocale: 'mr-IN',
    ),

    // 14. Nepali
    'ne': LanguageCapability(
      code: 'ne',
      name: 'Nepali',
      nativeName: 'नेपाली',
      scriptName: 'Devanagari',
      scriptRegex: devanagariRegex,
      googleSpeechLocale: 'ne-NP',
      isGoogleSpeechSupported: false,
      whisperCode: 'ne',
      isMlKitOfflineSupported: false,
      myMemoryCode: 'ne',
      ttsLocale: 'ne-NP',
    ),

    // 15. Odia
    'or': LanguageCapability(
      code: 'or',
      name: 'Odia',
      nativeName: 'ଓଡ଼ିଆ',
      scriptName: 'Odia',
      scriptRegex: odiaRegex,
      googleSpeechLocale: 'or-IN',
      isGoogleSpeechSupported: false,
      whisperCode: 'or',
      isMlKitOfflineSupported: false,
      myMemoryCode: 'or',
      ttsLocale: 'or-IN',
    ),

    // 16. Punjabi
    'pa': LanguageCapability(
      code: 'pa',
      name: 'Punjabi',
      nativeName: 'ਪੰਜਾਬੀ',
      scriptName: 'Gurmukhi',
      scriptRegex: gurmukhiRegex,
      googleSpeechLocale: 'pa-IN',
      isGoogleSpeechSupported: true,
      whisperCode: 'pa',
      isMlKitOfflineSupported: false,
      myMemoryCode: 'pa',
      ttsLocale: 'pa-IN',
    ),

    // 17. Sanskrit
    'sa': LanguageCapability(
      code: 'sa',
      name: 'Sanskrit',
      nativeName: 'संस्कृतम्',
      scriptName: 'Devanagari',
      scriptRegex: devanagariRegex,
      googleSpeechLocale: 'sa-IN',
      isGoogleSpeechSupported: false,
      whisperCode: 'sa',
      isMlKitOfflineSupported: false,
      myMemoryCode: 'sa',
      ttsLocale: 'sa-IN',
    ),

    // 18. Santali
    'sat': LanguageCapability(
      code: 'sat',
      name: 'Santali',
      nativeName: 'ᱥᱟᱱᱛᱟᱲᱤ',
      scriptName: 'Ol Chiki',
      scriptRegex: olChikiRegex,
      googleSpeechLocale: 'sat-IN',
      isGoogleSpeechSupported: false,
      whisperCode: 'sat',
      isMlKitOfflineSupported: false,
      myMemoryCode: 'sat',
      ttsLocale: 'sat-IN',
    ),

    // 19. Sindhi
    'sd': LanguageCapability(
      code: 'sd',
      name: 'Sindhi',
      nativeName: 'سنڌي',
      scriptName: 'Perso-Arabic',
      scriptRegex: persoArabicRegex,
      googleSpeechLocale: 'sd-IN',
      isGoogleSpeechSupported: false,
      whisperCode: 'sd',
      isMlKitOfflineSupported: false,
      myMemoryCode: 'sd',
      ttsLocale: 'sd-IN',
    ),

    // 20. Tamil
    'ta': LanguageCapability(
      code: 'ta',
      name: 'Tamil',
      nativeName: 'தமிழ்',
      scriptName: 'Tamil',
      scriptRegex: tamilRegex,
      googleSpeechLocale: 'ta-IN',
      isGoogleSpeechSupported: true,
      whisperCode: 'ta',
      isMlKitOfflineSupported: true,
      myMemoryCode: 'ta',
      ttsLocale: 'ta-IN',
    ),

    // 21. Telugu
    'te': LanguageCapability(
      code: 'te',
      name: 'Telugu',
      nativeName: 'తెలుగు',
      scriptName: 'Telugu',
      scriptRegex: teluguRegex,
      googleSpeechLocale: 'te-IN',
      isGoogleSpeechSupported: true,
      whisperCode: 'te',
      isMlKitOfflineSupported: true,
      myMemoryCode: 'te',
      ttsLocale: 'te-IN',
    ),

    // 22. Urdu
    'ur': LanguageCapability(
      code: 'ur',
      name: 'Urdu',
      nativeName: 'اردو',
      scriptName: 'Perso-Arabic',
      scriptRegex: persoArabicRegex,
      googleSpeechLocale: 'ur-IN',
      isGoogleSpeechSupported: true,
      whisperCode: 'ur',
      isMlKitOfflineSupported: true,
      myMemoryCode: 'ur',
      ttsLocale: 'ur-IN',
    ),

    // 23. English
    'en': LanguageCapability(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      scriptName: 'Latin',
      scriptRegex: latinRegex,
      googleSpeechLocale: 'en-IN',
      isGoogleSpeechSupported: true,
      whisperCode: 'en',
      isMlKitOfflineSupported: true,
      myMemoryCode: 'en',
      ttsLocale: 'en-IN',
    ),

    // 24. German
    'de': LanguageCapability(
      code: 'de',
      name: 'German',
      nativeName: 'Deutsch',
      scriptName: 'Latin',
      scriptRegex: latinRegex,
      googleSpeechLocale: 'de-DE',
      isGoogleSpeechSupported: true,
      whisperCode: 'de',
      isMlKitOfflineSupported: true,
      myMemoryCode: 'de',
      ttsLocale: 'de-DE',
    ),
  };

  /// Set of all 24 supported language codes.
  static Set<String> get allLanguageCodes => _capabilities.keys.toSet();

  /// Set of 10 languages supported natively offline by ML Kit translation.
  static Set<String> get mlKitOfflineSupportedCodes => _capabilities.entries
      .where((e) => e.value.isMlKitOfflineSupported)
      .map((e) => e.key)
      .toSet();

  /// Set of 12 languages verified supported by Google Speech Services on Android.
  static Set<String> get googleSpeechSupportedCodes => _capabilities.entries
      .where((e) => e.value.isGoogleSpeechSupported)
      .map((e) => e.key)
      .toSet();

  /// Clean input language code (e.g. '<|te|>' -> 'te', 'en-US' -> 'en').
  static String normalizeCode(String? code) {
    if (code == null) return '';
    final clean = code
        .replaceAll('<|', '')
        .replaceAll('|>', '')
        .trim()
        .toLowerCase();
    if (clean == 'auto' || clean == 'autodetect') return 'auto';
    return clean.split('-').first.split('_').first;
  }

  /// Look up capability for a language code.
  static LanguageCapability? getCapability(String? code) {
    final norm = normalizeCode(code);
    return _capabilities[norm];
  }

  /// Whether a language is part of the 24 supported languages.
  static bool isLanguageSupported(String? code) {
    final norm = normalizeCode(code);
    return _capabilities.containsKey(norm);
  }

  /// Whether both languages in a pair are supported in Online Mode (552 combinations).
  static bool isPairSupportedOnline(String? sourceCode, String? targetCode) {
    final src = normalizeCode(sourceCode);
    final tgt = normalizeCode(targetCode);
    return src != tgt &&
        _capabilities.containsKey(src) &&
        _capabilities.containsKey(tgt);
  }

  /// Whether a pair is supported in Offline Mode via ML Kit (10 * 9 = 90 pairs).
  static bool isPairSupportedOffline(String? sourceCode, String? targetCode) {
    final src = normalizeCode(sourceCode);
    final tgt = normalizeCode(targetCode);
    if (src == tgt) return true;
    final capSrc = _capabilities[src];
    final capTgt = _capabilities[tgt];
    if (capSrc == null || capTgt == null) return false;
    return capSrc.isMlKitOfflineSupported && capTgt.isMlKitOfflineSupported;
  }

  /// Resolve Google SpeechRecognizer locale.
  static String getGoogleSpeechLocale(String? code) {
    final norm = normalizeCode(code);
    return _capabilities[norm]?.googleSpeechLocale ?? 'en-IN';
  }

  /// Resolve Android TTS locale.
  static String getTtsLocale(String? code) {
    final norm = normalizeCode(code);
    return _capabilities[norm]?.ttsLocale ?? 'en-IN';
  }

  /// Resolve Language Name.
  static String getLanguageName(String? code) {
    final norm = normalizeCode(code);
    return _capabilities[norm]?.name ?? (code?.toUpperCase() ?? '');
  }

  /// Total count of product languages (24).
  static int get totalLanguagesCount => _capabilities.length;

  /// Total count of directed language pairs (24 * 23 = 552).
  static int get totalPairsCount =>
      _capabilities.length * (_capabilities.length - 1);
}
