/// Represents an individual translation message or record
class TranslationItemModel {
  final String id;
  final String sourceText;
  final String translatedText;
  final String sourceLanguageCode;
  final String targetLanguageCode;
  final DateTime timestamp;
  final bool isFavorite;

  const TranslationItemModel({
    required this.id,
    required this.sourceText,
    required this.translatedText,
    required this.sourceLanguageCode,
    required this.targetLanguageCode,
    required this.timestamp,
    this.isFavorite = false,
  });

  TranslationItemModel copyWith({
    String? id,
    String? sourceText,
    String? translatedText,
    String? sourceLanguageCode,
    String? targetLanguageCode,
    DateTime? timestamp,
    bool? isFavorite,
  }) {
    return TranslationItemModel(
      id: id ?? this.id,
      sourceText: sourceText ?? this.sourceText,
      translatedText: translatedText ?? this.translatedText,
      sourceLanguageCode: sourceLanguageCode ?? this.sourceLanguageCode,
      targetLanguageCode: targetLanguageCode ?? this.targetLanguageCode,
      timestamp: timestamp ?? this.timestamp,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceText': sourceText,
        'translatedText': translatedText,
        'sourceLanguageCode': sourceLanguageCode,
        'targetLanguageCode': targetLanguageCode,
        'timestamp': timestamp.toIso8601String(),
        'isFavorite': isFavorite,
      };

  factory TranslationItemModel.fromJson(Map<String, dynamic> json) {
    return TranslationItemModel(
      id: json['id'] as String,
      sourceText: json['sourceText'] as String,
      translatedText: json['translatedText'] as String,
      sourceLanguageCode: json['sourceLanguageCode'] as String,
      targetLanguageCode: json['targetLanguageCode'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }
}

