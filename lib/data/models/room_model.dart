import 'dart:convert';
import 'dart:math';

/// Status lifecycle for a two-phone conversation room.
enum RoomConnectionState {
  initial,
  created,
  connecting,
  waitingForPeer,
  connected,
  disconnected,
  closed,
  error,
}

/// Message types passed across room communication channel.
enum RoomMessageType {
  join,
  turn,
  leave,
  error,
  status,
}

/// Exception thrown for room creation, code validation, or joining errors.
class RoomException implements Exception {
  final String message;
  const RoomException(this.message);

  @override
  String toString() => 'RoomException: $message';
}

/// Represents an active or pending conversation room for two participants.
class RoomModel {
  final String roomId;
  final String hostId;
  final String? peerId;
  final RoomConnectionState state;
  final String sourceLanguageCode;
  final String targetLanguageCode;
  final DateTime createdAt;
  final bool isOnline;
  final String? errorMessage;

  const RoomModel({
    required this.roomId,
    required this.hostId,
    this.peerId,
    required this.state,
    required this.sourceLanguageCode,
    required this.targetLanguageCode,
    required this.createdAt,
    this.isOnline = true,
    this.errorMessage,
  });

  String get roomCode => roomId;
  String get hostClientId => hostId;
  String? get peerClientId => peerId;
  RoomConnectionState get connectionState => state;

  bool get isConnected => state == RoomConnectionState.connected;
  bool get isWaiting =>
      state == RoomConnectionState.waitingForPeer || state == RoomConnectionState.created;
  bool get hasPeer => peerId != null && peerId!.isNotEmpty;

  static String generateRoomCode() {
    final rand = Random.secure();
    const alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    final sb = StringBuffer('MTL-');
    for (int i = 0; i < 6; i++) {
      sb.write(alphabet[rand.nextInt(alphabet.length)]);
    }
    return sb.toString();
  }

  static bool isValidCode(String code) {
    final clean = code.trim().toUpperCase();
    // Accepts cryptographically secure 6-char codes (MTL-XXXXXX) or legacy 4-digit (MTL-XXXX)
    final reg = RegExp(r'^MTL-(\d{4}|[A-Z0-9]{6})$');
    return reg.hasMatch(clean);
  }

  RoomModel copyWith({
    String? roomId,
    String? hostId,
    String? peerId,
    RoomConnectionState? state,
    String? sourceLanguageCode,
    String? targetLanguageCode,
    DateTime? createdAt,
    bool? isOnline,
    String? errorMessage,
  }) {
    return RoomModel(
      roomId: roomId ?? this.roomId,
      hostId: hostId ?? this.hostId,
      peerId: peerId ?? this.peerId,
      state: state ?? this.state,
      sourceLanguageCode: sourceLanguageCode ?? this.sourceLanguageCode,
      targetLanguageCode: targetLanguageCode ?? this.targetLanguageCode,
      createdAt: createdAt ?? this.createdAt,
      isOnline: isOnline ?? this.isOnline,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toJson() => {
        'roomId': roomId,
        'hostId': hostId,
        'peerId': peerId,
        'state': state.name,
        'sourceLanguageCode': sourceLanguageCode,
        'targetLanguageCode': targetLanguageCode,
        'createdAt': createdAt.toIso8601String(),
        'isOnline': isOnline,
        'errorMessage': errorMessage,
      };

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      roomId: json['roomId'] as String? ?? '',
      hostId: json['hostId'] as String? ?? '',
      peerId: json['peerId'] as String?,
      state: RoomConnectionState.values.firstWhere(
        (e) => e.name == json['state'],
        orElse: () => RoomConnectionState.initial,
      ),
      sourceLanguageCode: json['sourceLanguageCode'] as String? ?? 'en',
      targetLanguageCode: json['targetLanguageCode'] as String? ?? 'te',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isOnline: json['isOnline'] as bool? ?? true,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  @override
  String toString() =>
      'RoomModel(id: $roomId, state: ${state.name}, peer: $peerId, pair: $sourceLanguageCode to $targetLanguageCode)';
}

/// Represents a synchronized turn message exchanged between room participants.
class RoomMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String speakerName;
  final String originalText;
  final String translatedText;
  final String sourceLanguageCode;
  final String targetLanguageCode;
  final DateTime timestamp;
  final RoomMessageType type;
  final Map<String, dynamic>? payload;

  const RoomMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.speakerName,
    required this.originalText,
    required this.translatedText,
    required this.sourceLanguageCode,
    required this.targetLanguageCode,
    required this.timestamp,
    this.type = RoomMessageType.turn,
    this.payload,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'roomId': roomId,
        'senderId': senderId,
        'speakerName': speakerName,
        'originalText': originalText,
        'translatedText': translatedText,
        'sourceLanguageCode': sourceLanguageCode,
        'targetLanguageCode': targetLanguageCode,
        'timestamp': timestamp.toIso8601String(),
        'type': type.name,
        if (payload != null) 'payload': payload,
      };

  factory RoomMessage.fromJson(Map<String, dynamic> json) {
    return RoomMessage(
      id: json['id'] as String? ?? '',
      roomId: json['roomId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      speakerName: json['speakerName'] as String? ?? 'Speaker',
      originalText: json['originalText'] as String? ?? '',
      translatedText: json['translatedText'] as String? ?? '',
      sourceLanguageCode: json['sourceLanguageCode'] as String? ?? 'en',
      targetLanguageCode: json['targetLanguageCode'] as String? ?? 'te',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      type: RoomMessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => RoomMessageType.turn,
      ),
      payload: json['payload'] as Map<String, dynamic>?,
    );
  }

  String toEncodedString() => jsonEncode(toJson());
}
