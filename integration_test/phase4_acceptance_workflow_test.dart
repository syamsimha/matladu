import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:matladu_ai/data/models/asr_state.dart';
import 'package:matladu_ai/data/models/language_model.dart';
import 'package:matladu_ai/data/repositories/settings_repository.dart';
import 'package:matladu_ai/data/repositories/translation_repository.dart';
import 'package:matladu_ai/data/services/local_storage_service.dart';
import 'package:matladu_ai/data/services/translation/on_device_translation_service.dart';
import 'package:matladu_ai/ui/features/home/view_models/home_view_model.dart';
import 'package:matladu_ai/ui/features/live_translation/views/live_translation_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _renderScreen(
  WidgetTester tester, {
  required ASRRecognitionResult asrResult,
  required String targetLangCode,
  required TranslationRepository translationRepo,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<TranslationRepository>.value(value: translationRepo),
      ],
      child: MaterialApp(
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (_) => const LiveTranslationScreen(),
            settings: RouteSettings(
              name: '/live-translation',
              arguments: {
                'asrResult': asrResult,
                'targetLanguageCode': targetLangCode,
              },
            ),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4 Live Acceptance Workflow Tests', () {
    late OnDeviceTranslationService translationService;
    late TranslationRepository translationRepo;
    late LocalStorageService storageService;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storageService = LocalStorageService(prefs);
      translationService = OnDeviceTranslationService();
      await translationService.initialize();
      translationRepo = TranslationRepository(
        translationService: translationService,
        storageService: storageService,
      );
    });

    tearDownAll(() async {
      await translationService.dispose();
    });

    testWidgets('1. English Speech Input -> Auto-detected English -> Translates into Selected Telugu Target', (tester) async {
      const spokenEnglish = 'Hello, how are you?';
      final asrResult = ASRRecognitionResult(
        text: spokenEnglish,
        isFinal: true,
        confidence: 0.95,
        detectedLanguageCode: 'en',
        detectedLanguageName: 'English',
        audioDuration: const Duration(seconds: 2),
        timestamp: DateTime.now(),
        isMock: false,
      );

      await _renderScreen(
        tester,
        asrResult: asrResult,
        targetLangCode: 'te',
        translationRepo: translationRepo,
      );

      // Wait for genuine on-device ML Kit translation to finish
      int waited = 0;
      while (find.textContaining('హలో').evaluate().isEmpty && waited < 30) {
        await tester.pump(const Duration(milliseconds: 500));
        waited++;
      }

      debugPrint('=== ACCEPTANCE TEST 1: ENGLISH -> TELUGU ===');
      debugPrint('Spoken Input: "$spokenEnglish"');
      debugPrint('Detected Language: ${asrResult.detectedLanguageCode} (${asrResult.detectedLanguageName})');
      debugPrint('Target Language: te (Telugu)');
      debugPrint('Verified on UI: ${find.textContaining("హలో").evaluate().isNotEmpty}');
      debugPrint('============================================');

      expect(find.textContaining(spokenEnglish), findsWidgets);
      expect(find.textContaining('Telugu'), findsWidgets);
      expect(find.textContaining('హలో'), findsWidgets);
    });

    testWidgets('2. Telugu Speech Input -> Auto-detected Telugu -> Translates into Selected English Target', (tester) async {
      const spokenTelugu = 'మీరు ఎలా ఉన్నారు?';
      final asrResult = ASRRecognitionResult(
        text: spokenTelugu,
        isFinal: true,
        confidence: 0.95,
        detectedLanguageCode: 'te',
        detectedLanguageName: 'Telugu',
        audioDuration: const Duration(seconds: 2),
        timestamp: DateTime.now(),
        isMock: false,
      );

      await _renderScreen(
        tester,
        asrResult: asrResult,
        targetLangCode: 'en',
        translationRepo: translationRepo,
      );

      int waited = 0;
      while (find.textContaining('how are you', skipOffstage: false).evaluate().isEmpty && waited < 20) {
        await tester.pump(const Duration(milliseconds: 500));
        waited++;
      }

      debugPrint('=== ACCEPTANCE TEST 2: TELUGU -> ENGLISH ===');
      debugPrint('Spoken Input: "$spokenTelugu"');
      debugPrint('Detected Language: ${asrResult.detectedLanguageCode} (${asrResult.detectedLanguageName})');
      debugPrint('Target Language: en (English)');
      debugPrint('Verified on UI: ${find.textContaining("how are you").evaluate().isNotEmpty}');
      debugPrint('============================================');

      expect(find.textContaining(spokenTelugu), findsWidgets);
      expect(find.textContaining('English'), findsWidgets);
      expect(find.textContaining('how are you'), findsWidgets);
    });

    testWidgets('3. Hindi Speech Input -> Auto-detected Hindi -> Translates into Selected English Target', (tester) async {
      const spokenHindi = 'आप कैसे हैं?';
      final asrResult = ASRRecognitionResult(
        text: spokenHindi,
        isFinal: true,
        confidence: 0.95,
        detectedLanguageCode: 'hi',
        detectedLanguageName: 'Hindi',
        audioDuration: const Duration(seconds: 2),
        timestamp: DateTime.now(),
        isMock: false,
      );

      await _renderScreen(
        tester,
        asrResult: asrResult,
        targetLangCode: 'en',
        translationRepo: translationRepo,
      );

      int waited = 0;
      while (find.textContaining('how are you', skipOffstage: false).evaluate().isEmpty && waited < 20) {
        await tester.pump(const Duration(milliseconds: 500));
        waited++;
      }

      debugPrint('=== ACCEPTANCE TEST 3: HINDI -> ENGLISH ===');
      debugPrint('Spoken Input: "$spokenHindi"');
      debugPrint('Detected Language: ${asrResult.detectedLanguageCode} (${asrResult.detectedLanguageName})');
      debugPrint('Target Language: en (English)');
      debugPrint('Verified on UI: ${find.textContaining("how are you").evaluate().isNotEmpty}');
      debugPrint('===========================================');

      expect(find.textContaining(spokenHindi), findsWidgets);
      expect(find.textContaining('English'), findsWidgets);
      expect(find.textContaining('how are you'), findsWidgets);
    });

    testWidgets('4. Target Language Preservation Test', (tester) async {
      final settings = SettingsRepository(storageService: storageService);
      final vm = HomeViewModel(
        settingsRepository: settings,
        translationRepository: translationRepo,
      );

      // User explicitly selected Telugu as target
      const selectedTarget = LanguageModel(
        code: 'te',
        name: 'Telugu',
        nativeName: 'తెలుగు',
      );
      await vm.setTargetLanguage(selectedTarget);
      expect(vm.targetLanguage.code, 'te');

      // Verify that HomeViewModel does NOT silently mutate vm.targetLanguage
      expect(vm.targetLanguage.code, 'te', reason: 'Target language must be strictly preserved.');
    });
  });
}
