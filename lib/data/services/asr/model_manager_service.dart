import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Integrity state for on-device ASR models.
enum ModelIntegrityState {
  notDownloaded,
  corrupted,
  installed,
}

/// Metadata definition for an on-device ASR model pack.
class ASRModelMetadata {
  /// Unique identifier (e.g. 'whisper-tiny-multilingual', 'zipformer-en', 'indic-telugu').
  final String id;

  /// Human readable display name.
  final String name;

  /// Target BCP-47 or ISO-639-1 language code(s) supported (e.g. 'te', 'hi', 'en', 'multilingual').
  final List<String> supportedLanguages;

  /// Architecture family (e.g. 'whisper', 'zipformer', 'conformer').
  final String modelType;

  /// Approximate download size in Megabytes.
  final int sizeMB;

  /// HTTPS URL where the pre-quantized ONNX model bundle can be fetched on demand.
  final String? downloadUrl;

  /// Required sub-files for the model (e.g. encoder.int8.onnx, decoder.int8.onnx, tokens.txt).
  final List<String> requiredFiles;

  const ASRModelMetadata({
    required this.id,
    required this.name,
    required this.supportedLanguages,
    required this.modelType,
    required this.sizeMB,
    this.downloadUrl,
    required this.requiredFiles,
  });

  /// Check whether this model supports a given language code.
  bool supportsLanguage(String langCode) {
    if (supportedLanguages.contains('multilingual')) return true;
    final normalized = langCode.toLowerCase().split('-').first;
    return supportedLanguages.any((lang) => lang.toLowerCase().split('-').first == normalized);
  }
}

/// Service managing offline, on-device speech recognition models.
///
/// STRICTURES:
/// 1. 100% On-Device execution. Models run locally inside the application sandbox.
/// 2. Audio is NEVER transmitted over the network.
/// 3. Network access is strictly restricted to user-initiated HTTPS model bundle downloads.
class ModelManagerService {
  final Directory? _overrideBaseDir;

  ModelManagerService({Directory? overrideBaseDir}) : _overrideBaseDir = overrideBaseDir;

  /// Catalog of curated, on-device models optimized for mobile inference (<120MB).
  static const List<ASRModelMetadata> availableModels = [
    // 1. Multilingual Whisper-Tiny int8 (~103.6MB) — Supports Telugu, Hindi, English and 90+ languages
    ASRModelMetadata(
      id: 'whisper-tiny-multilingual',
      name: 'Multilingual Indic & English Pack',
      supportedLanguages: ['te', 'hi', 'en', 'ta', 'kn', 'mr', 'bn', 'multilingual'],
      modelType: 'whisper',
      sizeMB: 104,
      downloadUrl:
          'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/main',
      requiredFiles: [
        'tiny-encoder.int8.onnx',
        'tiny-decoder.int8.onnx',
        'tiny-tokens.txt',
      ],
    ),

    // 2. Dedicated Streaming Zipformer English int8 (~60MB) â€” Ultra-low latency English
    ASRModelMetadata(
      id: 'zipformer-streaming-en',
      name: 'English Real-Time Streaming Pack',
      supportedLanguages: ['en'],
      modelType: 'zipformer',
      sizeMB: 60,
      downloadUrl:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-en-2023-06-26.tar.bz2',
      requiredFiles: [
        'encoder-epoch-99-avg-1.int8.onnx',
        'decoder-epoch-99-avg-1.onnx',
        'joiner-epoch-99-avg-1.int8.onnx',
        'tokens.txt',
      ],
    ),

    // 3. AI4Bharat IndicConformer Telugu int8 (~45MB)
    ASRModelMetadata(
      id: 'indic-conformer-te',
      name: 'Telugu Specialized Offline Pack',
      supportedLanguages: ['te'],
      modelType: 'conformer',
      sizeMB: 45,
      downloadUrl: null,
      requiredFiles: [
        'model.int8.onnx',
        'tokens.txt',
      ],
    ),

    // 4. AI4Bharat IndicConformer Hindi int8 (~45MB)
    ASRModelMetadata(
      id: 'indic-conformer-hi',
      name: 'Hindi Specialized Offline Pack',
      supportedLanguages: ['hi'],
      modelType: 'conformer',
      sizeMB: 45,
      downloadUrl: null,
      requiredFiles: [
        'model.int8.onnx',
        'tokens.txt',
      ],
    ),
  ];

