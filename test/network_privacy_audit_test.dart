import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:matladu_ai/data/models/audio_recording_state.dart';
import 'package:matladu_ai/data/models/connection_mode_model.dart';
import 'package:matladu_ai/data/services/asr/hybrid_asr_service.dart';
import 'package:matladu_ai/data/services/asr/model_manager_service.dart';
import 'package:matladu_ai/data/services/asr/online_asr_service.dart';
import 'package:matladu_ai/data/services/asr/sherpa_on_device_asr_service.dart';
import 'package:matladu_ai/data/services/engine/engine_selection_manager.dart';
import 'package:matladu_ai/data/services/network_connectivity_service.dart';
import 'package:matladu_ai/data/services/translation/hybrid_translation_service.dart';
import 'package:matladu_ai/data/services/translation/on_device_translation_service.dart';
import 'package:matladu_ai/data/services/translation/online_translation_service.dart';

class NetworkCallRecorder extends HttpOverrides {
  final List<Uri> interceptedUris = [];

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _RecordingHttpClient(this);
  }
}

class _RecordingHttpClient implements HttpClient {
  final NetworkCallRecorder recorder;
  _RecordingHttpClient(this.recorder);

  @override
  Duration? connectionTimeout;

  @override
  void close({bool force = false}) {}

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    recorder.interceptedUris.add(url);
    throw const SocketException('Network blocked during privacy assertion');
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    recorder.interceptedUris.add(url);
    throw const SocketException('Network blocked during privacy assertion');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockConnectedService extends NetworkConnectivityService {
  @override
  bool get isValidatedInternet => true;
}

class MockDisconnectedService extends NetworkConnectivityService {
  @override
  bool get isValidatedInternet => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Matladu Phase 8 Strict Network Privacy & Egress Verification', () {
    test('Zero network requests during Offline Mode translation even with internet active', () async {
      final recorder = NetworkCallRecorder();
      await HttpOverrides.runWithHttpOverrides(() async {
        final onDeviceService = OnDeviceTranslationService();
        await onDeviceService.initialize();

        final onlineService = OnlineTranslationService();
        await onlineService.initialize();

        final connectivity = MockConnectedService();
        final engineManager = EngineSelectionManager(
          connectivityService: connectivity,
          initialMode: ConnectionModeType.onDevice, // Explicit Offline Mode
        );

        final hybrid = HybridTranslationService(
          onDeviceService: onDeviceService,
          onlineService: onlineService,
          engineSelectionManager: engineManager,
        );
        await hybrid.initialize();

        final result = await hybrid.translate(
          text: 'Hello, how are you?',
          sourceLanguageCode: 'en',
          targetLanguageCode: 'te',
        );

        expect(result.originalText, equals('Hello, how are you?'));
        // STRICT PRIVACY ASSERTION: EXACTLY ZERO HTTP REQUESTS IN OFFLINE MODE
        expect(recorder.interceptedUris, isEmpty,
            reason: 'Zero HTTP requests may occur in Offline Mode; all translation must stay on-device.');
      }, recorder);
    });

    test('Zero network requests during ASR speech processing in every mode (zero audio egress)', () async {
      final recorder = NetworkCallRecorder();
      await HttpOverrides.runWithHttpOverrides(() async {
        final modelManager = ModelManagerService();
        final onDeviceAsr = SherpaOnDeviceASRService(modelManager: modelManager);
        await onDeviceAsr.initialize();

        final onlineAsr = OnlineASRService();
        await onlineAsr.initialize();

        final connectivity = MockConnectedService();
        final engineManager = EngineSelectionManager(
          connectivityService: connectivity,
          initialMode: ConnectionModeType.cloudAi, // Online Mode
        );

        final hybrid = HybridASRService(
          onDeviceService: onDeviceAsr,
          onlineService: onlineAsr,
          engineSelectionManager: engineManager,
        );
        await hybrid.initialize();

        // Audio sample buffer
        final audioBuffer = Uint8List(16000 * 2);
        await hybrid.transcribePcmBuffer(
          audioBuffer,
          audioConfig: const AudioCaptureConfig(),
          languageCodeHint: 'en',
        );

        // STRICT PRIVACY ASSERTION: ZERO AUDIO OR TRANSCRIPT EGRESS
        expect(recorder.interceptedUris, isEmpty,
            reason: 'Audio buffers must never trigger network egress in any mode.');
      }, recorder);
    });

    test('Online Mode transmits text query only with zero audio egress and proper parameterization', () async {
      final recorder = NetworkCallRecorder();
      await HttpOverrides.runWithHttpOverrides(() async {
        final onDeviceService = OnDeviceTranslationService();
        await onDeviceService.initialize();

        final onlineService = OnlineTranslationService();
        await onlineService.initialize();

        final connectivity = MockConnectedService();
        final engineManager = EngineSelectionManager(
          connectivityService: connectivity,
          initialMode: ConnectionModeType.cloudAi, // Online Mode
        );

        final hybrid = HybridTranslationService(
          onDeviceService: onDeviceService,
          onlineService: onlineService,
          engineSelectionManager: engineManager,
        );
        await hybrid.initialize();

        await hybrid.translate(
          text: 'Hello, how are you?',
          sourceLanguageCode: 'en',
          targetLanguageCode: 'te',
        );

        // Verification: Exactly 1 HTTP GET request to MyMemory API with text query parameter
        expect(recorder.interceptedUris.length, equals(1));
        final uri = recorder.interceptedUris.first;
        expect(uri.host, equals('api.mymemory.translated.net'));
        expect(uri.queryParameters['q'], equals('Hello, how are you?'));
        expect(uri.queryParameters['langpair'], equals('en|te'));
        expect(uri.queryParameters['de'], equals('support@matladu.app'));
        // Verify no audio or binary data in URL
        expect(uri.toString().contains('pcm'), isFalse);
        expect(uri.toString().contains('wav'), isFalse);
        expect(uri.toString().contains('audio'), isFalse);
      }, recorder);
    });

    test('EngineSelectionManager properly resolves Online, Offline, and Automatic modes', () async {
      final connectivity = MockConnectedService();
      final engineManager = EngineSelectionManager(
        connectivityService: connectivity,
        initialMode: ConnectionModeType.cloudAi,
      );

      // 1. Online Mode with internet
      final onlineRes = await engineManager.resolve(
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );
      expect(onlineRes.statusTitle, contains('Online - Cloud Translation'));
      expect(onlineRes.asrEngine, equals(EngineType.onDevice));
      expect(onlineRes.translationEngine, equals(EngineType.onlineCloud));
      expect(onlineRes.ttsEngine, equals(EngineType.onDevice));

      // 2. Offline Mode
      engineManager.setUserMode(ConnectionModeType.onDevice);
      final offlineRes = await engineManager.resolve(
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );
      expect(offlineRes.statusTitle, equals('Offline - Ready'));
      expect(offlineRes.asrEngine, equals(EngineType.onDevice));
      expect(offlineRes.translationEngine, equals(EngineType.onDevice));

      // 3. Automatic Mode with internet
      engineManager.setUserMode(ConnectionModeType.automatic);
      final autoRes = await engineManager.resolve(
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );
      expect(autoRes.statusTitle, contains('Auto - Online Translation'));
      expect(autoRes.asrEngine, equals(EngineType.onDevice));
      expect(autoRes.translationEngine, equals(EngineType.onlineCloud));
    });
  });
}
