import '../../models/conversation_turn_model.dart';
import '../../models/room_model.dart';

/// Contract defining real two-phone conversation room synchronization.
abstract class IRoomService {
  /// Unique client session ID for this phone instance.
  String get clientId;

  /// The active room model, or null if not currently in a room.
  RoomModel? get currentRoom;

  /// Whether the phone is currently in an active conversation room.
  bool get isInRoom;

  /// Reactive stream of room status updates (waiting, peer connected, disconnected).
  Stream<RoomModel> get roomStream;

  /// Reactive stream of incoming speech and translation messages from the peer phone.
  Stream<RoomMessage> get messageStream;

  /// Creates a new conversation room with a unique room code.
  Future<RoomModel> createRoom({
    required String sourceLanguageCode,
    required String targetLanguageCode,
  });

  /// Joins an existing conversation room using a validated room code.
  Future<RoomModel> joinRoom(String roomCode);

  /// Leaves and closes the current conversation room session.
  Future<void> leaveRoom();

  /// Synchronizes a completed conversation turn with the peer phone.
  Future<bool> sendTurn(ConversationTurnModel turn);

  /// Disposes resources, streams, and active connections.
  void dispose();
}
