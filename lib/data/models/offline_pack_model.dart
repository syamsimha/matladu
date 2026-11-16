/// State lifecycle for an offline downloadable pack.
enum PackInstallState {
  notDownloaded,
  downloading,
  paused,
  installing,
  verifying,
  installedAndReady,
  deleting,
  deleted,
  corrupted,
  failed,
  updateAvailable,
}

/// Represents an offline language pack or speech recognition model package.
class OfflinePackModel {
  final String id;
  final String languageName;
  final String languageCode;
  final String flagEmoji;
  final int sizeInMB;
  final String modelType;
  final PackInstallState installState;
  final int downloadedBytes;
  final int totalBytes;
  final double? installedSizeMB;
  final String? errorMessage;

  const OfflinePackModel({
    required this.id,
    required this.languageName,
    required this.languageCode,
    required this.flagEmoji,
    required this.sizeInMB,
    this.modelType = 'Neural Translation',
    this.installState = PackInstallState.notDownloaded,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.installedSizeMB,
    this.errorMessage,
    bool isDownloaded = false,
    bool isDownloading = false,
    double downloadProgress = 0.0,
  });

  /// Backward-compatible getters
  bool get isDownloaded => installState == PackInstallState.installedAndReady;
  bool get isDownloading => installState == PackInstallState.downloading;
  bool get isReady => installState == PackInstallState.installedAndReady;
  bool get isFailed =>
      installState == PackInstallState.failed || installState == PackInstallState.corrupted;

  double get downloadProgress {
    if (isDownloaded) return 1.0;
    if (totalBytes > 0) return (downloadedBytes / totalBytes).clamp(0.0, 1.0);
    return 0.0;
  }

  int get progressPercent => (downloadProgress * 100).round().clamp(0, 100);

  String get byteProgressText {
    if (downloadProgress <= 0.0) {
      return 'Downloading model (~$sizeInMB MB)...';
    }
    final downMB = (downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
    final totMB = totalBytes > 0
        ? (totalBytes / (1024 * 1024)).toStringAsFixed(1)
        : sizeInMB.toString();
    return '$downMB / $totMB MB ($progressPercent%)';
  }

  String get stateBadgeLabel {
    switch (installState) {
      case PackInstallState.notDownloaded:
        return 'Not Downloaded';
      case PackInstallState.downloading:
        return progressPercent > 0 ? 'Downloading $progressPercent%' : 'Downloading...';
      case PackInstallState.paused:
        return 'Paused / Interrupted';
      case PackInstallState.installing:
        return 'Installing...';
      case PackInstallState.verifying:
        return 'Verifying Installation...';
      case PackInstallState.installedAndReady:
        return 'Installed & Verified';
      case PackInstallState.deleting:
        return 'Deleting...';
      case PackInstallState.deleted:
        return 'Deleted';
      case PackInstallState.corrupted:
        return 'Corrupted / Incomplete';
      case PackInstallState.failed:
        return 'Download Failed';
      case PackInstallState.updateAvailable:
        return 'Update Available';
    }
  }

  OfflinePackModel copyWith({
    String? id,
    String? languageName,
    String? languageCode,
    String? flagEmoji,
    int? sizeInMB,
    String? modelType,
    PackInstallState? installState,
    int? downloadedBytes,
    int? totalBytes,
    double? installedSizeMB,
    String? errorMessage,
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
      modelType: modelType ?? this.modelType,
      installState: installState ??
          (isDownloaded != null
              ? (isDownloaded ? PackInstallState.installedAndReady : PackInstallState.notDownloaded)
              : (isDownloading != null && isDownloading
                  ? PackInstallState.downloading
                  : this.installState)),
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      installedSizeMB: installedSizeMB ?? this.installedSizeMB,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'languageName': languageName,
        'languageCode': languageCode,
        'flagEmoji': flagEmoji,
        'sizeInMB': sizeInMB,
        'modelType': modelType,
        'installState': installState.name,
        'downloadedBytes': downloadedBytes,
        'totalBytes': totalBytes,
        'installedSizeMB': installedSizeMB,
        'isDownloaded': isDownloaded,
        'isDownloading': isDownloading,
        'downloadProgress': downloadProgress,
      };

  factory OfflinePackModel.fromJson(Map<String, dynamic> json) {
    final stateStr = json['installState'] as String?;
    final isDown = json['isDownloaded'] as bool? ?? false;
    final state = stateStr != null
        ? PackInstallState.values.firstWhere(
            (e) => e.name == stateStr,
            orElse: () => isDown ? PackInstallState.installedAndReady : PackInstallState.notDownloaded,
          )
        : (isDown ? PackInstallState.installedAndReady : PackInstallState.notDownloaded);

    return OfflinePackModel(
      id: json['id'] as String,
      languageName: json['languageName'] as String,
      languageCode: json['languageCode'] as String,
      flagEmoji: json['flagEmoji'] as String? ?? '🌐',
      sizeInMB: json['sizeInMB'] as int? ?? 25,
      modelType: json['modelType'] as String? ?? 'Neural Translation',
      installState: state,
      downloadedBytes: json['downloadedBytes'] as int? ?? (isDown ? (json['sizeInMB'] as int? ?? 25) * 1024 * 1024 : 0),
      totalBytes: json['totalBytes'] as int? ?? (json['sizeInMB'] as int? ?? 25) * 1024 * 1024,
      installedSizeMB: (json['installedSizeMB'] as num?)?.toDouble(),
      errorMessage: json['errorMessage'] as String?,
    );
  }
}
