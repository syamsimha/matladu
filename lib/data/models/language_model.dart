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

  /// Default catalogue exactly matching Screen 4 and Screen 5
  static const List<LanguageModel> defaultLanguages = [
    LanguageModel(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      category: 'Popular',
      isDownloaded: true,
      packSize: '20 MB',
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
      code: 'hi',
      name: 'Hindi',
      nativeName: 'हिन्दी',
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
      code: 'kn',
      name: 'Kannada',
      nativeName: 'ಕನ್ನಡ',
      category: 'Indian',
      isDownloaded: false,
      packSize: '30 MB',
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
      code: 'bn',
      name: 'Bengali',
      nativeName: 'বাংলা',
      category: 'Indian',
      isDownloaded: false,
      packSize: '28 MB',
    ),
    LanguageModel(
      code: 'es',
      name: 'Spanish',
      nativeName: 'Español',
      category: 'Popular',
      isDownloaded: false,
      packSize: '35 MB',
    ),
    LanguageModel(
      code: 'fr',
      name: 'French',
      nativeName: 'Français',
      category: 'Others',
      isDownloaded: false,
      packSize: '34 MB',
    ),
    LanguageModel(
      code: 'de',
      name: 'German',
      nativeName: 'Deutsch',
      category: 'Others',
      isDownloaded: false,
      packSize: '36 MB',
    ),
  ];
}
