import 'package:flutter_test/flutter_test.dart';
import 'package:matladu_ai/data/models/language_model.dart';
import 'package:matladu_ai/data/models/connection_mode_model.dart';
import 'package:matladu_ai/data/models/offline_pack_model.dart';
import 'package:matladu_ai/data/models/translation_item_model.dart';

void main() {
  group('Matladu AI Phase 1 Model Tests', () {
    test('LanguageModel defaults and JSON serialization', () {
      const defaultLangs = LanguageModel.defaultLanguages;
      expect(defaultLangs.isNotEmpty, true);
      expect(defaultLangs.first.code, 'en');

      final json = defaultLangs.first.toJson();
      final fromJson = LanguageModel.fromJson(json);
      expect(fromJson.name, 'English');
      expect(fromJson.category, 'Popular');
    });

    test('ConnectionModeModel available modes', () {
      const modes = ConnectionModeModel.availableModes;
      expect(modes.length, 4);
      expect(modes.any((m) => m.type == ConnectionModeType.automatic), isTrue);
      expect(modes.any((m) => m.type == ConnectionModeType.cloudAi), isTrue);
      expect(modes.any((m) => m.type == ConnectionModeType.onDevice), isTrue);
    });

    test('OfflinePackModel copyWith and JSON serialization', () {
      const pack = OfflinePackModel(
        id: 'te',
        languageName: 'Telugu Pack',
        languageCode: 'te',
        flagEmoji: '🇮🇳',
        sizeInMB: 25,
      );

      final updated = pack.copyWith(isDownloaded: true);
      expect(updated.isDownloaded, true);
      expect(updated.sizeInMB, 25);
    });

    test('TranslationItemModel structure', () {
      final item = TranslationItemModel(
        id: '1',
        sourceText: 'Hello, how are you?',
        translatedText: 'నమస్తే, మీరు ఎలా ఉన్నారు?',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
        timestamp: DateTime.now(),
      );

      expect(item.sourceText, 'Hello, how are you?');
      expect(item.translatedText, 'నమస్తే, మీరు ఎలా ఉన్నారు?');
    });
  });
}

