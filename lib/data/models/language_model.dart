/// Represents a supported language in Matladu AI.
class LanguageModel {
  final String code;
  final String name;
  final String nativeName;
  final String category; // 'Popular', 'Indian', 'Others'
  final bool isDownloaded;
  final String packSize;

  const LanguageModel({
    required this.code,
    required this.name,
    required this.nativeName,
    this.category = 'Indian',
    this.isDownloaded = false,
    this.packSize = '30 MB',
  });

  /// Emoji representation of the language's primary national or regional flag.
  String get flagEmoji {
    switch (code) {
      case 'auto':
        return '✨';
      case 'en':
        return '🇬🇧';
      case 'de':
        return '🇩🇪';
      case 'as':
      case 'bn':
      case 'brx':
      case 'doi':
      case 'gu':
      case 'hi':
      case 'kn':
      case 'ks':
      case 'kok':
      case 'mai':
      case 'ml':
      case 'mni':
      case 'mr':
      case 'ne':
      case 'or':
      case 'pa':
      case 'sa':
      case 'sat':
      case 'sd':
      case 'ta':
      case 'te':
      case 'ur':
        return '🇮🇳';
      default:
        return '🌐';
    }
  }

  LanguageModel copyWith({
    String? code,
    String? name,
    String? nativeName,
    String? category,
    bool? isDownloaded,
    String? packSize,
  }) {
    return LanguageModel(
      code: code ?? this.code,
      name: name ?? this.name,
      nativeName: nativeName ?? this.nativeName,
      category: category ?? this.category,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      packSize: packSize ?? this.packSize,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'nativeName': nativeName,
        'category': category,
        'isDownloaded': isDownloaded,
        'packSize': packSize,
      };

  factory LanguageModel.fromJson(Map<String, dynamic> json) {
    return LanguageModel(
      code: json['code'] as String,
      name: json['name'] as String,
      nativeName: json['nativeName'] as String,
      category: json['category'] as String? ?? 'Indian',
      isDownloaded: json['isDownloaded'] as bool? ?? false,
      packSize: json['packSize'] as String? ?? '30 MB',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LanguageModel &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;

  /// Represents automatic language detection (available only for source language).
  static const LanguageModel autoDetect = LanguageModel(
    code: 'auto',
    name: 'Auto Detect',
    nativeName: 'Auto Detect',
    category: 'Popular',
    isDownloaded: true,
    packSize: '',
  );

  /// Looks up a [LanguageModel] by its ISO-639 language code (e.g. 'en', 'te', 'hi').
  static LanguageModel? fromCode(String code) {
    final clean = code.replaceAll('<|', '').replaceAll('|>', '').trim().toLowerCase();
    if (clean == 'auto' || clean == 'autodetect') {
      return autoDetect;
    }
    final first = clean.split('-').first;
    for (final lang in defaultLanguages) {
      if (lang.code.toLowerCase() == clean || lang.code.toLowerCase() == first) {
        return lang;
      }
    }
    return null;
  }

  /// The 24 required product languages:
  /// All 22 languages in India's Eighth Schedule + English + German.
  static const List<LanguageModel> defaultLanguages = [
    // Popular / Global
    LanguageModel(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      category: 'Popular',
      isDownloaded: false,
      packSize: '18 MB',
    ),
    LanguageModel(
      code: 'de',
      name: 'German',
      nativeName: 'Deutsch',
      category: 'Others',
      isDownloaded: false,
      packSize: '36 MB',
    ),

    // 22 Indian Scheduled Languages
    LanguageModel(
      code: 'as',
      name: 'Assamese',
      nativeName: 'অসমীয়া',
      category: 'Indian',
      isDownloaded: false,
      packSize: '28 MB',
    ),
    LanguageModel(
      code: 'bn',
      name: 'Bengali',
      nativeName: 'বাংলা',
      category: 'Indian',
      isDownloaded: false,
      packSize: '28 MB',
    ),
    LanguageModel(
      code: 'brx',
      name: 'Bodo',
      nativeName: 'बड़ो',
      category: 'Indian',
      isDownloaded: false,
      packSize: '28 MB',
    ),
    LanguageModel(
      code: 'doi',
      name: 'Dogri',
      nativeName: 'डोगरी',
      category: 'Indian',
      isDownloaded: false,
      packSize: '28 MB',
    ),
    LanguageModel(
      code: 'gu',
      name: 'Gujarati',
      nativeName: 'ગુજરાતી',
      category: 'Indian',
      isDownloaded: false,
      packSize: '30 MB',
    ),
    LanguageModel(
      code: 'hi',
      name: 'Hindi',
      nativeName: 'हिन्दी',
      category: 'Indian',
      isDownloaded: false,
      packSize: '28 MB',
    ),
    LanguageModel(
      code: 'kn',
      name: 'Kannada',
      nativeName: 'ಕನ್ನಡ',
      category: 'Indian',
      isDownloaded: false,
      packSize: '30 MB',
    ),
    LanguageModel(
      code: 'ks',
      name: 'Kashmiri',
      nativeName: 'کٲشُر',
      category: 'Indian',
      isDownloaded: false,
      packSize: '28 MB',
    ),
    LanguageModel(
      code: 'kok',
      name: 'Konkani',
      nativeName: 'कोंकणी',
      category: 'Indian',
      isDownloaded: false,
      packSize: '28 MB',
    ),
    LanguageModel(
      code: 'mai',
      name: 'Maithili',
      nativeName: 'मैथिली',
      category: 'Indian',
      isDownloaded: false,
      packSize: '28 MB',
    ),
    LanguageModel(
      code: 'ml',
      name: 'Malayalam',
      nativeName: 'മലയാളം',
      category: 'Indian',
      isDownloaded: false,
      packSize: '32 MB',
    ),
    LanguageModel(
      code: 'mni',
      name: 'Manipuri',
      nativeName: 'মৈতৈলোন্',
      category: 'Indian',
      isDownloaded: false,
      packSize: '28 MB',
    ),
    LanguageModel(
      code: 'mr',
      name: 'Marathi',
      nativeName: 'मराठी',
      category: 'Indian',
      isDownloaded: false,
      packSize: '28 MB',
    ),
    LanguageModel(
      code: 'ne',
      name: 'Nepali',
      nativeName: 'नेपाली',
      category: 'Indian',
      isDownloaded: false,
      packSize: '28 MB',
    ),
    LanguageModel(
      code: 'or',
      name: 'Odia',
      nativeName: 'ଓଡ଼ିଆ',
      category: 'Indian',
      isDownloaded: false,
      packSize: '30 MB',
    ),
    LanguageModel(
      code: 'pa',
      name: 'Punjabi',
      nativeName: 'ਪੰਜਾਬੀ',
      category: 'Indian',
      isDownloaded: false,
      packSize: '30 MB',
    ),
    LanguageModel(
      code: 'sa',
      name: 'Sanskrit',
      nativeName: 'संस्कृतम्',
      category: 'Indian',
      isDownloaded: false,
      packSize: '28 MB',
    ),
    LanguageModel(
      code: 'sat',
      name: 'Santali',
      nativeName: 'ᱥᱟᱱᱛᱟᱲᱤ',
      category: 'Indian',
      isDownloaded: false,
      packSize: '28 MB',
    ),
    LanguageModel(
      code: 'sd',
      name: 'Sindhi',
      nativeName: 'سنڌي',
      category: 'Indian',
      isDownloaded: false,
      packSize: '28 MB',
    ),
    LanguageModel(
      code: 'ta',
      name: 'Tamil',
      nativeName: 'தமிழ்',
      category: 'Indian',
      isDownloaded: false,
      packSize: '30 MB',
    ),
    LanguageModel(
      code: 'te',
      name: 'Telugu',
      nativeName: 'తెలుగు',
      category: 'Indian',
      isDownloaded: false,
      packSize: '25 MB',
    ),
    LanguageModel(
      code: 'ur',
      name: 'Urdu',
      nativeName: 'اردو',
      category: 'Indian',
      isDownloaded: false,
      packSize: '30 MB',
    ),
  ];
}
