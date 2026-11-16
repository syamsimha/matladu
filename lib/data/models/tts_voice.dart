/// Representation of a Text-to-Speech voice on Android.
/// Strictly enforces and inspects offline capability (`isNetworkRequired == false`).
class TtsVoice {
  final String name;
  final String locale;
  final String languageCode;
  final bool isNetworkRequired;
  final int? quality;
  final int? latency;
  final List<String> features;

  const TtsVoice({
    required this.name,
    required this.locale,
    required this.languageCode,
    this.isNetworkRequired = false,
    this.quality,
    this.latency,
    this.features = const [],
  });

  /// 100% Offline verification: Voice does not require network synthesis.
  bool get isOfflineAvailable => !isNetworkRequired;

  /// Human-friendly display label for settings and voice picker.
  String get displayName {
    final cleanName = name.replaceAll(RegExp(r'#.*$'), '');
    final offlineTag = isOfflineAvailable ? 'Offline' : 'Network Required';
    return '$cleanName ($locale) - $offlineTag';
  }

  factory TtsVoice.fromMap(Map<dynamic, dynamic> map) {
    final name = map['name']?.toString() ?? '';
    final locale = map['locale']?.toString() ?? '';
    final networkReqRaw = map['network_required'];
    final bool networkReq = (networkReqRaw == true ||
        networkReqRaw?.toString().toLowerCase() == 'true');

    // Extract base language code from locale (e.g., 'te-IN' -> 'te', 'hi_IN' -> 'hi')
    String langCode = 'en';
    if (locale.isNotEmpty) {
      final parts = locale.replaceAll('_', '-').split('-');
      if (parts.isNotEmpty) {
        langCode = parts.first.toLowerCase();
      }
    } else if (name.isNotEmpty) {
      final parts = name.split('-');
      if (parts.isNotEmpty) {
        langCode = parts.first.toLowerCase();
      }
    }

    final featuresList = <String>[];
    if (map['features'] is List) {
      for (final f in (map['features'] as List)) {
        if (f != null) featuresList.add(f.toString());
      }
    }

    return TtsVoice(
      name: name,
      locale: locale,
      languageCode: langCode,
      isNetworkRequired: networkReq,
      quality: map['quality'] is int ? map['quality'] as int : null,
      latency: map['latency'] is int ? map['latency'] as int : null,
      features: featuresList,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'locale': locale,
        'languageCode': languageCode,
        'isNetworkRequired': isNetworkRequired,
        'quality': quality,
        'latency': latency,
        'features': features,
      };

  @override
  String toString() => 'TtsVoice($name, $locale, offline: $isOfflineAvailable)';
}

