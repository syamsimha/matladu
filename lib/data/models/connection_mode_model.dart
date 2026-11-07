/// Supported networking and inference modes for Matladu AI
enum ConnectionModeType {
  cloudAi,
  onDevice,
  peerToPeer,
}

class ConnectionModeModel {
  final ConnectionModeType type;
  final String title;
  final String subtitle;
  final String latencyBadge;
  final String privacyBadge;
  final bool isRecommended;

  const ConnectionModeModel({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.latencyBadge,
    required this.privacyBadge,
    this.isRecommended = false,
  });

  static const List<ConnectionModeModel> availableModes = [
    ConnectionModeModel(
      type: ConnectionModeType.cloudAi,
      title: 'Cloud AI Mode',
      subtitle: 'Highest accuracy using cloud neural translation models. Requires internet.',
      latencyBadge: 'Ultra Accurate (120ms)',
      privacyBadge: 'TLS Encrypted',
      isRecommended: true,
    ),
    ConnectionModeModel(
      type: ConnectionModeType.onDevice,
      title: 'Local On-Device Mode',
      subtitle: 'Runs entirely on local neural engine. Zero internet needed, 100% private.',
      latencyBadge: 'Instant (45ms)',
      privacyBadge: 'Zero Cloud Data',
    ),
    ConnectionModeModel(
      type: ConnectionModeType.peerToPeer,
      title: 'P2P Offline Hotspot',
      subtitle: 'Direct local device mesh via Wi-Fi Direct or Bluetooth for two-way live translation.',
      latencyBadge: 'Direct Local',
      privacyBadge: 'Direct Device Mesh',
    ),
  ];
}