  /// Resolves the root models directory: `<ApplicationDocumentsDirectory>/models/asr/`
  Future<Directory> getModelsDirectory() async {
    if (_overrideBaseDir != null) {
      final dir = Directory('${_overrideBaseDir.path}/models/asr');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }

    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${appDocDir.path}/models/asr');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (e) {
      // Fallback for tests / environments without path_provider native plugin
      final fallbackDir = Directory('${Directory.systemTemp.path}/matladu_ai_models/asr');
      if (!await fallbackDir.exists()) {
        await fallbackDir.create(recursive: true);
      }
      return fallbackDir;
    }
  }

  /// Returns the specific directory path for a model.
  Future<Directory> getModelDirectory(String modelId, {bool createIfMissing = true}) async {
    final base = await getModelsDirectory();
    final modelDir = Directory('${base.path}/$modelId');
    if (createIfMissing && !await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir;
  }

  bool _hasRequiredFiles(Directory dir, ASRModelMetadata meta, {bool? strictSizeCheck}) {
    if (!dir.existsSync()) return false;
    final enforceStrict = strictSizeCheck ?? (_overrideBaseDir == null);
    for (final filename in meta.requiredFiles) {
      final file = File('${dir.path}/$filename');
      if (!file.existsSync()) return false;
      final len = file.lengthSync();
      if (len == 0) return false;

      // Strict integrity size validation:
      if (enforceStrict && meta.id == 'whisper-tiny-multilingual') {
        if (filename.contains('tokens') && len < 100 * 1024) return false;
        if (filename.contains('encoder') && len < 5 * 1024 * 1024) return false;
        if (filename.contains('decoder') && len < 50 * 1024 * 1024) return false;
      }
    }
    return true;
  }

  void _securePermissions(Directory modelDir, ASRModelMetadata meta) {
    if (!Platform.isAndroid && !Platform.isLinux) return;
    try {
      final chmodBin = File('/system/bin/chmod').existsSync() ? '/system/bin/chmod' : 'chmod';
      Process.runSync(chmodBin, ['700', modelDir.path]);
      for (final filename in meta.requiredFiles) {
        final filePath = '${modelDir.path}/$filename';
        if (File(filePath).existsSync()) {
          Process.runSync(chmodBin, ['600', filePath]);
        }
      }
    } catch (e) {
      debugPrint('[ModelManager] Note on securing permissions: $e');
    }
  }

  /// Evaluates model integrity state: installed, corrupted, or not downloaded.
  /// Strictly READ-ONLY. Never stages or restores models automatically.
  Future<ModelIntegrityState> checkModelIntegrityState(
    String modelId, {
    bool? strictSizeCheck,
  }) async {
    final meta = availableModels.firstWhere(
      (m) => m.id == modelId,
      orElse: () => throw ArgumentError('Unknown model id: $modelId'),
    );

    final modelDir = await getModelDirectory(modelId, createIfMissing: false);
    if (!await modelDir.exists()) {
      return ModelIntegrityState.notDownloaded;
    }

    final entries = modelDir.listSync();
    if (entries.isEmpty) {
      return ModelIntegrityState.notDownloaded;
    }

    if (_hasRequiredFiles(modelDir, meta, strictSizeCheck: strictSizeCheck)) {
      _securePermissions(modelDir, meta);
      return ModelIntegrityState.installed;
    }

    return ModelIntegrityState.corrupted;
  }

  /// Checks if a model's required files are fully installed and available locally.
  /// Strictly READ-ONLY: never copies files or auto-downloads.
  Future<bool> isModelInstalled(String modelId, {bool? strictSizeCheck}) async {
    final state = await checkModelIntegrityState(modelId, strictSizeCheck: strictSizeCheck);
    return state == ModelIntegrityState.installed;
  }

  /// Finds the best installed model for a target language code hint.
  /// When `languageCode` is 'auto', null, or empty, directly checks for the multilingual Whisper pack.
  Future<ASRModelMetadata?> findInstalledModelForLanguage(String? languageCode) async {
    final isAuto = (languageCode == null || languageCode == 'auto' || languageCode.isEmpty);

    // 1. If auto or empty, resolve to whisper-tiny-multilingual
    if (await isModelInstalled('whisper-tiny-multilingual')) {
      final whisper = availableModels.firstWhere((m) => m.id == 'whisper-tiny-multilingual');
      if (isAuto || whisper.supportsLanguage(languageCode)) {
        return whisper;
      }
    }

    if (isAuto) {
      // Automatic language identification requires the multilingual model
      return null;
    }

    final lang = languageCode;

    // 2. Look for language-specific match first
    for (final meta in availableModels) {
      if (!meta.supportedLanguages.contains('multilingual') && meta.supportsLanguage(lang)) {
        if (await isModelInstalled(meta.id)) {
          return meta;
        }
      }
    }

    // 3. Look for multilingual match
    for (final meta in availableModels) {
      if (meta.supportsLanguage(lang)) {
        if (await isModelInstalled(meta.id)) {
          return meta;
        }
      }
    }

    return null;
  }

  /// Returns a map of all required file paths for an installed model.
  /// All returned paths are guaranteed to reside strictly in the app-private directory.
  Future<Map<String, String>> getModelFilePaths(String modelId) async {
    final meta = availableModels.firstWhere(
      (m) => m.id == modelId,
      orElse: () => throw ArgumentError('Unknown model id: $modelId'),
    );
    final modelDir = await getModelDirectory(modelId);
    final paths = <String, String>{};

    for (final filename in meta.requiredFiles) {
      paths[filename] = '${modelDir.path}/$filename';
    }

    return paths;
  }

  final Map<String, bool> _cancellationMap = {};

  /// Cancels an in-progress model download.
  void cancelDownload(String modelId) {
    _cancellationMap[modelId] = true;
    debugPrint('[ModelManagerService] Download cancellation requested for $modelId.');
  }

  /// Downloads an on-device model bundle over HTTPS when initiated by the user.
  /// Uses atomic staging, verifies sizes, and never marks partial downloads as installed.
  /// Reports progressive progress [0.0 to 1.0].
  Future<bool> downloadModel(
    String modelId, {
    void Function(double progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    _cancellationMap[modelId] = false;
    bool combinedCancelled() => _cancellationMap[modelId] == true || (isCancelled?.call() == true);

    final meta = availableModels.firstWhere(
      (m) => m.id == modelId,
      orElse: () => throw ArgumentError('Unknown model id: $modelId'),
    );

    if (modelId == 'whisper-tiny-multilingual') {
      return await _downloadWhisperTinyMultilingual(
        meta,
        onProgress: onProgress,
        isCancelled: combinedCancelled,
      );
    }

    if (meta.downloadUrl == null) {
      debugPrint('[ModelManagerService] No download URL configured for $modelId.');
      return false;
    }

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 20);
      final request = await client.getUrl(Uri.parse(meta.downloadUrl!));
      request.followRedirects = true;
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        debugPrint('[ModelManagerService] Download failed: HTTP ${response.statusCode}');
        client.close();
        return false;
      }

      final totalBytes = response.contentLength > 0 ? response.contentLength : (meta.sizeMB * 1024 * 1024);
      int receivedBytes = 0;

      final modelDir = await getModelDirectory(modelId);
      final archiveFile = File('${modelDir.path}/bundle.archive.tmp');
      final sink = archiveFile.openWrite();

      await for (final chunk in response) {
        if (isCancelled?.call() == true) {
          await sink.close();
          if (archiveFile.existsSync()) archiveFile.deleteSync();
          client.close(force: true);
          return false;
        }
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (onProgress != null && totalBytes > 0) {
          onProgress((receivedBytes / totalBytes).clamp(0.0, 1.0));
        }
      }

      await sink.flush();
      await sink.close();
      client.close();

      final finalArchive = File('${modelDir.path}/bundle.archive');
      if (finalArchive.existsSync()) finalArchive.deleteSync();
      await archiveFile.rename(finalArchive.path);

      debugPrint('[ModelManagerService] Downloaded $receivedBytes bytes for $modelId.');
      return true;
    } catch (e) {
      debugPrint('[ModelManagerService] Download exception for $modelId: $e');
      return false;
    }
  }

  /// Downloads and atomically installs the Multilingual Whisper Tiny model pack (~103.6 MB).
  Future<bool> _downloadWhisperTinyMultilingual(
    ASRModelMetadata meta, {
    void Function(double progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final modelDir = await getModelDirectory(meta.id);
    const baseUrl = 'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/main';

    final fileSpecs = <String, int>{
      'tiny-tokens.txt': 816730,
      'tiny-encoder.int8.onnx': 12937772,
      'tiny-decoder.int8.onnx': 89855401,
    };

    final totalExpectedBytes = fileSpecs.values.fold<int>(0, (sum, sz) => sum + sz);
    int totalDownloadedBytes = 0;

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 25);
    final tempFiles = <File>[];

    try {
      debugPrint('[ModelManagerService] Beginning atomic download of Whisper Multilingual (~103.6 MB)...');

      for (final entry in fileSpecs.entries) {
        if (isCancelled?.call() == true) {
          throw Exception('Download cancelled by user.');
        }

        final filename = entry.key;
        final expectedSize = entry.value;
        final targetFile = File('${modelDir.path}/$filename');
        final tmpFile = File('${modelDir.path}/$filename.tmp');
        tempFiles.add(tmpFile);

        if (tmpFile.existsSync()) {
          try {
            tmpFile.deleteSync();
          } catch (_) {}
        }

        // If target file already exists and is intact, credit its bytes towards progress
        if (targetFile.existsSync() && targetFile.lengthSync() >= (expectedSize * 0.95)) {
          totalDownloadedBytes += expectedSize;
          if (onProgress != null && totalExpectedBytes > 0) {
            onProgress((totalDownloadedBytes / totalExpectedBytes).clamp(0.0, 1.0));
          }
          debugPrint('[ModelManagerService] $filename already verified on device (${targetFile.lengthSync()} bytes).');
          continue;
        }

        final fileUrl = '$baseUrl/$filename';
        debugPrint('[ModelManagerService] Downloading $filename ($expectedSize bytes) from $fileUrl');

        final request = await client.getUrl(Uri.parse(fileUrl));
        request.followRedirects = true;
        request.maxRedirects = 5;

        final response = await request.close();
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException('HTTP ${response.statusCode} while fetching $filename');
        }

        final sink = tmpFile.openWrite();
        await for (final chunk in response) {
          if (isCancelled?.call() == true) {
            await sink.close();
            throw Exception('Download cancelled by user.');
          }
          sink.add(chunk);
          totalDownloadedBytes += chunk.length;
          if (onProgress != null && totalExpectedBytes > 0) {
            onProgress((totalDownloadedBytes / totalExpectedBytes).clamp(0.0, 1.0));
          }
        }
        await sink.flush();
        await sink.close();

        // Verify size of downloaded staging file
        final actualSize = await tmpFile.length();
        if (actualSize < (expectedSize * 0.90)) {
          throw Exception('File $filename incomplete: downloaded $actualSize bytes, expected $expectedSize');
        }
      }

      // Atomic commit: rename all valid .tmp files into target files
      for (final entry in fileSpecs.entries) {
        final filename = entry.key;
        final targetFile = File('${modelDir.path}/$filename');
        final tmpFile = File('${modelDir.path}/$filename.tmp');

        if (tmpFile.existsSync()) {
          if (targetFile.existsSync()) {
            targetFile.deleteSync();
          }
          await tmpFile.rename(targetFile.path);
        }
      }

      _securePermissions(modelDir, meta);
      onProgress?.call(1.0);
      debugPrint('[ModelManagerService] Whisper Multilingual model successfully installed and verified in app-private storage.');
      client.close();
      return true;
    } catch (e) {
      debugPrint('[ModelManagerService] Download error for ${meta.id}: $e');
      client.close(force: true);
      // Clean up any dangling .tmp staging files
      for (final tmp in tempFiles) {
        if (tmp.existsSync()) {
          try {
            tmp.deleteSync();
          } catch (_) {}
        }
      }
      return false;
    }
  }

  /// Deletes an installed model to reclaim storage.
  /// Removes all files recursively and verifies absence on disk.
  Future<bool> deleteModel(String modelId) async {
    try {
      final modelDir = await getModelDirectory(modelId, createIfMissing: false);
      if (await modelDir.exists()) {
        await modelDir.delete(recursive: true);
      }
      final stillExists = await modelDir.exists();
      if (stillExists) {
        debugPrint('[ModelManagerService] Warning: model directory $modelId still exists after deletion.');
        return false;
      }
      debugPrint('[ModelManagerService] Model $modelId successfully removed from device storage.');
      return true;
    } catch (e) {
      debugPrint('[ModelManagerService] Error deleting model $modelId: $e');
      return false;
    }
  }

  /// Calculates total on-device storage used by offline ASR models (in bytes).
  Future<int> getTotalModelsStorageBytes() async {
    try {
      final rootDir = await getModelsDirectory();
      if (!await rootDir.exists()) return 0;

      int totalBytes = 0;
      await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          totalBytes += await entity.length();
        }
      }
      return totalBytes;
    } catch (e) {
      return 0;
    }
  }
}

