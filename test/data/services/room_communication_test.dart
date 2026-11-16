import 'package:flutter_test/flutter_test.dart';
import 'package:matladu_ai/data/models/conversation_turn_model.dart';
import 'package:matladu_ai/data/models/room_model.dart';
import 'package:matladu_ai/data/services/room/room_communication_service.dart';

void main() {
  group('Room Communication Architecture Tests', () {
    test('Generates valid MTL-XXXX or MTL-XXXXXX room code format', () {
      final code = RoomModel.generateRoomCode();
      expect(code.startsWith('MTL-'), isTrue);
      expect(code.length == 8 || code.length == 10, isTrue);
      expect(RoomModel.isValidCode(code), isTrue);
    });

    test('Rejects malformed room codes', () {
      expect(RoomModel.isValidCode('MTL-12'), isFalse);
      expect(RoomModel.isValidCode('ABC-1234'), isFalse);
      expect(RoomModel.isValidCode(''), isFalse);
      expect(RoomModel.isValidCode('MTL-12345'), isFalse);
    });

    test('Creates room successfully with host client', () async {
      final serviceA = RoomCommunicationService(clientId: 'client-A');
      final room = await serviceA.createRoom(
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );

      expect(room.hostClientId, equals('client-A'));
      expect(room.isWaiting, isTrue);
      expect(serviceA.currentRoom?.roomId, equals(room.roomId));
      expect(room.sourceLanguageCode, equals('en'));
      expect(room.targetLanguageCode, equals('te'));
    });

    test('Peer can join active room and synchronize state', () async {
      final serviceHost = RoomCommunicationService(clientId: 'host-1');
      final servicePeer = RoomCommunicationService(clientId: 'peer-2');

      final createdRoom = await serviceHost.createRoom(
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );

      final joinedRoom = await servicePeer.joinRoom(createdRoom.roomCode);

      expect(joinedRoom, isNotNull);
      expect(joinedRoom.connectionState, equals(RoomConnectionState.connected));
      expect(joinedRoom.peerClientId, equals('peer-2'));
      expect(joinedRoom.isConnected, isTrue);
    });

    test('Join fails with informative error on non-existent room', () async {
      final servicePeer = RoomCommunicationService(clientId: 'peer-test');
      final room = await servicePeer.joinRoom('MTL-9999');
      expect(room.state, equals(RoomConnectionState.error));
      expect(room.errorMessage, isNotNull);
    });

    test('Join fails on malformed room code format', () async {
      final servicePeer = RoomCommunicationService(clientId: 'peer-test');
      final room = await servicePeer.joinRoom('INVALID');
      expect(room.state, equals(RoomConnectionState.error));
      expect(room.errorMessage, contains('Invalid room code'));
    });

    test('Synchronizes conversation turns across peers', () async {
      final serviceHost = RoomCommunicationService(clientId: 'host-sync');
      final servicePeer = RoomCommunicationService(clientId: 'peer-sync');

      final room = await serviceHost.createRoom(
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );
      await servicePeer.joinRoom(room.roomCode);

      final turnReceivedFuture = servicePeer.messageStream
          .firstWhere((msg) => msg.type == RoomMessageType.turn);

      final testTurn = ConversationTurnModel(
        id: 'turn-101',
        turnNumber: 1,
        speaker: ConversationSpeaker.speakerA,
        sourceLanguageCode: 'en',
        sourceLanguageName: 'English',
        targetLanguageCode: 'te',
        targetLanguageName: 'Telugu',
        originalText: 'Hello, how are you?',
        translatedText: 'నమస్కారం, మీరు ఎలా ఉన్నారు?',
        state: ConversationTurnState.completed,
        timestamp: DateTime.now(),
      );

      await serviceHost.sendTurn(testTurn);

      final receivedMsg = await turnReceivedFuture;
      expect(receivedMsg.payload, isNotNull);
      final receivedTurn = ConversationTurnModel.fromJson(receivedMsg.payload!);
      expect(receivedTurn.id, equals('turn-101'));
      expect(receivedTurn.originalText, equals('Hello, how are you?'));
      expect(receivedTurn.translatedText, equals('నమస్కారం, మీరు ఎలా ఉన్నారు?'));
    });

    test('Leaves room and resets state', () async {
      final service = RoomCommunicationService(clientId: 'host-leave');
      final room = await service.createRoom(
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );
      expect(room.roomCode.isNotEmpty, isTrue);
      expect(service.currentRoom, isNotNull);

      await service.leaveRoom();
      expect(service.currentRoom, isNull);
    });
  });
}
