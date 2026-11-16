import 'package:flutter_test/flutter_test.dart';
import 'package:matladu_ai/data/models/conversation_turn_model.dart';
import 'package:matladu_ai/data/models/language_model.dart';
import 'package:matladu_ai/data/models/two_way_direction.dart';

void main() {
  group('TwoWayDirectionManager Tests', () {
    late TwoWayDirectionManager manager;
    const english = LanguageModel(code: 'en', name: 'English', nativeName: 'English');
    const telugu = LanguageModel(code: 'te', name: 'Telugu', nativeName: 'తెలుగు');

    setUp(() {
      manager = TwoWayDirectionManager(
        languageA: english,
        languageB: telugu,
      );
    });

    test('Initial state: prefers Language A to B', () {
      expect(manager.languageA.code, equals('en'));
      expect(manager.languageB.code, equals('te'));
      expect(manager.preferAtoB, isTrue);
      expect(manager.manualOverride, isFalse);
    });

    test('Turn 1: Person A speaks English -> resolves to English -> Telugu with Speaker 1', () {
      final result = manager.resolve(detectedLanguageCode: 'en');

      expect(result.sourceLanguage.code, equals('en'));
      expect(result.targetLanguage.code, equals('te'));
      expect(result.speaker, equals(ConversationSpeaker.speakerA));
      expect(result.canTranslate, isTrue);
      expect(result.isOutsidePair, isFalse);
      expect(result.isUncertain, isFalse);
      expect(result.warningMessage, isNull);
      expect(manager.preferAtoB, isFalse); // Next turn expects B
    });

    test('Turn 2: Person B responds in Telugu -> resolves to Telugu -> English with Speaker 2', () {
      // First turn A -> B
      manager.resolve(detectedLanguageCode: 'en');

      // Second turn B -> A
      final result = manager.resolve(detectedLanguageCode: 'te');

      expect(result.sourceLanguage.code, equals('te'));
      expect(result.targetLanguage.code, equals('en'));
      expect(result.speaker, equals(ConversationSpeaker.speakerB));
      expect(result.canTranslate, isTrue);
      expect(result.isOutsidePair, isFalse);
      expect(result.isUncertain, isFalse);
      expect(result.warningMessage, isNull);
      expect(manager.preferAtoB, isTrue); // Next turn expects A
    });

    test('Third-language detection: Hindi detected when pair is English to Telugu', () {
      final result = manager.resolve(detectedLanguageCode: 'hi');

      // Must NOT silently default to Language B
      expect(result.isOutsidePair, isTrue);
      expect(result.canTranslate, isFalse,
          reason: 'Must not generate potentially incorrect translation automatically');
      expect(result.warningMessage, contains('Detected Hindi'));
      expect(result.warningMessage, contains('English to Telugu'));

      // Active pair must be preserved
      expect(result.sourceLanguage.code, equals('en'));
      expect(result.targetLanguage.code, equals('te'));
    });

    test('Uncertain language detection: empty code or "und"', () {
      final resultUnd = manager.resolve(detectedLanguageCode: 'und');
      expect(resultUnd.isUncertain, isTrue);
      expect(resultUnd.canTranslate, isFalse);
      expect(resultUnd.warningMessage, contains('could not be determined with confidence'));
      expect(resultUnd.sourceLanguage.code, equals('en'));
      expect(resultUnd.targetLanguage.code, equals('te'));

      final resultEmpty = manager.resolve(detectedLanguageCode: '');
      expect(resultEmpty.isUncertain, isTrue);
      expect(resultEmpty.canTranslate, isFalse);

      final resultAuto = manager.resolve(detectedLanguageCode: 'auto');
      expect(resultAuto.isUncertain, isTrue);
      expect(resultAuto.canTranslate, isFalse);
    });

    test('Uncertain language detection: low confidence (< 0.35)', () {
      final result = manager.resolve(
        detectedLanguageCode: 'en',
        confidence: 0.20,
      );

      expect(result.isUncertain, isTrue);
      expect(result.canTranslate, isFalse);
      expect(result.warningMessage, isNotNull);
    });

    test('Manual swapDirection reverses direction and sets manual override', () {
      manager.swapDirection();
      expect(manager.manualOverride, isTrue);
      expect(manager.preferAtoB, isFalse);

      final result = manager.resolve(detectedLanguageCode: 'auto');
      expect(result.sourceLanguage.code, equals('te'));
      expect(result.targetLanguage.code, equals('en'));
      expect(result.speaker, equals(ConversationSpeaker.speakerB));
      expect(result.canTranslate, isTrue);

      manager.clearManualOverride();
      expect(manager.manualOverride, isFalse);
    });

    group('Dynamic Auto Detect Source Tests', () {
      late TwoWayDirectionManager autoManager;

      setUp(() {
        autoManager = TwoWayDirectionManager(
          languageA: LanguageModel.autoDetect,
          languageB: telugu,
        );
      });

      test('English speech when Source is Auto Detect and Target is Telugu', () {
        final result = autoManager.resolve(detectedLanguageCode: 'en');

        expect(result.sourceLanguage.code, equals('en'));
        expect(result.targetLanguage.code, equals('te'));
        expect(result.speaker, equals(ConversationSpeaker.speakerA));
        expect(result.canTranslate, isTrue);
        expect(result.isOutsidePair, isFalse);
        expect(result.isUncertain, isFalse);
      });

      test('Telugu speech when Source is Auto Detect and Target is Telugu', () {
        // Speaker speaking the target language Telugu resolves to Telugu -> English (partner)
        final result = autoManager.resolve(detectedLanguageCode: 'te');

        expect(result.sourceLanguage.code, equals('te'));
        expect(result.targetLanguage.code, equals('en'));
        expect(result.speaker, equals(ConversationSpeaker.speakerB));
        expect(result.canTranslate, isTrue);
        expect(result.isOutsidePair, isFalse);
      });

      test('Hindi speech when Source is Auto Detect and Target is Telugu', () {
        final result = autoManager.resolve(detectedLanguageCode: 'hi');

        expect(result.sourceLanguage.code, equals('hi'));
        expect(result.targetLanguage.code, equals('te'));
        expect(result.speaker, equals(ConversationSpeaker.speakerA));
        expect(result.canTranslate, isTrue);
      });
    });
  });
}
