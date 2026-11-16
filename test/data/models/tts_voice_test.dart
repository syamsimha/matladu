import 'package:flutter_test/flutter_test.dart';
import 'package:matladu_ai/data/models/tts_result.dart';
import 'package:matladu_ai/data/models/tts_voice.dart';

void main() {
  group('TtsVoice Model Tests', () {
    test('Correctly identifies offline voice when network_required is false', () {
      final voice = TtsVoice.fromMap({
        'name': 'te-in-x-tef-local',
        'locale': 'te-IN',
        'network_required': false,
        'quality': 400,
        'latency': 200,
        'features': ['embeddedTts'],
      });

      expect(voice.name, 'te-in-x-tef-local');
      expect(voice.locale, 'te-IN');
      expect(voice.languageCode, 'te');
      expect(voice.isNetworkRequired, isFalse);
      expect(voice.isOfflineAvailable, isTrue);
      expect(voice.displayName, contains('Offline'));
    });

    test('Strictly rejects voice when network_required is true', () {
      final voice = TtsVoice.fromMap({
        'name': 'te-in-x-network',
        'locale': 'te-IN',
        'network_required': true,
      });

      expect(voice.isNetworkRequired, isTrue);
      expect(voice.isOfflineAvailable, isFalse);
      expect(voice.displayName, contains('Network Required'));
    });

    test('Correctly extracts base language codes for Indian and global locales', () {
      final teVoice = TtsVoice.fromMap({'name': 'te_voice', 'locale': 'te_IN'});
      final hiVoice = TtsVoice.fromMap({'name': 'hi_voice', 'locale': 'hi-IN'});
      final enVoice = TtsVoice.fromMap({'name': 'en_voice', 'locale': 'en-US'});

      expect(teVoice.languageCode, 'te');
      expect(hiVoice.languageCode, 'hi');
      expect(enVoice.languageCode, 'en');
    });
  });

  group('TtsResult Model Tests', () {
    test('State getters correctly evaluate playback lifecycle', () {
      const resultSpeaking = TtsResult(
        requestId: 'req_1',
        state: TtsPlaybackState.speaking,
        text: 'నమస్కారం',
        languageCode: 'te',
      );
      expect(resultSpeaking.isSpeaking, isTrue);
      expect(resultSpeaking.isCompleted, isFalse);
      expect(resultSpeaking.isVoiceUnavailable, isFalse);
      expect(resultSpeaking.hasError, isFalse);

      const resultCompleted = TtsResult(
        requestId: 'req_1',
        state: TtsPlaybackState.completed,
        text: 'నమస్కారం',
        languageCode: 'te',
        duration: Duration(milliseconds: 1400),
      );
      expect(resultCompleted.isCompleted, isTrue);
      expect(resultCompleted.isSpeaking, isFalse);

      const resultUnavailable = TtsResult(
        requestId: 'req_2',
        state: TtsPlaybackState.voiceUnavailable,
        text: 'హలో',
        languageCode: 'te',
        errorMessage: 'Offline voice for Telugu is not installed.',
      );
      expect(resultUnavailable.isVoiceUnavailable, isTrue);
      expect(resultUnavailable.errorMessage, isNotNull);
    });
  });
}

