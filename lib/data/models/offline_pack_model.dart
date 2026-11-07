/// Represents an offline language pack package
class OfflinePackModel {
  final String id;
  final String languageName;
  final String languageCode;
  final String flagEmoji;
  final int sizeInMB;
  final bool isDownloaded;
  final bool isDownloading;
  final double downloadProgress; // 0.0 to 1.0

  const OfflinePackModel({
    required this.id,
    required this.languageName,
    required this.languageCode,
    required this.flagEmoji,
    required this.sizeInMB,
    this.isDownloaded = false,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
  });

  OfflinePackModel copyWith({
    String? id,
    String? languageName,
    String? languageCode,
    String? flagEmoji,
    int? sizeInMB,
    bool? isDownloaded,
    bool? isDownloading,
    double? downloadProgress,
  }) {
    return OfflinePackModel(
      id: id ?? this.id,
      languageName: languageName ?? this.languageName,
      languageCode: languageCode ?? this.languageCode,
      flagEmoji: flagEmoji ?? this.flagEmoji,
      sizeInMB: sizeInMB ?? this.sizeInMB,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'languageName': languageName,
        'languageCode': languageCode,
        'flagEmoji': flagEmoji,
        'sizeInMB': sizeInMB,
        'isDownloaded': isDownloaded,
      };

  factory OfflinePackModel.fromJson(Map<String, dynamic> json) {
    return OfflinePackModel(
      id: json['id'] as String,
      languageName: json['languageName'] as String,
      languageCode: json['languageCode'] as String,
      flagEmoji: json['flagEmoji'] as String,
      sizeInMB: json['sizeInMB'] as int,
      isDownloaded: json['isDownloaded'] as bool? ?? false,
    );
  }
}

