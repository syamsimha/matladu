import 'package:flutter_test/flutter_test.dart';
import 'package:matladu_ai/data/models/language_registry.dart';
import 'package:matladu_ai/data/models/translation_result.dart';
import 'package:matladu_ai/data/models/two_way_direction.dart';
import 'package:matladu_ai/data/models/language_model.dart';
import 'package:matladu_ai/data/services/asr/android_speech_recognizer_service.dart';
import 'package:matladu_ai/data/services/asr/transcript_validator.dart';
import 'package:matladu_ai/data/services/translation/on_device_translation_service.dart';
import 'package:matladu_ai/data/services/translation/online_translation_service.dart';
import 'package:matladu_ai/data/services/tts/on_device_tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Quality Gate 1: Centralized 24-Language Registry & 552 Directed Pairs', () {
    test('All 24 required product languages are registered with accurate metadata', () {
      expect(LanguageRegistry.totalLanguagesCount, equals(24));
      expect(LanguageRegistry.allLanguageCodes.length, equals(24));

      const expectedCodes = {
        'as', 'bn', 'brx', 'doi', 'gu', 'hi', 'kn', 'ks', 'kok',
        'mai', 'ml', 'mni', 'mr', 'ne', 'or', 'pa', 'sa', 'sat',
        'sd', 'ta', 'te', 'ur', 'en', 'de',
      };

      expect(LanguageRegistry.allLanguageCodes, equals(expectedCodes));

      for (final code in expectedCodes) {
        final cap = LanguageRegistry.getCapability(code);
        expect(cap, isNotNull, reason: 'Language $code must have registered capability');
        expect(cap!.code, equals(code));
        expect(cap.name.isNotEmpty, isTrue);
        expect(cap.nativeName.isNotEmpty, isTrue);
        expect(cap.scriptName.isNotEmpty, isTrue);
        expect(cap.googleSpeechLocale.isNotEmpty, isTrue);
        expect(cap.whisperCode.isNotEmpty, isTrue);
        expect(cap.ttsLocale.isNotEmpty, isTrue);
      }
    });

    test('All 24 * 23 = 552 directed translation pairs are represented and valid online', () {
      expect(LanguageRegistry.totalPairsCount, equals(552));

      final allCodes = LanguageRegistry.allLanguageCodes.toList();
      int directedPairCount = 0;

      for (final src in allCodes) {
        for (final tgt in allCodes) {
          if (src != tgt) {
            directedPairCount++;
            expect(
              LanguageRegistry.isPairSupportedOnline(src, tgt),
              isTrue,
              reason: 'Directed pair $src -> $tgt must be supported online',
            );
            // Reverse direction must also be valid independently
            expect(
              LanguageRegistry.isPairSupportedOnline(tgt, src),
              isTrue,
              reason: 'Reverse pair $tgt -> $src must be supported online',
            );
          } else {
            // Same-language translation is not a valid cross-language pair
            expect(LanguageRegistry.isPairSupportedOnline(src, tgt), isFalse);
          }
        }
      }

      expect(directedPairCount, equals(552));
    });

    test('Offline translation matrix correctly reflects exactly 10 ML Kit languages (90 pairs)', () {
      final offlineCodes = LanguageRegistry.mlKitOfflineSupportedCodes;
      expect(offlineCodes.length, equals(10));
      expect(offlineCodes, equals({'en', 'de', 'hi', 'bn', 'gu', 'kn', 'mr', 'ta', 'te', 'ur'}));

      int offlinePairsCount = 0;
      final allCodes = LanguageRegistry.allLanguageCodes.toList();

      for (final src in allCodes) {
        for (final tgt in allCodes) {
          if (src != tgt && LanguageRegistry.isPairSupportedOffline(src, tgt)) {
            offlinePairsCount++;
          }
        }
      }

      // Exactly 10 * 9 = 90 offline pairs
      expect(offlinePairsCount, equals(90));
      expect(LanguageRegistry.isPairSupportedOffline('en', 'te'), isTrue);
      expect(LanguageRegistry.isPairSupportedOffline('hi', 'de'), isTrue);
      // Unsupported offline pairs (e.g. Sanskrit, Bodo, Dogri, Santali)
      expect(LanguageRegistry.isPairSupportedOffline('en', 'sa'), isFalse);
      expect(LanguageRegistry.isPairSupportedOffline('te', 'brx'), isFalse);
      expect(LanguageRegistry.isPairSupportedOffline('sat', 'de'), isFalse);
    });

    test('Normalization handles Whisper tokens, locale suffixes and case variations cleanly', () {
      expect(LanguageRegistry.normalizeCode('<|te|>'), equals('te'));
      expect(LanguageRegistry.normalizeCode('<|hi|>'), equals('hi'));
      expect(LanguageRegistry.normalizeCode('te-IN'), equals('te'));
      expect(LanguageRegistry.normalizeCode('DE-de'), equals('de'));
      expect(LanguageRegistry.normalizeCode('en_US'), equals('en'));
      expect(LanguageRegistry.normalizeCode('auto'), equals('auto'));
      expect(LanguageRegistry.normalizeCode(''), equals(''));
      expect(LanguageRegistry.normalizeCode(null), equals(''));
    });
  });

  group('Quality Gate 2: Speech Recognition, Locales & Acoustic LID', () {
    test('Google SpeechRecognizer verified supported set contains exactly 12 major languages', () {
      final supported = AndroidSpeechRecognizerService.verifiedSupportedLanguages;
      expect(supported.length, equals(12));
      expect(supported, equals({'en', 'de', 'hi', 'bn', 'te', 'ta', 'kn', 'ml', 'gu', 'mr', 'pa', 'ur'}));

      // Major languages supported by Google Speech Services
      expect(AndroidSpeechRecognizerService.isLanguageSupported('en'), isTrue);
      expect(AndroidSpeechRecognizerService.isLanguageSupported('de'), isTrue);
      expect(AndroidSpeechRecognizerService.isLanguageSupported('te'), isTrue);
      expect(AndroidSpeechRecognizerService.isLanguageSupported('hi'), isTrue);

      // Minority languages routed to on-device Whisper (isGoogleSpeechSupported == false)
      expect(AndroidSpeechRecognizerService.isLanguageSupported('sa'), isFalse);
      expect(AndroidSpeechRecognizerService.isLanguageSupported('brx'), isFalse);
      expect(AndroidSpeechRecognizerService.isLanguageSupported('doi'), isFalse);
      expect(AndroidSpeechRecognizerService.isLanguageSupported('sat'), isFalse);
      expect(AndroidSpeechRecognizerService.isLanguageSupported('kok'), isFalse);
      expect(AndroidSpeechRecognizerService.isLanguageSupported('mai'), isFalse);
      expect(AndroidSpeechRecognizerService.isLanguageSupported('mni'), isFalse);
      expect(AndroidSpeechRecognizerService.isLanguageSupported('auto'), isFalse);
    });

    test('Locale mappings resolve to accurate BCP-47 tags across all 24 languages', () {
      expect(AndroidSpeechRecognizerService.resolveLocale('te'), equals('te-IN'));
      expect(AndroidSpeechRecognizerService.resolveLocale('hi'), equals('hi-IN'));
      expect(AndroidSpeechRecognizerService.resolveLocale('en'), equals('en-IN'));
      expect(AndroidSpeechRecognizerService.resolveLocale('de'), equals('de-DE'));
      expect(AndroidSpeechRecognizerService.resolveLocale('as'), equals('as-IN'));
      expect(AndroidSpeechRecognizerService.resolveLocale('ne'), equals('ne-NP'));
      expect(AndroidSpeechRecognizerService.resolveLocale('ks'), equals('ks-IN'));
      expect(AndroidSpeechRecognizerService.resolveLocale('ur'), equals('ur-IN'));
    });

    test('Romanized Telugu detection identifies Telugu transliteration and excludes English', () {
      expect(TranscriptValidator.isRomanizedTelugu('namaste ela unnaru'), isTrue);
      expect(TranscriptValidator.isRomanizedTelugu('meeru bagunnanu'), isTrue);
      expect(TranscriptValidator.isRomanizedTelugu('chala dhanyavadalu'), isTrue);

      // English phrases containing stopwords must never trigger Romanized Telugu
      expect(TranscriptValidator.isRomanizedTelugu('Welcome to Matladu'), isFalse);
      expect(TranscriptValidator.isRomanizedTelugu('Hello how are you today'), isFalse);
      expect(TranscriptValidator.isRomanizedTelugu('Thank you very much'), isFalse);
    });

    test('Romanized Hindi detection identifies Hindi transliteration and excludes English', () {
      expect(TranscriptValidator.isRomanizedHindi('aap kaise hain'), isTrue);
      expect(TranscriptValidator.isRomanizedHindi('kya kar rahe ho'), isTrue);
      expect(TranscriptValidator.isRomanizedHindi('bahut dhanyavad'), isTrue);
      expect(TranscriptValidator.isRomanizedHindi('sab theek hai'), isTrue);

      // English phrases must not trigger Romanized Hindi
      expect(TranscriptValidator.isRomanizedHindi('Good morning and welcome'), isFalse);
      expect(TranscriptValidator.isRomanizedHindi('Where are you going'), isFalse);
    });

    test('TranscriptValidator suppresses fragmented speech tokens <= 2 characters', () {
      final invalid1 = TranscriptValidator.validate('nd');
      expect(invalid1.isValid, isFalse);
      expect(invalid1.reason, contains('Incomplete or fragmented speech'));

      final invalid2 = TranscriptValidator.validate('th');
      expect(invalid2.isValid, isFalse);

      // Legitimate 2-letter words are preserved
      final validOk = TranscriptValidator.validate('ok');
      expect(validOk.isValid, isTrue);

      final validHi = TranscriptValidator.validate('hi');
      expect(validHi.isValid, isTrue);

      final validJa = TranscriptValidator.validate('ja');
      expect(validJa.isValid, isTrue);
    });

    test('TwoWayDirectionManager resolves direction using spoken text transliteration', () {
      final langEn = LanguageModel.fromCode('en')!;
      final langTe = LanguageModel.fromCode('te')!;
      final manager = TwoWayDirectionManager(languageA: langEn, languageB: langTe);

      // When person speaks Romanized Telugu, direction dynamically resolves to te -> en
      final resTe = manager.resolve(
        detectedLanguageCode: 'auto',
        spokenText: 'ela unnaru bagunnanu',
      );
      expect(resTe.sourceLanguage.code, equals('te'));
      expect(resTe.targetLanguage.code, equals('en'));

      // When person speaks English, direction resolves to en -> te
      final resEn = manager.resolve(
        detectedLanguageCode: 'en',
        spokenText: 'Hello, how are you?',
      );
      expect(resEn.sourceLanguage.code, equals('en'));
      expect(resEn.targetLanguage.code, equals('te'));
    });
  });

  group('Quality Gate 3: Translation Quality, Script Verification & Bridge Pivots', () {
    test('TranscriptValidator.isScriptValidForTarget rejects non-Latin scripts on European cards', () {
      // European target: German
      expect(TranscriptValidator.isScriptValidForTarget('Hallo, wie geht es Ihnen?', 'de'), isTrue);
      expect(TranscriptValidator.isScriptValidForTarget('Danke schön', 'de'), isTrue);
      // Reject Indic script leakage on German target
      expect(TranscriptValidator.isScriptValidForTarget('ఎలా ఉన్నారు', 'de'), isFalse);
      expect(TranscriptValidator.isScriptValidForTarget('नमस्ते', 'de'), isFalse);
      expect(TranscriptValidator.isScriptValidForTarget('வணக்கம்', 'de'), isFalse);
      expect(TranscriptValidator.isScriptValidForTarget('اردو', 'de'), isFalse);

      // European target: English
      expect(TranscriptValidator.isScriptValidForTarget('Hello world', 'en'), isTrue);
      expect(TranscriptValidator.isScriptValidForTarget('నమస్కారం', 'en'), isFalse);
      expect(TranscriptValidator.isScriptValidForTarget('धन्यवाद', 'en'), isFalse);
    });

    test('OnlineTranslationService segmentText chunks long text preserving boundaries', () {
      const shortText = 'Hello world. How are you today?';
      final chunks = OnlineTranslationService.segmentText(shortText, maxBytes: 400);
      expect(chunks.length, equals(1));
      expect(chunks.first, equals(shortText));

      final longText = List.generate(30, (i) => 'Sentence number $i explaining translation.').join(' ');
      final longChunks = OnlineTranslationService.segmentText(longText, maxBytes: 200);
      expect(longChunks.length, greaterThan(1));
      // Reconstructed text must cover all sentences
      expect(longChunks.join(' '), equals(longText));
    });

    test('OnDeviceTranslationService handles supported and unsupported offline pairs honestly', () async {
      final onDevice = OnDeviceTranslationService(simulatedDownloadedCodes: {'en', 'te', 'hi'});
      await onDevice.initialize();

      // Supported pair with downloaded models
      final resTe = await onDevice.translate(
        text: 'Hello, how are you?',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );
      expect(resTe.isSuccess, isTrue);
      expect(resTe.translatedText, contains('ఎలా ఉన్నారు'));

      // Supported ML Kit language but missing download pack
      final resMr = await onDevice.translate(
        text: 'Hello',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'mr',
      );
      expect(resMr.status, equals(TranslationStatus.modelMissing));
      expect(resMr.errorMessage, contains('Offline pack required'));

      // Language not supported offline by ML Kit (e.g. Sanskrit)
      final resSa = await onDevice.translate(
        text: 'Hello',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'sa',
      );
      expect(resSa.status, equals(TranslationStatus.unsupportedPair));
      expect(resSa.errorMessage, contains('On-device offline translation pack is not available'));
      expect(resSa.errorMessage, contains('Online Mode'));
    });

    test('Same-language translation returns original text immediately without inference overhead', () async {
      final onDevice = OnDeviceTranslationService(simulatedDownloadedCodes: {'en'});
      final res = await onDevice.translate(
        text: 'Identical language check',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'en',
      );
      expect(res.isSuccess, isTrue);
      expect(res.translatedText, equals('Identical language check'));
      expect(res.duration, equals(Duration.zero));
    });
  });

  group('Quality Gate 4: TTS Capabilities & Privacy Guarantees', () {
    test('OnDeviceTtsService locale mapping covers all 24 languages with accurate locales', () {
      expect(OnDeviceTtsService.getLocaleForLanguage('te'), equals('te-IN'));
      expect(OnDeviceTtsService.getLocaleForLanguage('hi'), equals('hi-IN'));
      expect(OnDeviceTtsService.getLocaleForLanguage('de'), equals('de-DE'));
      expect(OnDeviceTtsService.getLocaleForLanguage('en'), equals('en-IN'));
      expect(OnDeviceTtsService.getLocaleForLanguage('bn'), equals('bn-IN'));
      expect(OnDeviceTtsService.getLocaleForLanguage('ta'), equals('ta-IN'));
      expect(OnDeviceTtsService.getLocaleForLanguage('kn'), equals('kn-IN'));
      expect(OnDeviceTtsService.getLocaleForLanguage('mr'), equals('mr-IN'));
      expect(OnDeviceTtsService.getLocaleForLanguage('gu'), equals('gu-IN'));
      expect(OnDeviceTtsService.getLocaleForLanguage('ur'), equals('ur-IN'));
      expect(OnDeviceTtsService.getLocaleForLanguage('pa'), equals('pa-IN'));
      expect(OnDeviceTtsService.getLocaleForLanguage('ml'), equals('ml-IN'));
      expect(OnDeviceTtsService.getLocaleForLanguage('or'), equals('or-IN'));
      expect(OnDeviceTtsService.getLocaleForLanguage('as'), equals('as-IN'));
      expect(OnDeviceTtsService.getLocaleForLanguage('sa'), equals('sa-IN'));
      expect(OnDeviceTtsService.getLocaleForLanguage('ne'), equals('ne-NP'));
    });

    test('OnDeviceTtsService blocks speaking error messages or system notifications', () async {
      final tts = OnDeviceTtsService();
      final spokeError = await tts.speak(
        text: 'Error: Cannot reach translation provider',
        languageCode: 'en',
      );
      expect(spokeError, isFalse);

      final spokeTranslating = await tts.speak(
        text: 'Translating speech...',
        languageCode: 'en',
      );
      expect(spokeTranslating, isFalse);
    });
  });
}
