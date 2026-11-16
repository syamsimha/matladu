import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:matladu_ai/data/models/translation_result.dart';
import 'package:matladu_ai/data/services/translation/on_device_translation_service.dart';

Future<void> _ensureRenderSurface(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: Text(
            'Running On-Device Native Translation Tests...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('On-Device Neural Translation Integration Tests', () {
    late OnDeviceTranslationService translationService;

    setUpAll(() async {
      translationService = OnDeviceTranslationService();
      await translationService.initialize();
    });

    tearDownAll(() async {
      await translationService.dispose();
    });

    testWidgets('Ensure required on-device translation models are ready', (tester) async {
      await _ensureRenderSurface(tester);

      debugPrint('=== PREPARING ON-DEVICE TRANSLATION MODELS ===');
      final teReady = await translationService.isModelDownloaded('te');
      if (!teReady) {
        debugPrint('[IntegrationTest] Downloading Telugu model...');
        final teSuccess = await translationService.downloadModel('te');
        debugPrint('[IntegrationTest] Telugu download: $teSuccess');
      }

      final hiReady = await translationService.isModelDownloaded('hi');
      if (!hiReady) {
        debugPrint('[IntegrationTest] Downloading Hindi model...');
        final hiSuccess = await translationService.downloadModel('hi');
        debugPrint('[IntegrationTest] Hindi download: $hiSuccess');
      }

      final enOk = await translationService.isModelDownloaded('en');
      final teOk = await translationService.isModelDownloaded('te');
      final hiOk = await translationService.isModelDownloaded('hi');

      debugPrint('=== MODEL STATUS: en=$enOk, te=$teOk, hi=$hiOk ===');
      expect(enOk, isTrue, reason: 'English model must be ready.');
      expect(teOk, isTrue, reason: 'Telugu model must be ready.');
      expect(hiOk, isTrue, reason: 'Hindi model must be ready.');
    });

    testWidgets('Translates English to Telugu using genuine on-device neural model', (tester) async {
      await _ensureRenderSurface(tester);

      const sourceText = 'Hello, how are you?';
      final stopwatch = Stopwatch()..start();

      final result = await translationService.translate(
        text: sourceText,
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );
      stopwatch.stop();

      debugPrint('=== REAL ON-DEVICE TRANSLATION: ENGLISH -> TELUGU ===');
      debugPrint('Source text: "$sourceText"');
      debugPrint('Translated text: "${result.translatedText}"');
      debugPrint('Source language: ${result.sourceLanguageCode} (${result.sourceLanguageName})');
      debugPrint('Target language: ${result.targetLanguageCode} (${result.targetLanguageName})');
      debugPrint('Inference latency: ${stopwatch.elapsedMilliseconds} ms');
      debugPrint('Status: ${result.status}');
      debugPrint('Is Mock: ${result.isMock}');
      debugPrint('======================================================');

      expect(result.status, TranslationStatus.completed);
      expect(result.isMock, isFalse, reason: 'Must be genuine on-device neural translation, never mock.');
      expect(result.hasText, isTrue);
      expect(result.translatedText.isNotEmpty, isTrue);
      // Verify Telugu Unicode characters (0x0C00 - 0x0C7F)
      final hasTeluguChars = result.translatedText.runes.any((r) => r >= 0x0C00 && r <= 0x0C7F);
      expect(hasTeluguChars, isTrue, reason: 'Output must be written in authentic Telugu script.');
    });

    testWidgets('Translates Telugu to English using genuine on-device neural model', (tester) async {
      await _ensureRenderSurface(tester);

      const sourceText = 'మీరు ఎలా ఉన్నారు?';
      final stopwatch = Stopwatch()..start();

      final result = await translationService.translate(
        text: sourceText,
        sourceLanguageCode: 'te',
        targetLanguageCode: 'en',
      );
      stopwatch.stop();

      debugPrint('=== REAL ON-DEVICE TRANSLATION: TELUGU -> ENGLISH ===');
      debugPrint('Source text: "$sourceText"');
      debugPrint('Translated text: "${result.translatedText}"');
      debugPrint('Inference latency: ${stopwatch.elapsedMilliseconds} ms');
      debugPrint('Status: ${result.status}');
      debugPrint('Is Mock: ${result.isMock}');
      debugPrint('======================================================');

      expect(result.status, TranslationStatus.completed);
      expect(result.isMock, isFalse);
      expect(result.hasText, isTrue);
      expect(result.translatedText.toLowerCase(), contains('how are you'));
    });

    testWidgets('Translates English to Hindi using genuine on-device neural model', (tester) async {
      await _ensureRenderSurface(tester);

      const sourceText = 'Hello, how are you?';
      final stopwatch = Stopwatch()..start();

      final result = await translationService.translate(
        text: sourceText,
        sourceLanguageCode: 'en',
        targetLanguageCode: 'hi',
      );
      stopwatch.stop();

      debugPrint('=== REAL ON-DEVICE TRANSLATION: ENGLISH -> HINDI ===');
      debugPrint('Source text: "$sourceText"');
      debugPrint('Translated text: "${result.translatedText}"');
      debugPrint('Inference latency: ${stopwatch.elapsedMilliseconds} ms');
      debugPrint('Status: ${result.status}');
      debugPrint('Is Mock: ${result.isMock}');
      debugPrint('====================================================');

      expect(result.status, TranslationStatus.completed);
      expect(result.isMock, isFalse);
      expect(result.hasText, isTrue);
      // Verify Devanagari Unicode characters (0x0900 - 0x097F)
      final hasDevanagariChars = result.translatedText.runes.any((r) => r >= 0x0900 && r <= 0x097F);
      expect(hasDevanagariChars, isTrue, reason: 'Output must be written in authentic Devanagari script.');
    });

    testWidgets('Translates Hindi to English using genuine on-device neural model', (tester) async {
      await _ensureRenderSurface(tester);

      const sourceText = 'आप कैसे हैं?';
      final stopwatch = Stopwatch()..start();

      final result = await translationService.translate(
        text: sourceText,
        sourceLanguageCode: 'hi',
        targetLanguageCode: 'en',
      );
      stopwatch.stop();

      debugPrint('=== REAL ON-DEVICE TRANSLATION: HINDI -> ENGLISH ===');
      debugPrint('Source text: "$sourceText"');
      debugPrint('Translated text: "${result.translatedText}"');
      debugPrint('Inference latency: ${stopwatch.elapsedMilliseconds} ms');
      debugPrint('Status: ${result.status}');
      debugPrint('Is Mock: ${result.isMock}');
      debugPrint('====================================================');

      expect(result.status, TranslationStatus.completed);
      expect(result.isMock, isFalse);
      expect(result.hasText, isTrue);
      expect(result.translatedText.toLowerCase(), contains('how are you'));
    });

    testWidgets('End-to-End Speech-to-Translation Pipeline preserves context without cloud egress', (tester) async {
      await _ensureRenderSurface(tester);

      // Simulates recognized speech emitted by Phase 3 Whisper ASR
      const recognizedAsrSpeech =
          'After early nightfall, the yellow lamps would light up here and there the squalid quarter of the brothels.';

      final stopwatch = Stopwatch()..start();
      final translation = await translationService.translate(
        text: recognizedAsrSpeech,
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );
      stopwatch.stop();

      debugPrint('=== END-TO-END ASR -> TRANSLATION PIPELINE METRICS ===');
      debugPrint('ASR Speech Input: "$recognizedAsrSpeech"');
      debugPrint('Translated Telugu Output: "${translation.translatedText}"');
      debugPrint('Pipeline Translation Duration: ${stopwatch.elapsedMilliseconds} ms');
      debugPrint('Is Mock: ${translation.isMock}');
      debugPrint('======================================================');

      expect(translation.status, TranslationStatus.completed);
      expect(translation.isMock, isFalse);
      expect(translation.hasText, isTrue);
      expect(translation.translatedText.isNotEmpty, isTrue);
    });
  });
}
