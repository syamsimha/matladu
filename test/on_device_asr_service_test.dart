import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:matladu_ai/data/models/asr_state.dart';
import 'package:matladu_ai/data/models/audio_recording_state.dart';
import 'package:matladu_ai/data/services/asr/mock_asr_service.dart';
import 'package:matladu_ai/data/services/asr/model_manager_service.dart';
import 'package:matladu_ai/data/services/asr/sherpa_on_device_asr_service.dart';

void main() {
  late Directory tempDir;
  late ModelManagerService modelManager;
  late MockASRService mockFallback;
  late SherpaOnDeviceASRService asrService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('matladu_asr_test_');
    modelManager = ModelManagerService(overrideBaseDir: tempDir);
    mockFallback = MockASRService();
    asrService = SherpaOnDeviceASRService(
      modelManager: modelManager,
      fallbackService: mockFallback,
    );
  });

  tearDown(() async {
    await asrService.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SherpaOnDeviceASRService Lifecycle & Streaming Tests', () {
    test('Initializes in idle state with null lastResult', () {
      expect(asrService.currentState, ASRState.idle);
      expect(asrService.lastResult, isNull);
    });

    test('Falls back cleanly when model files are not installed', () async {
      await asrService.initialize();

      final streamController = StreamController<Uint8List>();
      final stateEvents = <ASRState>[];
      final resultEvents = <ASRRecognitionResult>[];

      final sub1 = asrService.stateStream.listen(stateEvents.add);
      final sub2 = asrService.resultStream.listen(resultEvents.add);

      await asrService.startStreamingRecognition(
        streamController.stream,
        audioConfig: const AudioCaptureConfig(),
        languageCodeHint: 'te',
      );

      // Emit simulated 16-bit PCM chunks (5 chunks = 16,000 bytes > 6400 bytes minimum)
      for (int i = 0; i < 5; i++) {
        streamController.add(Uint8List(3200));
      }
      await Future.delayed(const Duration(milliseconds: 60));

      final finalResult = await asrService.stopStreamingRecognition();
      await streamController.close();

      expect(finalResult.isFinal, isTrue);
      expect(finalResult.text.isNotEmpty, isTrue);
      expect(stateEvents, contains(ASRState.listening));

      await sub1.cancel();
      await sub2.cancel();
    });

    test('transcribePcmBuffer produces result without crashing', () async {
      await asrService.initialize();
      final pcmBytes = Uint8List(32000); // 1 sec of audio

      final result = await asrService.transcribePcmBuffer(
        pcmBytes,
        audioConfig: const AudioCaptureConfig(),
        languageCodeHint: 'hi',
      );

      expect(result.isFinal, isTrue);
      expect(result.detectedLanguageCode, 'hi');
    });

    test('cancelRecognition resets state to idle and clears buffers', () async {
      await asrService.initialize();
      final streamController = StreamController<Uint8List>();

      await asrService.startStreamingRecognition(
        streamController.stream,
        audioConfig: const AudioCaptureConfig(),
        languageCodeHint: 'en',
      );

      await asrService.cancelRecognition();
      expect(asrService.currentState, ASRState.idle);

      await streamController.close();
    });

    test('Error handled without fallback emits clear offline pack guidance', () async {
      final strictAsrService = SherpaOnDeviceASRService(
        modelManager: modelManager,
        fallbackService: null, // No fallback permitted
      );

      await strictAsrService.initialize();
      const emptyStream = Stream<Uint8List>.empty();

      await strictAsrService.startStreamingRecognition(
        emptyStream,
        audioConfig: const AudioCaptureConfig(),
        languageCodeHint: 'te',
      );

      expect(strictAsrService.currentState, ASRState.error);
      expect(strictAsrService.lastResult?.hasError, isTrue);
      expect(
        strictAsrService.lastResult?.errorMessage,
        contains('offline pack'),
      );

      await strictAsrService.dispose();
    });
  });
}
