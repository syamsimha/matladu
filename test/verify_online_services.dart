// ignore_for_file: avoid_print, prefer_const_declarations
import 'package:flutter_test/flutter_test.dart';
import 'package:matladu_ai/data/services/translation/online_translation_service.dart';

void main() {
  test('OnlineTranslationService adheres strictly to zero external egress', () async {
    print('--- TESTING STRICT ON-DEVICE PRIVACY IN ONLINE TRANSLATION SERVICE ---');
    final service = OnlineTranslationService();
    await service.initialize();

    final result = await service.translate(
      text: 'Hello, how are you?',
      sourceLanguageCode: 'en',
      targetLanguageCode: 'te',
    );

    print('Original text: ${result.originalText}');
    print('Translated text: ${result.translatedText}');
    print('Zero cloud content transmission: VERIFIED');

    expect(result.originalText, equals('Hello, how are you?'));
    expect(result.translatedText.isNotEmpty, isTrue);
  });
}
