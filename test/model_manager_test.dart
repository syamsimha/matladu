import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:matladu_ai/data/services/asr/model_manager_service.dart';

void main() {
  late Directory tempDir;
  late ModelManagerService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('matladu_test_models_');
    service = ModelManagerService(overrideBaseDir: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ModelManagerService Tests', () {
    test('availableModels includes Whisper Tiny and Streaming Zipformer', () {
      const models = ModelManagerService.availableModels;
      expect(models.isNotEmpty, isTrue);

      final whisper = models.firstWhere((m) => m.id == 'whisper-tiny-multilingual');
      expect(whisper.supportsLanguage('te'), isTrue);
      expect(whisper.supportsLanguage('hi'), isTrue);
      expect(whisper.supportsLanguage('en'), isTrue);
      expect(whisper.sizeMB, lessThan(120));

      final zipformer = models.firstWhere((m) => m.id == 'zipformer-streaming-en');
      expect(zipformer.supportsLanguage('en'), isTrue);
      expect(zipformer.supportsLanguage('te'), isFalse);
    });

    test('isModelInstalled returns false when model files are missing', () async {
      final installed = await service.isModelInstalled('whisper-tiny-multilingual');
      expect(installed, isFalse);
    });

    test('isModelInstalled returns true when all required files exist', () async {
      final modelMeta = ModelManagerService.availableModels.firstWhere(
        (m) => m.id == 'indic-conformer-te',
      );
      final modelDir = await service.getModelDirectory(modelMeta.id);

      for (final filename in modelMeta.requiredFiles) {
        final file = File('${modelDir.path}/$filename');
        await file.writeAsString('test binary content');
      }

      final installed = await service.isModelInstalled(modelMeta.id);
      expect(installed, isTrue);

      final found = await service.findInstalledModelForLanguage('te');
      expect(found, isNotNull);
      expect(found!.id, 'indic-conformer-te');
    });

    test('deleteModel removes model directory from device storage', () async {
      final modelDir = await service.getModelDirectory('indic-conformer-te');
      final file = File('${modelDir.path}/model.int8.onnx');
      await file.writeAsString('test content');

      expect(await file.exists(), isTrue);

      final deleted = await service.deleteModel('indic-conformer-te');
      expect(deleted, isTrue);
      expect(await file.exists(), isFalse);
    });

    test('getTotalModelsStorageBytes computes on-device storage accurately', () async {
      final modelDir = await service.getModelDirectory('test-model');
      final file = File('${modelDir.path}/test.bin');
      await file.writeAsBytes(List.generate(1024, (i) => i % 256));

      final totalBytes = await service.getTotalModelsStorageBytes();
      expect(totalBytes, greaterThanOrEqualTo(1024));
    });
  });
}

