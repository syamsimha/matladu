/// Supported networking and inference modes for Matladu
enum ConnectionModeType {
  cloudAi,
  onDevice,
  automatic,
  peerToPeer,
}

class ConnectionModeModel {
  final ConnectionModeType type;
  final String title;
  final String subtitle;
  final String latencyBadge;
  final String privacyBadge;
  final bool isRecommended;

  ConnectionModeType get mode => type;

  const ConnectionModeModel({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.latencyBadge,
    required this.privacyBadge,
    this.isRecommended = false,
  });

  static ConnectionModeModel fromType(ConnectionModeType type) {
    return availableModes.firstWhere(
      (m) => m.type == type,
      orElse: () => availableModes.first,
    );
  }

  static const List<ConnectionModeModel> availableModes = [
    ConnectionModeModel(
      type: ConnectionModeType.automatic,
      title: 'Automatic Mode',
      subtitle: 'Intelligently uses online translation when connected, and switches to on-device translation when offline.',
      latencyBadge: 'Smart Adaptive',
      privacyBadge: 'Speech & Audio Local',
      isRecommended: true,
    ),
    ConnectionModeModel(
      type: ConnectionModeType.cloudAi,
      title: 'Online Mode',
      subtitle: 'External internet translation API. Speech recognition and TTS remain 100% on-device. No pack download required.',
      latencyBadge: 'Fast Cloud API',
      privacyBadge: 'Text Only - Zero Audio Upload',
      isRecommended: false,
    ),
    ConnectionModeModel(
      type: ConnectionModeType.onDevice,
      title: 'Offline Mode',
      subtitle: '100% on-device speech recognition, neural translation, and TTS. Zero internet required.',
      latencyBadge: 'On-Device Neural',
      privacyBadge: 'Zero Data Leaves Device',
      isRecommended: false,
    ),
    ConnectionModeModel(
      type: ConnectionModeType.peerToPeer,
      title: 'P2P Offline Hotspot',
      subtitle: 'Direct local device mesh via Wi-Fi Direct or Bluetooth for two-way live coordination.',
      latencyBadge: 'Direct Local',
      privacyBadge: 'Direct Device Mesh',
      isRecommended: false,
    ),
  ];
}
