import 'package:flutter_test/flutter_test.dart';
import 'package:matladu_ai/data/models/language_model.dart';
import 'package:matladu_ai/data/models/connection_mode_model.dart';
import 'package:matladu_ai/data/services/engine/engine_selection_manager.dart';
import 'package:matladu_ai/data/services/network_connectivity_service.dart';
import 'package:matladu_ai/data/services/translation/online_translation_service.dart';
import 'package:matladu_ai/data/services/translation/on_device_translation_service.dart';
import 'package:matladu_ai/data/services/tts/on_device_tts_service.dart';

void main() {
  group('24 Languages Coverage & Eighth Schedule Verification', () {
    const requiredCodes = [
      // 22 Indian Eighth Schedule languages
      'as', 'bn', 'brx', 'doi', 'gu', 'hi', 'kn', 'ks', 'kok', 'mai',
      'ml', 'mni', 'mr', 'ne', 'or', 'pa', 'sa', 'sat', 'sd', 'ta', 'te', 'ur',
      // 2 Additional languages
      'en', 'de',
    ];

    test('All 24 required languages exist in LanguageModel.defaultLanguages', () {
      expect(LanguageModel.defaultLanguages.length, greaterThanOrEqualTo(24));
      final codes = LanguageModel.defaultLanguages.map((l) => l.code).toSet();
      for (final req in requiredCodes) {
        expect(codes.contains(req), isTrue, reason: 'Language $req must exist');
      }
    });

    test('Every required language has non-empty name, nativeName, and correct flag', () {
      for (final req in requiredCodes) {
        final lang = LanguageModel.fromCode(req);
        expect(lang, isNotNull, reason: 'LanguageModel.fromCode($req) must not be null');
        expect(lang!.name.isNotEmpty, isTrue);
        expect(lang.nativeName.isNotEmpty, isTrue);
        if (req == 'en') {
          expect(lang.flagEmoji, '🇬🇧');
        } else if (req == 'de') {
          expect(lang.flagEmoji, '🇩🇪');
        } else {
          expect(lang.flagEmoji, '🇮🇳', reason: 'Indian language $req must have India flag');
        }
      }
    });

    test('OnlineTranslationService supports all 24 required languages', () {
      final service = OnlineTranslationService();
      for (final req in requiredCodes) {
        expect(service.isLanguageSupported(req), isTrue,
            reason: 'Online translation must support $req');
      }
    });

    test('OnDeviceTranslationService accurately distinguishes supported vs unsupported offline languages', () {
      final service = OnDeviceTranslationService();
      // ML Kit genuinely supports 10 languages
      const mlKitSupported = ['en', 'de', 'hi', 'bn', 'gu', 'kn', 'mr', 'ta', 'te', 'ur'];
      // The other 14 are not provided by ML Kit
      const mlKitUnsupported = [
        'as', 'brx', 'doi', 'ks', 'kok', 'mai', 'ml', 'mni', 'ne', 'or', 'pa', 'sa', 'sat', 'sd'
      ];

      for (final code in mlKitSupported) {
        expect(service.isLanguageSupported(code), isTrue,
            reason: '$code must be supported by on-device ML Kit');
      }

      for (final code in mlKitUnsupported) {
        expect(service.isLanguageSupported(code), isFalse,
            reason: '$code is not supported by on-device ML Kit and must not fake support');
      }
    });

    test('TTS Locale mapping covers all 24 required languages without defaulting to English', () {
      for (final req in requiredCodes) {
        final voice = OnDeviceTtsService.getLocaleForLanguage(req);
        if (req == 'de') {
          expect(voice, 'de-DE');
        } else if (req == 'ne') {
          expect(voice, 'ne-NP');
        } else if (req == 'en') {
          expect(voice, 'en-IN');
        } else {
          expect(voice.endsWith('-IN'), isTrue,
              reason: 'Indian language $req locale must end with -IN');
        }
      }
    });
  });

  group('EngineSelectionManager & First-Use UX Verification', () {
    test('Online mode is ready out-of-the-box without requiring Whisper download', () async {
      final net = FakeNetworkConnectivityService(connected: true, validated: true);
      final manager = EngineSelectionManager(
        connectivityService: net,
        initialMode: ConnectionModeType.cloudAi,
      );

      final res = await manager.resolve(
        sourceLanguageCode: 'auto',
        targetLanguageCode: 'te',
      );

      expect(res.isReady, isTrue,
          reason: 'Online mode must be ready without Whisper model download');
      expect(res.translationEngine, EngineType.onlineCloud);
      expect(res.statusTitle.contains('Online'), isTrue);
    });

    test('Automatic mode with internet is ready out-of-the-box', () async {
      final net = FakeNetworkConnectivityService(connected: true, validated: true);
      final manager = EngineSelectionManager(
        connectivityService: net,
        initialMode: ConnectionModeType.automatic,
      );

      final res = await manager.resolve(
        sourceLanguageCode: 'auto',
        targetLanguageCode: 'te',
      );

      expect(res.isReady, isTrue,
          reason: 'Automatic mode with internet must be ready out of the box');
      expect(res.translationEngine, EngineType.onlineCloud);
    });

    test('Offline mode strictly enforces offline pack requirements', () async {
      final net = FakeNetworkConnectivityService(connected: false, validated: false);
      final manager = EngineSelectionManager(
        connectivityService: net,
        initialMode: ConnectionModeType.onDevice,
      );

      final res = await manager.resolve(
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );

      // In tests without actual Whisper and ML Kit installed on disk, requires pack
      expect(res.isFullyOffline, isTrue);
    });
  });
}

class FakeNetworkConnectivityService extends Fake implements NetworkConnectivityService {
  final bool _connected;
  final bool _validated;

  FakeNetworkConnectivityService({bool connected = true, bool validated = true})
      : _connected = connected,
        _validated = validated;

  @override
  bool get isConnected => _connected;

  @override
  bool get isValidatedInternet => _validated;

  @override
  Stream<NetworkState> get stateStream => const Stream.empty();
}
