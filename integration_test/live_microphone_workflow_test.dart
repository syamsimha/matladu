import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:matladu_ai/data/models/audio_recording_state.dart';
import 'package:matladu_ai/data/models/language_model.dart';
import 'package:matladu_ai/data/models/translation_result.dart';
import 'package:matladu_ai/data/repositories/asr_repository.dart';
import 'package:matladu_ai/data/repositories/audio_repository.dart';
import 'package:matladu_ai/data/repositories/settings_repository.dart';
import 'package:matladu_ai/data/repositories/translation_repository.dart';
import 'package:matladu_ai/data/services/asr/model_manager_service.dart';
import 'package:matladu_ai/data/services/asr/pcm_converter.dart';
import 'package:matladu_ai/data/services/asr/sherpa_on_device_asr_service.dart';
import 'package:matladu_ai/data/services/audio_capture_service.dart';
import 'package:matladu_ai/data/services/audio_permission_service.dart';
import 'package:matladu_ai/data/services/local_storage_service.dart';
import 'package:matladu_ai/data/services/translation/on_device_translation_service.dart';
import 'package:matladu_ai/ui/features/home/view_models/home_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _ensureRenderSurface(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: Text(
            'Running Live Microphone Workflow Tests...',
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

  group('Live Microphone ASR & Translation Workflow Integration Tests', () {
    testWidgets('Live Audio Pipeline: Streaming chunks -> Whisper LID -> Transcript -> On-Device Translation', (tester) async {
      await _ensureRenderSurface(tester);

      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final settingsRepo = SettingsRepository(storageService: storage);

      // Explicitly set target language to Telugu
      await settingsRepo.setTargetLanguage(LanguageModel.fromCode('te')!);

      final translationService = OnDeviceTranslationService();
      await translationService.initialize();
      final translationRepo = TranslationRepository(
        translationService: translationService,
        storageService: storage,
      );

      final modelManager = ModelManagerService();
      final asrService = SherpaOnDeviceASRService(
        modelManager: modelManager,
        fallbackService: null,
      );
      await asrService.initialize();

      // Load real speech PCM samples from /data/local/tmp/0.wav
      final wavFile = File('/data/local/tmp/0.wav');
      expect(await wavFile.exists(), isTrue, reason: 'Test speech WAV must exist on emulator.');
      final allBytes = await wavFile.readAsBytes();
      final pcmBytes = allBytes.sublist(44);

      // Verify PCM properties
      final peak = PCMConverter.computePeakAmplitude(pcmBytes);
      final nonZero = PCMConverter.countNonZeroBytes(pcmBytes);
      final rms = PCMConverter.computeRms(pcmBytes);
      final maxWinRms = PCMConverter.computeMaxWindowRms(pcmBytes);

      debugPrint('=== REAL AUDIO METRICS (0.WAV) ===');
      debugPrint('PCM length: ${pcmBytes.length} bytes (${pcmBytes.length ~/ 32} ms)');
      debugPrint('Peak amplitude: $peak / 32767');
      debugPrint('Non-zero bytes: $nonZero / ${pcmBytes.length}');
      debugPrint('RMS: ${rms.toStringAsFixed(6)}');
      debugPrint('Max Window RMS: ${maxWinRms.toStringAsFixed(6)}');
      debugPrint('==================================');

      expect(peak, greaterThan(100), reason: 'Spoken audio must have audible peak amplitude.');
      expect(nonZero, greaterThan(1000), reason: 'Audio must contain non-zero samples.');

      // 1. Simulate real streaming microphone input: emit PCM in 100ms chunks (3200 bytes)
      final streamController = StreamController<Uint8List>.broadcast();
      await asrService.startStreamingRecognition(
        streamController.stream,
        audioConfig: const AudioCaptureConfig(),
        languageCodeHint: 'auto', // Real automatic language identification
      );

      const chunkSize = 3200;
      for (int i = 0; i < pcmBytes.length; i += chunkSize) {
        final end = (i + chunkSize < pcmBytes.length) ? i + chunkSize : pcmBytes.length;
        streamController.add(pcmBytes.sublist(i, end));
        await Future.delayed(const Duration(milliseconds: 10));
      }

      // 2. Stop streaming recognition passing the complete captured buffer
      final aStopwatch = Stopwatch()..start();
      final asrResult = await asrService.stopStreamingRecognition(recordedPcm: pcmBytes);
      aStopwatch.stop();
      await streamController.close();

      debugPrint('=== REAL ASR STREAMING RECOGNITION RESULT ===');
      debugPrint('Recognized Text: "${asrResult.text}"');
      debugPrint('Detected Language: ${asrResult.detectedLanguageCode} (${asrResult.detectedLanguageName})');
      debugPrint('Confidence: ${asrResult.confidence}');
      debugPrint('Latency: ${aStopwatch.elapsedMilliseconds} ms');
      debugPrint('Is Mock: ${asrResult.isMock}');
      debugPrint('Has Error: ${asrResult.hasError}');
      debugPrint('=============================================');

      expect(asrResult.hasError, isFalse);
      expect(asrResult.isMock, isFalse);
      expect(asrResult.hasText, isTrue, reason: 'Whisper must recognize spoken sentence from PCM buffer.');
      expect(asrResult.detectedLanguageCode, 'en', reason: 'English speech must be auto-detected as en.');

      // 3. Translate recognized speech into the selected target language (Telugu)
      final tStopwatch = Stopwatch()..start();
      final translationResult = await translationRepo.translateText(
        text: asrResult.text,
        sourceLanguageCode: asrResult.detectedLanguageCode ?? 'en',
        targetLanguageCode: 'te',
      );
      tStopwatch.stop();

      debugPrint('=== ON-DEVICE TRANSLATION RESULT (ENGLISH -> TELUGU) ===');
      debugPrint('Source: "${translationResult.originalText}" (${translationResult.sourceLanguageCode})');
      debugPrint('Translated: "${translationResult.translatedText}" (${translationResult.targetLanguageCode})');
      debugPrint('Translation Latency: ${tStopwatch.elapsedMilliseconds} ms');
      debugPrint('Status: ${translationResult.status}');
      debugPrint('Is Mock: ${translationResult.isMock}');
      debugPrint('========================================================');

      expect(translationResult.status, TranslationStatus.completed);
      expect(translationResult.isMock, isFalse);
      expect(translationResult.hasText, isTrue);
      // Target language was Telugu and remains Telugu
      expect(translationResult.targetLanguageCode, 'te');
      // Verify Telugu Unicode characters exist in translated text (0x0C00 - 0x0C7F)
      final hasTeluguRunes = translationResult.translatedText.runes.any((r) => r >= 0x0C00 && r <= 0x0C7F);
      expect(hasTeluguRunes, isTrue, reason: 'Translated output must be written in genuine Telugu script.');

      await asrService.dispose();
      await translationService.dispose();
    });

    testWidgets('Preserves user selected target language during auto language detection', (tester) async {
      await _ensureRenderSurface(tester);

      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final settingsRepo = SettingsRepository(storageService: storage);

      // User chose Telugu as target
      final telugu = LanguageModel.fromCode('te')!;
      await settingsRepo.setTargetLanguage(telugu);

      final mockCapture = RecordAudioCaptureService();
      const mockPermission = AudioPermissionService();
      final audioRepo = AudioRepository(captureService: mockCapture, permissionService: mockPermission);

      final modelManager = ModelManagerService();
      final asrService = SherpaOnDeviceASRService(modelManager: modelManager, fallbackService: null);
      await asrService.initialize();

      final asrRepo = ASRRepository(audioRepository: audioRepo, asrService: asrService);

      final translationService = OnDeviceTranslationService();
      await translationService.initialize();
      final translationRepo = TranslationRepository(translationService: translationService, storageService: storage);

      final homeVm = HomeViewModel(
        translationRepository: translationRepo,
        settingsRepository: settingsRepo,
        audioRepository: audioRepo,
        asrRepository: asrRepo,
      );

      // Verify initial state
      expect(homeVm.targetLanguage.code, 'te');

      // Now transcribe English speech
      final wavFile = File('/data/local/tmp/0.wav');
      final allBytes = await wavFile.readAsBytes();
      final pcmBytes = allBytes.sublist(44);

      final result = await asrRepo.transcribeBuffer(pcmBytes, languageCodeHint: 'auto');
      expect(result.detectedLanguageCode, 'en');

      // The user's target language must NOT be modified
      expect(homeVm.targetLanguage.code, 'te', reason: 'User selected target language must remain strictly preserved.');

      await asrService.dispose();
      await translationService.dispose();
    });

    testWidgets('Live Microphone Gating: Digital silence yields empty result; Vocal signal yields speech', (tester) async {
      await _ensureRenderSurface(tester);

      final modelManager = ModelManagerService();
      final asrService = SherpaOnDeviceASRService(modelManager: modelManager, fallbackService: null);
      await asrService.initialize();

      // Test A: Digital silence (all zeroes)
      final silentPcm = Uint8List(32000); // 1 second of zero samples
      final silenceStream = StreamController<Uint8List>();
      await asrService.startStreamingRecognition(
        silenceStream.stream,
        audioConfig: const AudioCaptureConfig(),
        languageCodeHint: 'en',
      );
      silenceStream.add(silentPcm);
      await Future.delayed(const Duration(milliseconds: 30));
      final silenceResult = await asrService.stopStreamingRecognition();
      await silenceStream.close();

      debugPrint('Silence Test: text="${silenceResult.text}", hasText=${silenceResult.hasText}');
      expect(silenceResult.text, isEmpty, reason: 'True digital silence must yield empty transcription.');
      expect(silenceResult.hasError, isFalse);

      // Test B: Vocal speech signal
      final wavFile = File('/data/local/tmp/0.wav');
      final allBytes = await wavFile.readAsBytes();
      final speechPcm = allBytes.sublist(44);

      final speechStream = StreamController<Uint8List>();
      await asrService.startStreamingRecognition(
        speechStream.stream,
        audioConfig: const AudioCaptureConfig(),
        languageCodeHint: 'en',
      );
      speechStream.add(speechPcm);
      await Future.delayed(const Duration(milliseconds: 30));
      final speechResult = await asrService.stopStreamingRecognition(recordedPcm: speechPcm);
      await speechStream.close();

      debugPrint('Speech Test: text="${speechResult.text}", hasText=${speechResult.hasText}');
      expect(speechResult.hasText, isTrue, reason: 'Audible speech must NOT be classified as silence.');
      expect(speechResult.text.isNotEmpty, isTrue);

      await asrService.dispose();
    });
  });
}
