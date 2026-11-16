import 'dart:async';
import '../models/translation_result.dart';
import 'translation/i_translation_service.dart';

export 'translation/i_translation_service.dart';

/// Mock translation engine service for UI and interface-level validation.
///
/// STRICT GUARANTEES:
/// - 100% offline — zero external HTTP requests or network sockets.
/// - Used only in unit/widget test harnesses where native platform channels are unavailable.
/// - Emits results with `isMock: true` for testing transparency.
class MockTranslationService implements ITranslationService {
  final StreamController<TranslationResult> _resultController =
      StreamController<TranslationResult>.broadcast();

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
    'welcome to matladu': {
      'te': 'మాట్లాడు కు స్వాగతం (Matladu ki swagatham)',
      'hi': 'बातलाडू में आपका स्वागत है',
      'es': 'Bienvenido a Matladu',
      'fr': 'Bienvenue sur Matladu',
      'de': 'Willkommen bei Matladu',
      'ta': 'மாட்லாடு க்கு வரவேற்கிறோம்',
      'kn': 'ಮಾತ್ಲಾಡು ಗೆ ಸುಸ್ವಾಗತ',
    },
    'welcome to matladu ai': {
      'te': 'మాట్లాడు కు స్వాగతం (Matladu ki swagatham)',
      'hi': 'बातलाडू में आपका स्वागत है',
      'es': 'Bienvenido a Matladu',
      'fr': 'Bienvenue sur Matladu',
      'de': 'Willkommen bei Matladu',
      'ta': 'மாட்லாடு க்கு வரவேற்கிறோம்',
      'kn': 'ಮಾತ್ಲಾಡು ಗೆ ಸುಸ್ವಾಗತ',
    },
  };

  @override
  Stream<TranslationResult> get resultStream => _resultController.stream;

  @override
  Future<void> initialize() async {}

  @override
  bool isLanguageSupported(String languageCode) => true;

  @override
  bool isPairSupported(String sourceCode, String targetCode) => true;

  @override
  Future<bool> isModelDownloaded(String languageCode) async => true;

  @override
  Future<bool> downloadModel(
    String languageCode, {
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(1.0);
    return true;
  }

  @override
  Future<bool> deleteModel(String languageCode) async => true;

  @override
  Future<TranslationResult> translate({
    required String text,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) {
      return TranslationResult.empty(
        sourceLang: sourceLanguageCode,
        targetLang: targetLanguageCode,
      );
    }

    if (sourceLanguageCode == targetLanguageCode) {
      return TranslationResult.sameLanguage(
        text: clean,
        languageCode: sourceLanguageCode,
      );
    }

    final normalized = clean.toLowerCase();
    String translatedText;

    if (_sampleDictionary.containsKey(normalized) &&
        _sampleDictionary[normalized]!.containsKey(targetLanguageCode)) {
      translatedText = _sampleDictionary[normalized]![targetLanguageCode]!;
    } else if (targetLanguageCode == 'te') {
      translatedText = 'నమస్కారం, మీరు ఎలా ఉన్నారు?';
    } else if (targetLanguageCode == 'hi') {
      translatedText = 'नमस्ते, आप कैसे हैं?';
    } else if (targetLanguageCode == 'en') {
      translatedText = 'Hello, how are you?';
    } else {
      translatedText = '[$targetLanguageCode Translation]: $clean';
    }

    final result = TranslationResult(
      originalText: clean,
      translatedText: translatedText,
      sourceLanguageCode: sourceLanguageCode,
      targetLanguageCode: targetLanguageCode,
      status: TranslationStatus.completed,
      duration: const Duration(milliseconds: 15),
      isMock: true,
      timestamp: DateTime.now(),
    );

    if (!_resultController.isClosed) {
      _resultController.add(result);
    }

    return result;
  }

  Stream<List<double>> listenVoiceWaves() {
    return Stream.periodic(const Duration(milliseconds: 100), (count) {
      return [
        (0.3 + 0.5 * (count % 3 == 0 ? 0.8 : 0.4)).clamp(0.1, 1.0),
        (0.5 + 0.4 * (count % 2 == 0 ? 0.9 : 0.3)).clamp(0.1, 1.0),
        (0.8 + 0.2 * (count % 4 == 0 ? 1.0 : 0.5)).clamp(0.1, 1.0),
        (0.4 + 0.5 * (count % 2 == 0 ? 0.7 : 0.2)).clamp(0.1, 1.0),
        (0.6 + 0.3 * (count % 3 == 0 ? 0.6 : 0.3)).clamp(0.1, 1.0),
      ];
    });
  }

  @override
  Future<void> dispose() async {
    await _resultController.close();
  }
}
