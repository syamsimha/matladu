import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:matladu_ai/data/models/audio_recording_state.dart';
import 'package:matladu_ai/data/services/asr/model_manager_service.dart';
import 'package:matladu_ai/data/services/asr/sherpa_on_device_asr_service.dart';

Future<void> _ensureRenderSurface(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: Text(
            'Running On-Device Native ASR Tests...',
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

  group('On-Device Native ASR Inference Integration Tests', () {
    testWidgets('Performs real on-device Whisper inference on Android runtime', (tester) async {
      await _ensureRenderSurface(tester);
      final modelManager = ModelManagerService();
      final asrService = SherpaOnDeviceASRService(
        modelManager: modelManager,
        fallbackService: null, // STRICT: 0 Mock fallback allowed
      );

      final initStopwatch = Stopwatch()..start();
      await asrService.initialize();
      initStopwatch.stop();

      // Verify that model is installed
      final isInstalled = await modelManager.isModelInstalled('whisper-tiny-multilingual');
      expect(isInstalled, isTrue, reason: 'Whisper Tiny Multilingual model files must be in application documents.');

      // Load test audio PCM from /data/local/tmp/0.wav
      final wavFile = File('/data/local/tmp/0.wav');
      expect(await wavFile.exists(), isTrue, reason: '0.wav must exist on emulator.');
      final allBytes = await wavFile.readAsBytes();
      // Skip 44-byte standard RIFF WAV header to get raw 16-bit PCM samples
      final pcmBytes = allBytes.sublist(44);

      final inferStopwatch = Stopwatch()..start();
      final result = await asrService.transcribePcmBuffer(
        pcmBytes,
        audioConfig: const AudioCaptureConfig(),
        languageCodeHint: 'en',
      );
      inferStopwatch.stop();

      debugPrint('=== REAL ON-DEVICE INFERENCE METRICS (ENGLISH 0.WAV) ===');
      debugPrint('Model initialization time: ${initStopwatch.elapsedMilliseconds} ms');
      debugPrint('Inference execution time: ${inferStopwatch.elapsedMilliseconds} ms');
      debugPrint('Audio byte length: ${pcmBytes.length} bytes');
      debugPrint('Recognized text: "${result.text}"');
      debugPrint('Detected language code: "${result.detectedLanguageCode}"');
      debugPrint('Is Mock flag: ${result.isMock}');
      debugPrint('Confidence score: ${result.confidence}');
      debugPrint('Has Error: ${result.hasError}');
      debugPrint('========================================================');

      expect(result.isMock, isFalse, reason: 'Inference must be produced by real on-device ONNX engine, never mock.');
      expect(result.hasError, isFalse, reason: 'Inference must succeed without error.');
      expect(result.text, contains('brothels'));

      await asrService.dispose();
    });

    testWidgets('Performs real on-device Automatic Spoken Language Identification (SLID)', (tester) async {
      await _ensureRenderSurface(tester);
      final modelManager = ModelManagerService();
      final asrService = SherpaOnDeviceASRService(
        modelManager: modelManager,
        fallbackService: null, // STRICT: 0 Mock fallback allowed
      );

      await asrService.initialize();

      // Load test audio PCM from /data/local/tmp/1.wav
      final wavFile = File('/data/local/tmp/1.wav');
      expect(await wavFile.exists(), isTrue, reason: '1.wav must exist on emulator.');
      final allBytes = await wavFile.readAsBytes();
      final pcmBytes = allBytes.sublist(44);

      final inferStopwatch = Stopwatch()..start();
      // Pass null to test real Automatic Language Identification (Whisper SLID)
      final result = await asrService.transcribePcmBuffer(
        pcmBytes,
        audioConfig: const AudioCaptureConfig(),
        languageCodeHint: null,
      );
      inferStopwatch.stop();

      debugPrint('=== REAL ON-DEVICE SLID & INFERENCE METRICS (1.WAV) ===');
      debugPrint('Inference execution time: ${inferStopwatch.elapsedMilliseconds} ms');
      debugPrint('Audio byte length: ${pcmBytes.length} bytes');
      debugPrint('Recognized text: "${result.text}"');
      debugPrint('Auto-detected language code: "${result.detectedLanguageCode}"');
      debugPrint('Auto-detected language name: "${result.detectedLanguageName}"');
      debugPrint('Is Mock flag: ${result.isMock}');
      debugPrint('Has Error: ${result.hasError}');
      debugPrint('=======================================================');

      expect(result.isMock, isFalse);
      expect(result.hasError, isFalse);
      expect(result.detectedLanguageCode, 'en');
      expect(result.text.isNotEmpty, isTrue);

      await asrService.dispose();
    });

    testWidgets('Silence gating prevents Whisper hallucination on silent audio', (tester) async {
      await _ensureRenderSurface(tester);
      final modelManager = ModelManagerService();
      final asrService = SherpaOnDeviceASRService(
        modelManager: modelManager,
        fallbackService: null,
      );

      await asrService.initialize();
      // Generate 2 seconds of zeroed PCM samples (pure digital silence)
      final silentPcm = Uint8List(64000);
      final streamController = StreamController<Uint8List>();

      await asrService.startStreamingRecognition(
        streamController.stream,
        audioConfig: const AudioCaptureConfig(),
        languageCodeHint: 'en',
      );

      streamController.add(silentPcm);
      await Future.delayed(const Duration(milliseconds: 50));
      final result = await asrService.stopStreamingRecognition();
      await streamController.close();

      debugPrint('=== REAL SILENCE GATING RESULT ===');
      debugPrint('Result text: "${result.text}" (Expected: empty)');
      debugPrint('Is Mock: ${result.isMock}');
      debugPrint('==================================');

      expect(result.text, isEmpty);
      expect(result.isMock, isFalse);
      expect(result.hasError, isFalse);

      await asrService.dispose();
    });
  });
}
