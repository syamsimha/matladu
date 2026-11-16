import 'package:flutter_test/flutter_test.dart';
import 'package:matladu_ai/data/services/asr/transcript_validator.dart';

void main() {
  group('TranscriptValidator Unit Tests', () {
    test('Valid Telugu sentence passes validation and detects te script', () {
      const input = 'శుభ సాయంత్రం, మీరు ఎలా ఉన్నారు?';
      final res = TranscriptValidator.validate(input);

      expect(res.isValid, isTrue);
      expect(res.cleanedText, equals(input));
      expect(res.resolvedScript, equals('te'));
      expect(res.isHallucination, isFalse);
    });

    test('Valid English sentence passes validation and detects en script', () {
      const input = 'Hello, how are you today?';
      final res = TranscriptValidator.validate(input);

      expect(res.isValid, isTrue);
      expect(res.cleanedText, equals(input));
      expect(res.resolvedScript, equals('en'));
      expect(res.isHallucination, isFalse);
    });

    test('Valid Hindi sentence passes validation and detects hi script', () {
      const input = 'नमस्ते, आप कैसे हैं?';
      final res = TranscriptValidator.validate(input);

      expect(res.isValid, isTrue);
      expect(res.cleanedText, equals(input));
      expect(res.resolvedScript, equals('hi'));
      expect(res.isHallucination, isFalse);
    });

    test('Single character repetition loop (e.g. 1 1 1 1 1) is detected and rejected', () {
      const input = '1 1 1 1 1';
      final res = TranscriptValidator.validate(input);

      expect(res.isValid, isFalse);
      expect(res.isHallucination, isTrue);
    });

    test('Corrupted byte tokens (<0x9F>) are stripped and rejected if nothing else remains', () {
      const input = '<0x9F> <0x9F> <0x9F>';
      final res = TranscriptValidator.validate(input);

      expect(res.isValid, isFalse);
      expect(res.isHallucination, isTrue);
    });

    test('CJK / Bopomofo hallucination (e.g. ㄟ ㄟ ㄟ ㄟ ㄟ) is detected and rejected', () {
      const input = 'ㄟ ㄟ ㄟ ㄟ ㄟ';
      final res = TranscriptValidator.validate(input);

      expect(res.isValid, isFalse);
      expect(res.isHallucination, isTrue);
    });

    test('Repeated phrase hallucination (e.g. Vale para tu!...) is detected and rejected', () {
      const input = '¡Vale para tu! ¡Vale para tu! ¡Vale para tu! ¡Vale para tu!';
      final res = TranscriptValidator.validate(input);

      expect(res.isValid, isFalse);
      expect(res.isHallucination, isTrue);
    });

    test('Punctuation-only string is rejected', () {
      const input = '... ??? !!!';
      final res = TranscriptValidator.validate(input);

      expect(res.isValid, isFalse);
      expect(res.reason, contains('Punctuation'));
    });

    test('Empty or whitespace-only string is rejected', () {
      const input = '   ';
      final res = TranscriptValidator.validate(input);

      expect(res.isValid, isFalse);
    });
  });
}

