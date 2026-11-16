import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:matladu_ai/data/models/audio_recording_state.dart';
import 'package:matladu_ai/data/models/connection_mode_model.dart';
import 'package:matladu_ai/data/models/language_model.dart';
import 'package:matladu_ai/data/models/two_way_direction.dart';
import 'package:matladu_ai/data/services/asr/online_asr_service.dart';
import 'package:matladu_ai/data/services/asr/pcm_converter.dart';
import 'package:matladu_ai/data/services/engine/engine_selection_manager.dart';
import 'package:matladu_ai/data/services/network_connectivity_service.dart';
import 'package:matladu_ai/data/services/translation/online_translation_service.dart';

class MockNetworkConnectivityService extends NetworkConnectivityService {
  final bool _online;
  MockNetworkConnectivityService(this._online);

  @override
  bool get isValidatedInternet => _online;
}

void main() {
  group('Phase 7 Consolidated Verification — Online Speech & Translation', () {
    test('OnlineASRService rejects silence buffers via RMS silence gating', () async {
      final asr = OnlineASRService();
      await asr.initialize();

      // Silent buffer (all zeros)
      final silentBytes = Uint8List(16000 * 2);
      final result = await asr.transcribePcmBuffer(
        silentBytes,
        audioConfig: const AudioCaptureConfig(),
      );

      expect(result.hasText, isFalse);
      expect(result.errorMessage, contains('No speech detected'));
    });

    test('OnlineASRService honestly reports missing cloud endpoint when not configured', () async {
      // Create OnlineASRService without an endpoint
      final asr = OnlineASRService(cloudEndpointUrl: null);
      await asr.initialize();

      // Audio buffer with genuine signal
      final audioBytes = Uint8List(16000 * 2);
      final byteData = ByteData.sublistView(audioBytes);
      for (int i = 0; i < 16000; i++) {
        // 440 Hz tone
        byteData.setInt16(i * 2, (10000 * (i % 36 == 0 ? 1 : 0)), Endian.little);
      }

      final result = await asr.transcribePcmBuffer(
        audioBytes,
        audioConfig: const AudioCaptureConfig(),
        languageCodeHint: 'en',
      );

      expect(result.hasText, isFalse);
      expect(result.errorMessage, contains('Cloud speech-recognition provider not configured'));
      expect(result.errorMessage, contains('switch to Offline Mode'));
    });

    test('PCMConverter packages raw PCM16 into standard 44-byte RIFF WAV', () {
      final pcmBytes = Uint8List(3200); // 100ms at 16kHz
      final wav = PCMConverter.pcm16ToWav(pcmBytes, sampleRate: 16000, numChannels: 1);

      expect(wav.length, equals(pcmBytes.length + 44));
      // 'RIFF' header
      expect(String.fromCharCodes(wav.sublist(0, 4)), equals('RIFF'));
      // 'WAVE'
      expect(String.fromCharCodes(wav.sublist(8, 12)), equals('WAVE'));
      // 'fmt '
      expect(String.fromCharCodes(wav.sublist(12, 16)), equals('fmt '));
      // 'data'
      expect(String.fromCharCodes(wav.sublist(36, 40)), equals('data'));
    });

    test('OnlineTranslationService validates language and pair support', () {
      final service = OnlineTranslationService();
      expect(service.isLanguageSupported('en'), isTrue);
      expect(service.isLanguageSupported('te'), isTrue);
      expect(service.isLanguageSupported('hi'), isTrue);
      expect(service.isPairSupported('en', 'te'), isTrue);
      expect(service.isPairSupported('te', 'en'), isTrue);
    });
  });

  group('Phase 7 Consolidated Verification — Strict Offline Privacy & Engine Switching', () {
    test('Strict Offline Mode forces on-device engine even when internet is available', () async {
      final connectivity = MockNetworkConnectivityService(true);
      final manager = EngineSelectionManager(
        connectivityService: connectivity,
        initialMode: ConnectionModeType.onDevice,
        autoSwitchEnabled: false,
      );

      final resolution = await manager.resolve(
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );

      expect(resolution.isFullyOffline, isTrue);
      expect(resolution.isOnlineRequired, isFalse);
      expect(resolution.asrEngine, isNot(equals(EngineType.onlineCloud)));
      expect(resolution.translationEngine, isNot(equals(EngineType.onlineCloud)));
    });

    test('Online mode with internet connected routes translation to cloud while ASR runs on-device', () async {
      final connectivity = MockNetworkConnectivityService(true);
      final manager = EngineSelectionManager(
        connectivityService: connectivity,
        initialMode: ConnectionModeType.cloudAi,
        autoSwitchEnabled: false,
      );

      final resolution = await manager.resolve(
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );

      expect(resolution.asrEngine, equals(EngineType.onDevice));
      expect(resolution.translationEngine, equals(EngineType.onlineCloud));
      expect(resolution.statusTitle, equals('Online - Cloud Translation'));
      expect(resolution.statusDescription, contains('Zero audio upload'));
    });

    test('Offline mode when disconnected reports Offline Ready with 100% on-device processing', () async {
      final connectivity = MockNetworkConnectivityService(false);
      final manager = EngineSelectionManager(
        connectivityService: connectivity,
        initialMode: ConnectionModeType.onDevice,
        autoSwitchEnabled: false,
      );

      final resolution = await manager.resolve(
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );

      expect(resolution.isReady, isTrue);
      expect(resolution.asrEngine, equals(EngineType.onDevice));
      expect(resolution.translationEngine, equals(EngineType.onDevice));
      expect(resolution.statusTitle, equals('Offline - Ready'));
    });
  });

  group('Phase 7 Consolidated Verification — Automatic Language Direction', () {
    const langEn = LanguageModel(code: 'en', name: 'English', nativeName: 'English');
    const langTe = LanguageModel(code: 'te', name: 'Telugu', nativeName: 'తెలుగు');

    test('English detected speech sets EN -> TE direction and prepares TE next', () {
      final directionManager = TwoWayDirectionManager(
        languageA: langEn,
        languageB: langTe,
      );

      final result = directionManager.resolve(detectedLanguageCode: 'en');
      expect(result.sourceLanguage.code, equals('en'));
      expect(result.targetLanguage.code, equals('te'));
      expect(result.canTranslate, isTrue);
      expect(result.isOutsidePair, isFalse);
      expect(directionManager.preferAtoB, isFalse); // Anticipates next speaker is B (Telugu)
    });

    test('Telugu detected speech sets TE -> EN direction and prepares EN next', () {
      final directionManager = TwoWayDirectionManager(
        languageA: langEn,
        languageB: langTe,
      );

      final result = directionManager.resolve(detectedLanguageCode: 'te');
      expect(result.sourceLanguage.code, equals('te'));
      expect(result.targetLanguage.code, equals('en'));
      expect(result.canTranslate, isTrue);
      expect(result.isOutsidePair, isFalse);
      expect(directionManager.preferAtoB, isTrue); // Anticipates next speaker is A (English)
    });

    test('Language outside active pair (e.g. Hindi) is rejected without silent guessing', () {
      final directionManager = TwoWayDirectionManager(
        languageA: langEn,
        languageB: langTe,
      );

      final result = directionManager.resolve(detectedLanguageCode: 'hi');
      expect(result.canTranslate, isFalse);
      expect(result.isOutsidePair, isTrue);
      expect(result.warningMessage, contains('Detected Hindi, which is outside the active'));
    });
  });
}
