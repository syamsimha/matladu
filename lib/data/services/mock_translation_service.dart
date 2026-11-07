import 'dart:async';
import '../models/language_model.dart';
import '../models/translation_item_model.dart';

/// Mock translation engine service for UI and interface-level validation.
/// Actual AI speech-to-text, neural translation, and text-to-speech engines
/// will plug in behind this contract in future phases.
abstract class ITranslationService {
  Future<TranslationItemModel> translate({
    required String text,
    required LanguageModel sourceLang,
    required LanguageModel targetLang,
  });

  Stream<List<double>> listenVoiceWaves();
}

class MockTranslationService implements ITranslationService {
  // Sample dictionary mappings for realistic UI demonstrations
  static final Map<String, Map<String, String>> _sampleDictionary = {
    'hello': {
      'te': 'నమస్కారం (Namaskaram)',
      'hi': 'नमस्ते (Namaste)',
      'es': 'Hola',
      'fr': 'Bonjour',
      'de': 'Hallo',
      'ta': 'வணக்கம் (Vanakkam)',
      'kn': 'ನಮಸ್ಕಾರ (Namaskara)',
    },
    'how are you': {
      'te': 'మీరు ఎలా ఉన్నారు? (Meeru ela unnaru?)',
      'hi': 'आप कैसे हैं? (Aap kaise hain?)',
      'es': '¿Cómo estás?',
      'fr': 'Comment allez-vous?',
      'de': 'Wie geht es dir?',
      'ta': 'நீங்கள் எப்படி இருக்கிறீர்கள்?',
      'kn': 'ನೀವು ಹೇಗಿದ್ದೀರಿ?',
    },
    'welcome to matladu ai': {
      'te': 'మాట్లాడు AI కి స్వాగతం (Matladu AI ki swagatham)',
      'hi': 'बातलाडू AI में आपका स्वागत है',
      'es': 'Bienvenido a Matladu AI',
      'fr': 'Bienvenue sur Matladu AI',
      'de': 'Willkommen bei Matladu AI',
      'ta': 'மாட்லாடு AI க்கு வரவேற்கிறோம்',
      'kn': 'ಮಾತ್ಲಾಡು AI ಗೆ ಸುಸ್ವಾಗತ',
    },
  };

  @override
  Future<TranslationItemModel> translate({
    required String text,
    required LanguageModel sourceLang,
    required LanguageModel targetLang,
  }) async {
    // Simulate real-time neural network inference latency (300ms)
    await Future.delayed(const Duration(milliseconds: 320));

    final normalized = text.trim().toLowerCase();
    String translatedText;

    if (_sampleDictionary.containsKey(normalized) &&
        _sampleDictionary[normalized]!.containsKey(targetLang.code)) {
      translatedText = _sampleDictionary[normalized]![targetLang.code]!;
    } else {
      // Clean fallback formatting for prototype testing
      translatedText =
          '[${targetLang.name} Translation]: $text (${targetLang.nativeName})';
    }

    return TranslationItemModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sourceText: text,
      translatedText: translatedText,
      sourceLanguageCode: sourceLang.code,
      targetLanguageCode: targetLang.code,
      timestamp: DateTime.now(),
    );
  }

  @override
  Stream<List<double>> listenVoiceWaves() {
    return Stream.periodic(const Duration(milliseconds: 100), (count) {
      final t = count * 0.2;
      return [
        (0.3 + 0.5 * (count % 3 == 0 ? 0.8 : 0.4)).clamp(0.1, 1.0),
        (0.5 + 0.4 * (count % 2 == 0 ? 0.9 : 0.3)).clamp(0.1, 1.0),
        (0.8 + 0.2 * (count % 4 == 0 ? 1.0 : 0.5)).clamp(0.1, 1.0),
        (0.4 + 0.5 * (count % 2 == 0 ? 0.7 : 0.2)).clamp(0.1, 1.0),
        (0.6 + 0.3 * (count % 3 == 0 ? 0.6 : 0.3)).clamp(0.1, 1.0),
      ];
    });
  }
}

