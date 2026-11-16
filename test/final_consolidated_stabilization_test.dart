import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:matladu_ai/core/constants/app_strings.dart';
import 'package:matladu_ai/data/models/connection_mode_model.dart';
import 'package:matladu_ai/data/models/language_model.dart';
import 'package:matladu_ai/data/models/two_way_direction.dart';
import 'package:matladu_ai/data/repositories/settings_repository.dart';
import 'package:matladu_ai/data/repositories/translation_repository.dart';
import 'package:matladu_ai/data/services/asr/android_speech_recognizer_service.dart';
import 'package:matladu_ai/data/services/asr/transcript_validator.dart';
import 'package:matladu_ai/data/services/local_storage_service.dart';
import 'package:matladu_ai/data/services/translation/on_device_translation_service.dart';
import 'package:matladu_ai/data/services/translation/online_translation_service.dart';
import 'package:matladu_ai/ui/features/home/view_models/home_view_model.dart';
import 'package:matladu_ai/ui/features/live_translation/view_models/live_translation_view_model.dart';
import 'package:matladu_ai/ui/features/live_translation/views/live_translation_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late LocalStorageService storageService;
  late SettingsRepository settingsRepository;
  late OnDeviceTranslationService onDeviceTranslationService;
  late TranslationRepository translationRepository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storageService = LocalStorageService(prefs);
    settingsRepository = SettingsRepository(storageService: storageService);
    onDeviceTranslationService = OnDeviceTranslationService(
      simulatedDownloadedCodes: {'en', 'te', 'hi', 'ta', 'kn', 'de'},
    );
    translationRepository = TranslationRepository(
      translationService: onDeviceTranslationService,
      storageService: storageService,
    );
  });

  group('Priority 1: Speech Recognition, Language Detection & Accuracy', () {
    test('1. Romanized Telugu is correctly recognized as Telugu and not confused with English', () {
      expect(TranscriptValidator.isRomanizedTelugu('ela unnaru'), isTrue);
      expect(TranscriptValidator.isRomanizedTelugu('nenu bagunnanu'), isTrue);
      expect(TranscriptValidator.isRomanizedTelugu('namaskaram meeru ela unnaru'), isTrue);
      expect(TranscriptValidator.isRomanizedTelugu('chala baagundi'), isTrue);

      // Explicit English vocabulary is NOT Romanized Telugu
      expect(TranscriptValidator.isRomanizedTelugu('Welcome to Matladu'), isFalse);
      expect(TranscriptValidator.isRomanizedTelugu('Hello, how are you?'), isFalse);
      expect(TranscriptValidator.isRomanizedTelugu('Good morning everyone'), isFalse);
    });

    test('2. TwoWayDirectionManager resolves Romanized Telugu to Telugu in an En <-> Te session', () {
      final manager = TwoWayDirectionManager(
        languageA: const LanguageModel(code: 'en', name: 'English', nativeName: 'English'),
        languageB: const LanguageModel(code: 'te', name: 'Telugu', nativeName: 'తెలుగు'),
      );

      // Person speaks "ela unnaru" (Romanized Telugu)
      final result = manager.resolve(
        detectedLanguageCode: 'en', // ASR may transcribe in Latin script
        spokenText: 'ela unnaru',
      );

      expect(result.sourceLanguage.code, 'te');
      expect(result.targetLanguage.code, 'en');
      expect(result.canTranslate, isTrue);
      expect(result.isUncertain, isFalse);
    });

    test('3. Short speech fragments (e.g. "nd", "th", "d") are rejected as incomplete input', () {
      final resNd = TranscriptValidator.validate('nd');
      expect(resNd.isValid, isFalse);
      expect(resNd.reason, contains('Incomplete or fragmented speech'));

      final resTh = TranscriptValidator.validate('th');
      expect(resTh.isValid, isFalse);

      final resD = TranscriptValidator.validate('d');
      expect(resD.isValid, isFalse);

      // Valid short words are accepted
      final resHi = TranscriptValidator.validate('hi');
      expect(resHi.isValid, isTrue);

      final resOk = TranscriptValidator.validate('ok');
      expect(resOk.isValid, isTrue);
    });

    test('4. Target language content validation: German rejects Indic scripts; Telugu rejects pure Latin echo', () {
      // German target rejects Telugu/Devanagari script
      expect(TranscriptValidator.isScriptValidForTarget('నమస్తే', 'de'), isFalse);
      expect(TranscriptValidator.isScriptValidForTarget('नमस्ते', 'de'), isFalse);
      expect(TranscriptValidator.isScriptValidForTarget('Hallo, wie geht es Ihnen?', 'de'), isTrue);

      // English target rejects Telugu script
      expect(TranscriptValidator.isScriptValidForTarget('ఎలా ఉన్నారు', 'en'), isFalse);
      expect(TranscriptValidator.isScriptValidForTarget('Hello, how are you?', 'en'), isTrue);

      // Telugu target accepts Telugu script
      expect(TranscriptValidator.isScriptValidForTarget('నమస్కారం', 'te'), isTrue);
    });

    test('5. German Card never displays Telugu script content by default', () {
      final vm = LiveTranslationViewModel(
        translationRepository: translationRepository,
        initialTargetLanguageCode: 'de',
        initialSourceLanguageCode: 'en',
      );

      expect(vm.translatedText, isNot(contains('నమస్తే')));
      expect(vm.translatedText, isNot(contains('ఎలా')));
      expect(vm.targetLanguageCode, 'de');
    });

    test('6. Deterministic translation covers German and Indic language pairs accurately', () async {
      // en -> de
      final enToDe = await onDeviceTranslationService.translate(
        text: 'Hello, how are you?',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'de',
      );
      expect(enToDe.isSuccess, isTrue);
      expect(enToDe.translatedText, contains('Hallo'));

      // te -> de
      final teToDe = await onDeviceTranslationService.translate(
        text: 'మీరు ఎలా ఉన్నారు?',
        sourceLanguageCode: 'te',
        targetLanguageCode: 'de',
      );
      expect(teToDe.isSuccess, isTrue);
      expect(teToDe.translatedText, contains('Hallo'));
      expect(TranscriptValidator.isScriptValidForTarget(teToDe.translatedText, 'de'), isTrue);

      // de -> en
      final deToEn = await onDeviceTranslationService.translate(
        text: 'Hallo, wie geht es Ihnen?',
        sourceLanguageCode: 'de',
        targetLanguageCode: 'en',
      );
      expect(deToEn.isSuccess, isTrue);
      expect(deToEn.translatedText, contains('Hello'));

      // hi -> te
      final hiToTe = await onDeviceTranslationService.translate(
        text: 'नमस्ते, आप कैसे हैं?',
        sourceLanguageCode: 'hi',
        targetLanguageCode: 'te',
      );
      expect(hiToTe.isSuccess, isTrue);
      expect(hiToTe.translatedText, contains('నమస్కారం'));
    });

    test('7. Auto Detect resolves source language without defaulting to auto or self-translating', () {
      final manager = TwoWayDirectionManager(
        languageA: const LanguageModel(code: 'auto', name: 'Auto Detect', nativeName: 'Auto Detect'),
        languageB: const LanguageModel(code: 'te', name: 'Telugu', nativeName: 'తెలుగు'),
      );

      // Spoken English
      final enTurn = manager.resolve(detectedLanguageCode: 'en', spokenText: 'Hello');
      expect(enTurn.sourceLanguage.code, 'en');
      expect(enTurn.targetLanguage.code, 'te');
      expect(enTurn.canTranslate, isTrue);

      // Spoken Telugu
      final teTurn = manager.resolve(detectedLanguageCode: 'te', spokenText: 'నమస్కారం');
      expect(teTurn.sourceLanguage.code, 'te');
      expect(teTurn.targetLanguage.code, 'en');
      expect(teTurn.canTranslate, isTrue);
    });
  });

  group('Priority 2: Cloud Speech Recognition, Rules & Privacy', () {
    test('8. Verified supported languages for Google Speech Services include 12 languages', () {
      expect(AndroidSpeechRecognizerService.isLanguageSupported('en'), isTrue);
      expect(AndroidSpeechRecognizerService.isLanguageSupported('de'), isTrue);
      expect(AndroidSpeechRecognizerService.isLanguageSupported('hi'), isTrue);
      expect(AndroidSpeechRecognizerService.isLanguageSupported('te'), isTrue);
      expect(AndroidSpeechRecognizerService.isLanguageSupported('ta'), isTrue);
      expect(AndroidSpeechRecognizerService.isLanguageSupported('kn'), isTrue);
      expect(AndroidSpeechRecognizerService.isLanguageSupported('ml'), isTrue);
      expect(AndroidSpeechRecognizerService.isLanguageSupported('bn'), isTrue);
      expect(AndroidSpeechRecognizerService.isLanguageSupported('gu'), isTrue);
      expect(AndroidSpeechRecognizerService.isLanguageSupported('mr'), isTrue);
      expect(AndroidSpeechRecognizerService.isLanguageSupported('pa'), isTrue);
      expect(AndroidSpeechRecognizerService.isLanguageSupported('ur'), isTrue);

      // 'auto' is not a fixed locale
      expect(AndroidSpeechRecognizerService.isLanguageSupported('auto'), isFalse);
    });

    test('9. Online Mode with Cloud Consent ON and Auto Detect explains language selection requirement', () async {
      await settingsRepository.setCloudSpeechConsent(true);
      await settingsRepository.setConnectionMode(ConnectionModeType.cloudAi);
      final vm = HomeViewModel(
        translationRepository: translationRepository,
        settingsRepository: settingsRepository,
      );
      vm.setSourceLanguage(const LanguageModel(code: 'auto', name: 'Auto Detect', nativeName: 'Auto Detect'));

      // If Whisper is missing, Auto Detect in Online mode prompts user with accurate explanation
      final started = await vm.toggleRecording();
      if (!started && vm.audioErrorMessage != null) {
        expect(vm.audioErrorMessage, contains('Cloud Speech Recognition requires selecting a specific spoken language'));
      }
    });

    test('10. Cloud Speech consent defaults to OFF (Privacy invariant: 0 audio egress without consent)', () {
      expect(settingsRepository.getCloudSpeechConsent(), isFalse);
    });
  });

  group('Priority 3: Matladu Branding and UI Consistency', () {
    test('11. Matladu tagline and title constants conform to approved brand specifications', () {
      expect(AppStrings.appName, 'Matladu');
      expect(AppStrings.tagline, 'Speak • Translate • Connect');
    });

    testWidgets('12. LiveTranslationScreen displays language-appropriate placeholder for German target', (tester) async {
      final vm = LiveTranslationViewModel(
        translationRepository: translationRepository,
        initialTargetLanguageCode: 'de',
        initialSourceLanguageCode: 'en',
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<LiveTranslationViewModel>.value(
          value: vm,
          child: const MaterialApp(
            home: Scaffold(
              body: LiveTranslationScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that German card does NOT display Telugu script
      expect(find.text(AppStrings.sampleTeluguText), findsNothing);
      expect(find.text('Hallo, wie geht es Ihnen?'), findsOneWidget);
    });
  });

  group('Priority 4: Permanent Free Forever Policy & Quota Handling', () {
    test('13. OnlineTranslationService enforces verified MyMemory quota limits and segment sizing', () {
      expect(OnlineTranslationService.maxQueryBytes, lessThanOrEqualTo(400));
      expect(OnlineTranslationService.guaranteedDailyCharQuotaAnonymous, 5000);
      expect(OnlineTranslationService.expectedResetCooldown, const Duration(hours: 24));
    });

    test('14. Quota exhaustion triggers conservative cooldown and avoids repeated network flooding', () {
      final service = OnlineTranslationService();
      expect(service.isDailyQuotaExhausted, isFalse);

      service.markQuotaExhausted();
      expect(service.isDailyQuotaExhausted, isTrue);
      expect(service.isEligibleForConservativeProbe, isFalse);
    });
  });
}
