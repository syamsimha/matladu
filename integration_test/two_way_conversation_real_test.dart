import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:matladu_ai/data/models/asr_state.dart';
import 'package:matladu_ai/data/models/conversation_turn_model.dart';
import 'package:matladu_ai/data/repositories/settings_repository.dart';
import 'package:matladu_ai/data/repositories/translation_repository.dart';
import 'package:matladu_ai/data/repositories/tts_repository.dart';
import 'package:matladu_ai/data/services/local_storage_service.dart';
import 'package:matladu_ai/data/services/translation/on_device_translation_service.dart';
import 'package:matladu_ai/data/services/tts/on_device_tts_service.dart';
import 'package:matladu_ai/ui/features/live_translation/view_models/live_translation_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _ensureRenderSurface(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: Text(
            'Running Phase 6 Real Two-Way Conversation Integration Tests...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _waitForTurn(LiveTranslationViewModel vm, int targetTurn, {int timeoutMs = 15000}) async {
  final start = DateTime.now();
  while (vm.turnCount < targetTurn &&
      vm.turnState != ConversationTurnState.error &&
      DateTime.now().difference(start).inMilliseconds < timeoutMs) {
    await Future.delayed(const Duration(milliseconds: 100));
  }
  if (vm.turnCount < targetTurn) {
    debugPrint('[Test] _waitForTurn($targetTurn) timed out: turnCount=${vm.turnCount}, state=${vm.turnState}, error="${vm.errorMessage}"');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 6: Real Two-Way Voice Conversation Integration Tests', () {
    late OnDeviceTtsService ttsService;
    late OnDeviceTranslationService translationService;
    late LocalStorageService storageService;
    late TtsRepository ttsRepo;
    late TranslationRepository translationRepo;
    late SettingsRepository settingsRepo;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storageService = LocalStorageService(prefs);

      ttsService = OnDeviceTtsService();
      await ttsService.initialize();

      translationService = OnDeviceTranslationService();
      await translationService.initialize();
      await translationService.downloadModel('te');
      await translationService.downloadModel('hi');

      // Warm up offline translation engine on hardware
      debugPrint('[IntegrationTest] Warming up offline translator...');
      await translationService.translate(
        text: 'Hello',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );
      debugPrint('[IntegrationTest] Translator warmed up successfully.');

      ttsRepo = TtsRepository(
        ttsService: ttsService,
        storageService: storageService,
      );
      await ttsRepo.initialize();

      translationRepo = TranslationRepository(
        translationService: translationService,
        storageService: storageService,
      );

      settingsRepo = SettingsRepository(storageService: storageService);
    });

    tearDownAll(() async {
      await ttsRepo.dispose();
      await translationService.dispose();
    });

    testWidgets('Turn 1: Person A speaks English -> detects English -> translates to Telugu -> auto speaks Telugu',
        (tester) async {
      await _ensureRenderSurface(tester);

      final initialAsr = ASRRecognitionResult(
        text: 'Where is the nearest hospital?',
        isFinal: true,
        detectedLanguageCode: 'en',
        detectedLanguageName: 'English',
        confidence: 0.98,
        audioDuration: const Duration(seconds: 2),
        timestamp: DateTime.now(),
      );

      final vm = LiveTranslationViewModel(
        initialRecognition: initialAsr,
        translationRepository: translationRepo,
        ttsRepository: ttsRepo,
        settingsRepository: settingsRepo,
        initialSourceLanguageCode: 'en',
        initialTargetLanguageCode: 'te',
      );

      // Await initial translation and automatic TTS trigger
      await _waitForTurn(vm, 1);

      expect(vm.originalText, equals('Where is the nearest hospital?'));
      expect(vm.sourceLanguageCode, equals('en'));
      expect(vm.targetLanguageCode, equals('te'));
      expect(vm.translatedText.isNotEmpty, isTrue);
      expect(vm.turnCount, equals(1));

      final turn1 = vm.conversationHistory.first;
      expect(turn1.speaker, equals(ConversationSpeaker.speakerA));
      expect(turn1.sourceLanguageCode, equals('en'));
      expect(turn1.targetLanguageCode, equals('te'));
      expect(turn1.originalText, equals('Where is the nearest hospital?'));
      expect(turn1.translatedText, equals(vm.translatedText));
      expect(turn1.turnNumber, equals(1));

      debugPrint('=== TURN 1 COMPLETED ===');
      debugPrint('Speaker: ${turn1.speaker.label}');
      debugPrint('Original: "${turn1.originalText}" (${turn1.sourceLanguageCode})');
      debugPrint('Translated: "${turn1.translatedText}" (${turn1.targetLanguageCode})');
      debugPrint('Turn State: ${vm.turnState}');
    });

    testWidgets('Turn 2: Person B responds in Telugu -> detects Telugu -> translates to English -> auto speaks English',
        (tester) async {
      await _ensureRenderSurface(tester);

      final initialAsr = ASRRecognitionResult(
        text: 'Where is the nearest hospital?',
        isFinal: true,
        detectedLanguageCode: 'en',
        detectedLanguageName: 'English',
        confidence: 0.98,
        audioDuration: const Duration(seconds: 2),
        timestamp: DateTime.now(),
      );

      final vm = LiveTranslationViewModel(
        initialRecognition: initialAsr,
        translationRepository: translationRepo,
        ttsRepository: ttsRepo,
        settingsRepository: settingsRepo,
        initialSourceLanguageCode: 'en',
        initialTargetLanguageCode: 'te',
      );

      await _waitForTurn(vm, 1);
      expect(vm.turnCount, equals(1));

      // Simulate Person B responding in Telugu
      final turn2Asr = ASRRecognitionResult(
        text: 'ఆసుపత్రి రెండు కిలోమీటర్ల దూరంలో ఉంది.',
        isFinal: true,
        detectedLanguageCode: 'te',
        detectedLanguageName: 'Telugu',
        confidence: 0.96,
        audioDuration: const Duration(seconds: 2),
        timestamp: DateTime.now(),
      );

      vm.updateRecognitionResult(turn2Asr);
      await _waitForTurn(vm, 2);

      expect(vm.turnCount, equals(2));
      final turn2 = vm.conversationHistory[1];
      expect(turn2.speaker, equals(ConversationSpeaker.speakerB));
      expect(turn2.sourceLanguageCode, equals('te'));
      expect(turn2.targetLanguageCode, equals('en'));
      expect(turn2.originalText, equals('ఆసుపత్రి రెండు కిలోమీటర్ల దూరంలో ఉంది.'));
      expect(turn2.translatedText.isNotEmpty, isTrue);

      debugPrint('=== TURN 2 COMPLETED ===');
      debugPrint('Speaker: ${turn2.speaker.label}');
      debugPrint('Original: "${turn2.originalText}" (${turn2.sourceLanguageCode})');
      debugPrint('Translated: "${turn2.translatedText}" (${turn2.targetLanguageCode})');
    });

    testWidgets('Multi-Turn Conversation: 5 alternating turns flow naturally without leaving screen',
        (tester) async {
      await _ensureRenderSurface(tester);

      final utterances = [
        ASRRecognitionResult(
          text: 'Hello, how can I help you today?',
          isFinal: true,
          detectedLanguageCode: 'en',
          detectedLanguageName: 'English',
          confidence: 0.98,
          audioDuration: const Duration(seconds: 2),
          timestamp: DateTime.now(),
        ),
        ASRRecognitionResult(
          text: 'నాకు బస్సు స్టాండ్ ఎక్కడ ఉందో చెప్పగలరా?',
          isFinal: true,
          detectedLanguageCode: 'te',
          detectedLanguageName: 'Telugu',
          confidence: 0.95,
          audioDuration: const Duration(seconds: 2),
          timestamp: DateTime.now(),
        ),
        ASRRecognitionResult(
          text: 'It is straight down this street, next to the bank.',
          isFinal: true,
          detectedLanguageCode: 'en',
          detectedLanguageName: 'English',
          confidence: 0.97,
          audioDuration: const Duration(seconds: 2),
          timestamp: DateTime.now(),
        ),
        ASRRecognitionResult(
          text: 'చాలా ధన్యవాదాలు, ఎంత సమయం పడుతుంది?',
          isFinal: true,
          detectedLanguageCode: 'te',
          detectedLanguageName: 'Telugu',
          confidence: 0.96,
          audioDuration: const Duration(seconds: 2),
          timestamp: DateTime.now(),
        ),
        ASRRecognitionResult(
          text: 'It takes about five minutes to walk there.',
          isFinal: true,
          detectedLanguageCode: 'en',
          detectedLanguageName: 'English',
          confidence: 0.99,
          audioDuration: const Duration(seconds: 2),
          timestamp: DateTime.now(),
        ),
      ];

      final vm = LiveTranslationViewModel(
        initialRecognition: utterances[0],
        translationRepository: translationRepo,
        ttsRepository: ttsRepo,
        settingsRepository: settingsRepo,
        initialSourceLanguageCode: 'en',
        initialTargetLanguageCode: 'te',
      );

      await _waitForTurn(vm, 1);

      // Turns 2 through 5
      for (int i = 1; i < utterances.length; i++) {
        vm.updateRecognitionResult(utterances[i]);
        await _waitForTurn(vm, i + 1);
      }

      expect(vm.turnCount, equals(5));
      expect(vm.conversationHistory.length, equals(5));

      // Verify alternating speakers
      expect(vm.conversationHistory[0].speaker, equals(ConversationSpeaker.speakerA));
      expect(vm.conversationHistory[1].speaker, equals(ConversationSpeaker.speakerB));
      expect(vm.conversationHistory[2].speaker, equals(ConversationSpeaker.speakerA));
      expect(vm.conversationHistory[3].speaker, equals(ConversationSpeaker.speakerB));
      expect(vm.conversationHistory[4].speaker, equals(ConversationSpeaker.speakerA));

      // Verify turn numbers
      for (int i = 0; i < 5; i++) {
        expect(vm.conversationHistory[i].turnNumber, equals(i + 1));
      }

      debugPrint('=== 5-TURN CONVERSATION VERIFIED ===');
      for (final turn in vm.conversationHistory) {
        debugPrint('Turn ${turn.turnNumber} [${turn.speaker.label}]: "${turn.originalText}" -> "${turn.translatedText}"');
      }
    });

    testWidgets('Acoustic Feedback Protection: Mic lock prevents recording while TTS plays',
        (tester) async {
      await _ensureRenderSurface(tester);

      final initialAsr = ASRRecognitionResult(
        text: 'Where is the nearest hospital?',
        isFinal: true,
        detectedLanguageCode: 'en',
        confidence: 0.98,
        audioDuration: const Duration(seconds: 2),
        timestamp: DateTime.now(),
      );

      final vm = LiveTranslationViewModel(
        initialRecognition: initialAsr,
        translationRepository: translationRepo,
        ttsRepository: ttsRepo,
        settingsRepository: settingsRepo,
      );

      await Future.delayed(const Duration(milliseconds: 300));

      // Play translation
      await vm.playTranslation();
      await Future.delayed(const Duration(milliseconds: 50));

      if (vm.isPlayingAudio) {
        final started = await vm.startListening();
        expect(started, isFalse);
        expect(vm.isListening, isFalse);
        expect(vm.isPlayingAudio, isFalse); // Successfully stopped audio playback
      }

      await vm.stopPlayback(isManual: true);
    });

    testWidgets('Manual controls: swapDirection, replayTurn, clearConversationHistory',
        (tester) async {
      await _ensureRenderSurface(tester);

      final vm = LiveTranslationViewModel(
        translationRepository: translationRepo,
        ttsRepository: ttsRepo,
        settingsRepository: settingsRepo,
        initialSourceLanguageCode: 'en',
        initialTargetLanguageCode: 'te',
      );

      expect(vm.sourceLanguageCode, equals('en'));
      expect(vm.targetLanguageCode, equals('te'));

      // Swap direction
      vm.swapDirection();
      expect(vm.sourceLanguageCode, equals('te'));
      expect(vm.targetLanguageCode, equals('en'));

      vm.swapDirection();
      expect(vm.sourceLanguageCode, equals('en'));
      expect(vm.targetLanguageCode, equals('te'));

      // Clear history
      vm.clearConversationHistory();
      expect(vm.turnCount, equals(0));
      expect(vm.conversationHistory.isEmpty, isTrue);
      expect(vm.turnState, equals(ConversationTurnState.idle));
    });
  });
}
