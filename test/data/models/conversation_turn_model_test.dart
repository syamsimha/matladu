import 'package:flutter_test/flutter_test.dart';
import 'package:matladu_ai/data/models/conversation_turn_model.dart';
import 'package:matladu_ai/data/models/language_model.dart';
import 'package:matladu_ai/data/models/tts_result.dart';
import 'package:matladu_ai/data/models/two_way_direction.dart';

void main() {
  group('ConversationTurnModel Tests', () {
    test('Correctly serializes and deserializes JSON', () {
      final turn = ConversationTurnModel(
        id: 'turn_101',
        turnNumber: 1,
        speaker: ConversationSpeaker.speakerA,
        sourceLanguageCode: 'en',
        sourceLanguageName: 'English',
        targetLanguageCode: 'te',
        targetLanguageName: 'Telugu',
        originalText: 'Hello, how are you?',
        translatedText: 'నమస్కారం, మీరు ఎలా ఉన్నారు?',
        state: ConversationTurnState.completed,
        playbackState: TtsPlaybackState.completed,
        timestamp: DateTime(2026, 11, 12, 10, 0, 0),
        confidence: 0.98,
        audioDuration: const Duration(seconds: 2),
      );

      final json = turn.toJson();
      final restored = ConversationTurnModel.fromJson(json);

      expect(restored.id, equals('turn_101'));
      expect(restored.turnNumber, equals(1));
      expect(restored.speaker, equals(ConversationSpeaker.speakerA));
      expect(restored.sourceLanguageCode, equals('en'));
      expect(restored.targetLanguageCode, equals('te'));
      expect(restored.originalText, equals('Hello, how are you?'));
      expect(restored.translatedText, equals('నమస్కారం, మీరు ఎలా ఉన్నారు?'));
      expect(restored.state, equals(ConversationTurnState.completed));
      expect(restored.playbackState, equals(TtsPlaybackState.completed));
      expect(restored.directionLabel, equals('English to Telugu'));
    });

    test('State machine displayName and icon mappings are exhaustive', () {
      for (final state in ConversationTurnState.values) {
        expect(state.displayName, isNotEmpty);
        expect(state.icon, isNotNull);
      }
    });
  });

  group('TwoWayDirectionManager Tests', () {
    const langEn = LanguageModel(code: 'en', name: 'English', nativeName: 'English');
    const langTe = LanguageModel(code: 'te', name: 'Telugu', nativeName: 'తెలుగు');
    const langHi = LanguageModel(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी');

    test('Automatically resolves English -> Telugu when English detected', () {
      final manager = TwoWayDirectionManager(languageA: langEn, languageB: langTe);
      final result = manager.resolve(detectedLanguageCode: 'en');

      expect(result.sourceLanguage.code, equals('en'));
      expect(result.targetLanguage.code, equals('te'));
      expect(result.speaker, equals(ConversationSpeaker.speakerA));
      expect(result.isOutsidePair, isFalse);
    });

    test('Automatically resolves Telugu -> English when Telugu detected', () {
      final manager = TwoWayDirectionManager(languageA: langEn, languageB: langTe);
      final result = manager.resolve(detectedLanguageCode: 'te');

      expect(result.sourceLanguage.code, equals('te'));
      expect(result.targetLanguage.code, equals('en'));
      expect(result.speaker, equals(ConversationSpeaker.speakerB));
      expect(result.isOutsidePair, isFalse);
    });

    test('Flags language outside the pair with helpful warning message', () {
      final manager = TwoWayDirectionManager(languageA: langEn, languageB: langTe);
      final result = manager.resolve(detectedLanguageCode: 'hi');

      expect(result.isOutsidePair, isTrue);
      expect(result.warningMessage, contains('outside the active English to Telugu conversation'));
    });

    test('Manual swap overrides automatic direction until cleared', () {
      final manager = TwoWayDirectionManager(languageA: langEn, languageB: langTe);
      manager.swapDirection(); // Force Te -> En

      final result = manager.resolve(detectedLanguageCode: 'en');
      // With manual override, it honors the forced direction
      expect(result.sourceLanguage.code, equals('te'));
      expect(result.targetLanguage.code, equals('en'));

      manager.clearManualOverride();
      final autoResult = manager.resolve(detectedLanguageCode: 'en');
      expect(autoResult.sourceLanguage.code, equals('en'));
      expect(autoResult.targetLanguage.code, equals('te'));
    });

    test('Supports Hindi ⇄ English pair naturally', () {
      final manager = TwoWayDirectionManager(languageA: langEn, languageB: langHi);
      final r1 = manager.resolve(detectedLanguageCode: 'en');
      expect(r1.sourceLanguage.code, equals('en'));
      expect(r1.targetLanguage.code, equals('hi'));

      final r2 = manager.resolve(detectedLanguageCode: 'hi');
      expect(r2.sourceLanguage.code, equals('hi'));
      expect(r2.targetLanguage.code, equals('en'));
    });
  });
}
