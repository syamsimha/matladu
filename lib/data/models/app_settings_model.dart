/// User preferences and application configuration model
class AppSettingsModel {
  final bool autoDetectLanguage;
  final bool autoPlayAudio;
  final bool hapticFeedback;
  final bool noiseSuppression;
  final double speechSpeed; // 0.5x to 2.0x
  final String speechPitch; // 'Normal', 'Low', 'High'

  const AppSettingsModel({
    this.autoDetectLanguage = true,
    this.autoPlayAudio = true,
    this.hapticFeedback = true,
    this.noiseSuppression = true,
    this.speechSpeed = 1.0,
    this.speechPitch = 'Normal',
  });

  AppSettingsModel copyWith({
    bool? autoDetectLanguage,
    bool? autoPlayAudio,
    bool? hapticFeedback,
    bool? noiseSuppression,
    double? speechSpeed,
    String? speechPitch,
  }) {
    return AppSettingsModel(
      autoDetectLanguage: autoDetectLanguage ?? this.autoDetectLanguage,
      autoPlayAudio: autoPlayAudio ?? this.autoPlayAudio,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      noiseSuppression: noiseSuppression ?? this.noiseSuppression,
      speechSpeed: speechSpeed ?? this.speechSpeed,
      speechPitch: speechPitch ?? this.speechPitch,
    );
  }

  Map<String, dynamic> toJson() => {
        'autoDetectLanguage': autoDetectLanguage,
        'autoPlayAudio': autoPlayAudio,
        'hapticFeedback': hapticFeedback,
        'noiseSuppression': noiseSuppression,
        'speechSpeed': speechSpeed,
        'speechPitch': speechPitch,
      };

  factory AppSettingsModel.fromJson(Map<String, dynamic> json) {
    return AppSettingsModel(
      autoDetectLanguage: json['autoDetectLanguage'] as bool? ?? true,
      autoPlayAudio: json['autoPlayAudio'] as bool? ?? true,
      hapticFeedback: json['hapticFeedback'] as bool? ?? true,
      noiseSuppression: json['noiseSuppression'] as bool? ?? true,
      speechSpeed: (json['speechSpeed'] as num?)?.toDouble() ?? 1.0,
      speechPitch: json['speechPitch'] as String? ?? 'Normal',
    );
  }
}

