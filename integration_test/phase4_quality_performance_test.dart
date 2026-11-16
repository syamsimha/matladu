import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:matladu_ai/data/models/audio_recording_state.dart';
import 'package:matladu_ai/data/models/translation_result.dart';
import 'package:matladu_ai/data/services/asr/model_manager_service.dart';
import 'package:matladu_ai/data/services/asr/pcm_converter.dart';
import 'package:matladu_ai/data/services/asr/sherpa_on_device_asr_service.dart';
import 'package:matladu_ai/data/services/translation/on_device_translation_service.dart';

Future<void> _ensureRenderSurface(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: Text(
            'Running Phase 4 Verification Suite...',
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

  group('Phase 4 Final Quality & Performance Suite', () {
    testWidgets('TASK 1: Prepare & Verify On-Device Translation Models', (tester) async {
      await _ensureRenderSurface(tester);
      final translationService = OnDeviceTranslationService();
      await translationService.initialize();

      debugPrint('=== TASK 1: PREPARING MODELS ===');
      if (!await translationService.isModelDownloaded('te')) {
        debugPrint('[Test] Ensuring Telugu model is installed...');
        await translationService.downloadModel('te');
      }
      if (!await translationService.isModelDownloaded('hi')) {
        debugPrint('[Test] Ensuring Hindi model is installed...');
        await translationService.downloadModel('hi');
      }
      if (!await translationService.isModelDownloaded('en')) {
        debugPrint('[Test] Ensuring English model is installed...');
        await translationService.downloadModel('en');
      }

      final teOk = await translationService.isModelDownloaded('te');
      final hiOk = await translationService.isModelDownloaded('hi');
      final enOk = await translationService.isModelDownloaded('en');
      debugPrint('Model readiness: en=$enOk, te=$teOk, hi=$hiOk');
      expect(enOk, isTrue);
      expect(teOk, isTrue);
      expect(hiOk, isTrue);

      await translationService.dispose();
    });

    testWidgets('TASK 4: Model Security & Application Private Sandbox Audit', (tester) async {
      await _ensureRenderSurface(tester);
      final modelManager = ModelManagerService();
      final isInstalled = await modelManager.isModelInstalled('whisper-tiny-multilingual');
      expect(isInstalled, isTrue);

      final paths = await modelManager.getModelFilePaths('whisper-tiny-multilingual');
      debugPrint('=== TASK 4: SECURE MODEL PATHS AUDIT ===');
      for (final entry in paths.entries) {
        debugPrint('Model File [${entry.key}]: ${entry.value}');
        expect(entry.value.contains('/data/local/tmp'), isFalse, reason: 'Must NOT read from /data/local/tmp');
        expect(entry.value.contains('app_flutter'), isTrue, reason: 'Must reside in app-private storage');
        final file = File(entry.value);
        expect(file.existsSync(), isTrue);
        expect(file.lengthSync(), greaterThan(100 * 1024));
      }
      debugPrint('ASR Model Storage: 100% App-Private Sandbox.');
      debugPrint('========================================');
    });

    testWidgets('TASK 5: Performance Disaggregation (0.wav Cold vs Warm)', (tester) async {
      await _ensureRenderSurface(tester);
      final modelManager = ModelManagerService();
      final asrService = SherpaOnDeviceASRService(
        modelManager: modelManager,
        fallbackService: null,
      );
      final translationService = OnDeviceTranslationService();

      final wavFile = File('/data/local/tmp/0.wav');
      expect(await wavFile.exists(), isTrue);
      final allBytes = await wavFile.readAsBytes();
      final pcmBytes = allBytes.sublist(44);
      final audioCaptureDurationMs = (pcmBytes.length / (16000 * 2) * 1000).round();

      // --- COLD START ---
      final coldPcmWatch = Stopwatch()..start();
      PCMConverter.pcm16ToFloat32(pcmBytes);
      PCMConverter.computeRms(pcmBytes);
      coldPcmWatch.stop();
      final coldPcmMs = coldPcmWatch.elapsedMilliseconds;

      final coldAsrInitWatch = Stopwatch()..start();
      await asrService.initialize();
      coldAsrInitWatch.stop();
      final coldAsrInitMs = coldAsrInitWatch.elapsedMilliseconds;

      final coldAsrInferWatch = Stopwatch()..start();
      final asrResult = await asrService.transcribePcmBuffer(
        pcmBytes,
        audioConfig: const AudioCaptureConfig(),
        languageCodeHint: 'en',
      );
      coldAsrInferWatch.stop();
      final coldAsrInferMs = coldAsrInferWatch.elapsedMilliseconds;

      final coldTransInitWatch = Stopwatch()..start();
      await translationService.initialize();
      coldTransInitWatch.stop();
      final coldTransInitMs = coldTransInitWatch.elapsedMilliseconds;

      final coldTransInferWatch = Stopwatch()..start();
      final transResult = await translationService.translate(
        text: asrResult.text,
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );
      coldTransInferWatch.stop();
      final coldTransInferMs = coldTransInferWatch.elapsedMilliseconds;

      final coldTotalPipelineMs = audioCaptureDurationMs +
          coldPcmMs +
          coldAsrInitMs +
          coldAsrInferMs +
          coldTransInitMs +
          coldTransInferMs;

      debugPrint('=== TASK 5: COLD-START DISAGGREGATED BENCHMARKS (0.WAV) ===');
      debugPrint('(1) Audio capture duration:       $audioCaptureDurationMs ms (${(audioCaptureDurationMs / 1000).toStringAsFixed(2)} s)');
      debugPrint('(2) PCM preprocessing duration:    $coldPcmMs ms');
      debugPrint('(3) ASR model initialization:      $coldAsrInitMs ms');
      debugPrint('(4) Actual Whisper inference:      $coldAsrInferMs ms');
      debugPrint('(5) Translation model init:        $coldTransInitMs ms');
      debugPrint('(6) Translation inference:         $coldTransInferMs ms');
      debugPrint('(7) Total End-to-End Pipeline:     $coldTotalPipelineMs ms');
      debugPrint('    Recognized text:               "${asrResult.text}"');
      debugPrint('    Translated text:               "${transResult.translatedText}"');
      debugPrint('===========================================================');

      // --- WARM START ---
      final warmPcmWatch = Stopwatch()..start();
      PCMConverter.pcm16ToFloat32(pcmBytes);
      warmPcmWatch.stop();
      final warmPcmMs = warmPcmWatch.elapsedMilliseconds;

      const warmAsrInitMs = 0; // Cached in RAM

      final warmAsrInferWatch = Stopwatch()..start();
      final warmAsrResult = await asrService.transcribePcmBuffer(
        pcmBytes,
        audioConfig: const AudioCaptureConfig(),
        languageCodeHint: 'en',
      );
      warmAsrInferWatch.stop();
      final warmAsrInferMs = warmAsrInferWatch.elapsedMilliseconds;

      const warmTransInitMs = 0; // Cached in RAM

      final warmTransInferWatch = Stopwatch()..start();
      final warmTransResult = await translationService.translate(
        text: warmAsrResult.text,
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );
      warmTransInferWatch.stop();
      final warmTransInferMs = warmTransInferWatch.elapsedMilliseconds;

      final warmTotalPipelineMs = audioCaptureDurationMs +
          warmPcmMs +
          warmAsrInitMs +
          warmAsrInferMs +
          warmTransInitMs +
          warmTransInferMs;

      debugPrint('=== TASK 5: WARM-START DISAGGREGATED BENCHMARKS (0.WAV) ===');
      debugPrint('(1) Audio capture duration:       $audioCaptureDurationMs ms');
      debugPrint('(2) PCM preprocessing duration:    $warmPcmMs ms');
      debugPrint('(3) ASR model initialization:      $warmAsrInitMs ms (cached in memory)');
      debugPrint('(4) Actual Whisper inference:      $warmAsrInferMs ms');
      debugPrint('(5) Translation model init:        $warmTransInitMs ms (cached in memory)');
      debugPrint('(6) Translation inference:         $warmTransInferMs ms');
      debugPrint('(7) Total End-to-End Pipeline:     $warmTotalPipelineMs ms');
      debugPrint('===========================================================');

      expect(asrResult.isMock, isFalse);
      expect(transResult.isMock, isFalse);
      expect(warmAsrResult.isMock, isFalse);
      expect(warmTransResult.isMock, isFalse);

      await asrService.dispose();
      await translationService.dispose();
    });

    testWidgets('TASK 2: Translation Quality & Domain Boundaries Evaluation', (tester) async {
      await _ensureRenderSurface(tester);
      final translationService = OnDeviceTranslationService();
      await translationService.initialize();

      final qualityTests = <Map<String, String>>[
        {
          'category': 'Conversational Greeting',
          'source': 'Hello, my name is John. Nice to meet you.',
          'src': 'en',
          'tgt': 'te',
        },
        {
          'category': 'Conversational Hindi',
          'source': 'Hello, my name is John. Nice to meet you.',
          'src': 'en',
          'tgt': 'hi',
        },
        {
          'category': 'Transit / Navigation',
          'source': 'Where is the nearest railway station?',
          'src': 'en',
          'tgt': 'te',
        },
        {
          'category': 'Basic Needs',
          'source': 'I need a glass of water, please.',
          'src': 'en',
          'tgt': 'te',
        },
        {
          'category': 'Emergency',
          'source': 'Call a doctor immediately, this is an emergency!',
          'src': 'en',
          'tgt': 'te',
        },
        {
          'category': 'Long Sentence with Clauses',
          'source': 'Although it was raining heavily, the students walked to school without umbrellas.',
          'src': 'en',
          'tgt': 'te',
        },
        {
          'category': 'Names & Proper Nouns',
          'source': 'Hyderabad is the capital city of Telangana and has wonderful biryani.',
          'src': 'en',
          'tgt': 'te',
        },
        {
          'category': 'Archaic English (Dubliners 0.wav)',
          'source': 'After early nightfall, the yellow lamps would light up here and there the squalid quarter of the brothels.',
          'src': 'en',
          'tgt': 'te',
        },
        {
          'category': 'Telugu Native -> English',
          'source': 'దయచేసి నాకు కొంచెం సమయం ఇవ్వండి.',
          'src': 'te',
          'tgt': 'en',
        },
        {
          'category': 'Telugu Needs -> English',
          'source': 'నాకు ఆకలిగా ఉంది, భోజనం ఎక్కడ దొరుకుతుంది?',
          'src': 'te',
          'tgt': 'en',
        },
        {
          'category': 'Hindi Native -> English',
          'source': 'कृपया मुझे रास्ता बताइए।',
          'src': 'hi',
          'tgt': 'en',
        },
        {
          'category': 'Hindi Medical -> English',
          'source': 'मुझे डॉक्टर से मिलना है।',
          'src': 'hi',
          'tgt': 'en',
        },
      ];

      debugPrint('=== TASK 2: TRANSLATION QUALITY EVALUATION MATRIX ===');
      for (final qt in qualityTests) {
        final sw = Stopwatch()..start();
        final res = await translationService.translate(
          text: qt['source']!,
          sourceLanguageCode: qt['src']!,
          targetLanguageCode: qt['tgt']!,
        );
        sw.stop();

        debugPrint('[${qt['category']}] (${qt['src']} -> ${qt['tgt']})');
        debugPrint('  Input:  "${qt['source']}"');
        debugPrint('  Output: "${res.translatedText}"');
        debugPrint('  Latency: ${sw.elapsedMilliseconds} ms | isMock: ${res.isMock}');
        expect(res.status, TranslationStatus.completed);
        expect(res.isMock, isFalse);
        expect(res.hasText, isTrue);
      }
      debugPrint('=====================================================');

      await translationService.dispose();
    });
  });
}

