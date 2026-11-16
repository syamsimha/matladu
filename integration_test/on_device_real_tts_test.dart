import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:matladu_ai/data/models/asr_state.dart';
import 'package:matladu_ai/data/models/tts_result.dart';
import 'package:matladu_ai/data/repositories/translation_repository.dart';
import 'package:matladu_ai/data/repositories/tts_repository.dart';
import 'package:matladu_ai/data/services/local_storage_service.dart';
import 'package:matladu_ai/data/services/translation/on_device_translation_service.dart';
import 'package:matladu_ai/data/services/tts/on_device_tts_service.dart';
import 'package:matladu_ai/ui/features/live_translation/view_models/live_translation_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _ensureRenderSurface(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: Text(
            'Running Real On-Device TTS Integration Tests...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('On-Device Real Native TTS Integration Tests', () {
    late OnDeviceTtsService ttsService;
    late OnDeviceTranslationService translationService;
    late LocalStorageService storageService;
    late TtsRepository ttsRepo;
    late TranslationRepository translationRepo;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storageService = LocalStorageService(prefs);

      ttsService = OnDeviceTtsService();
      await ttsService.initialize();

      translationService = OnDeviceTranslationService();
      await translationService.initialize();

      ttsRepo = TtsRepository(
        ttsService: ttsService,
        storageService: storageService,
      );
      await ttsRepo.initialize();

      translationRepo = TranslationRepository(
        translationService: translationService,
        storageService: storageService,
      );
    });

    tearDownAll(() async {
      await ttsRepo.dispose();
      await translationService.dispose();
    });

    testWidgets('Inspect native TTS engines, available voices, and offline compatibility',
        (tester) async {
      await _ensureRenderSurface(tester);

      final defaultEngine = await ttsService.getDefaultEngine();
      final allEngines = await ttsService.getEngines();
      final allVoices = await ttsService.getAvailableVoices();
      final offlineVoices = await ttsService.getOfflineVoices();

      debugPrint('=== NATIVE ANDROID TTS ENGINE AUDIT ===');
      debugPrint('Default TTS Engine: $defaultEngine');
      debugPrint('Installed Engines: $allEngines');
      debugPrint('Total Voices Enumerated: ${allVoices.length}');
      debugPrint('Offline Certified Voices: ${offlineVoices.length}');

      final enOffline = offlineVoices.where((v) => v.languageCode == 'en').toList();
      final hiOffline = offlineVoices.where((v) => v.languageCode == 'hi').toList();
      final teOffline = offlineVoices.where((v) => v.languageCode == 'te').toList();

      debugPrint('English Offline Voices: ${enOffline.map((v) => v.name).toList()}');
      debugPrint('Hindi Offline Voices: ${hiOffline.map((v) => v.name).toList()}');
      debugPrint('Telugu Offline Voices: ${teOffline.map((v) => v.name).toList()}');
      debugPrint('=======================================');

      expect(allVoices.isNotEmpty || defaultEngine != null, isTrue,
          reason: 'A native TTS engine must be present on the Android device.');
    });

    testWidgets('Real native English offline speech synthesis', (tester) async {
      await _ensureRenderSurface(tester);

      const englishPhrase = 'Hello, how are you? Welcome to Matladu AI.';
      final stopwatch = Stopwatch()..start();

      final success = await ttsRepo.speakTranslation(
        text: englishPhrase,
        targetLanguageCode: 'en',
        isAutoPlay: false,
      );
      stopwatch.stop();

      debugPrint('=== REAL NATIVE ENGLISH SPEECH SYNTHESIS ===');
      debugPrint('Input text: "$englishPhrase"');
      debugPrint('Target language: en');
      debugPrint('Synthesis start latency: ${stopwatch.elapsedMilliseconds} ms');
      debugPrint('Success status: $success');
      debugPrint('============================================');

      expect(success, isTrue, reason: 'English speech synthesis must succeed on device.');
      // Allow audio to play for 2 seconds
      await tester.pump(const Duration(seconds: 2));
      await ttsRepo.stop();
    });

    testWidgets('Real native Hindi offline speech synthesis', (tester) async {
      await _ensureRenderSurface(tester);

      const hindiPhrase = 'नमस्कार, आप कैसे हैं?';
      final stopwatch = Stopwatch()..start();

      final isHiAvailable = await ttsRepo.isOfflineVoiceAvailable('hi');
      debugPrint('=== REAL NATIVE HINDI SPEECH SYNTHESIS ===');
      debugPrint('Input text: "$hindiPhrase"');
      debugPrint('Hindi offline voice available: $isHiAvailable');

      final success = await ttsRepo.speakTranslation(
        text: hindiPhrase,
        targetLanguageCode: 'hi',
        isAutoPlay: false,
      );
      stopwatch.stop();

      debugPrint('Synthesis start latency: ${stopwatch.elapsedMilliseconds} ms');
      debugPrint('Success status: $success');
      debugPrint('==========================================');

      if (isHiAvailable) {
        expect(success, isTrue);
        await tester.pump(const Duration(seconds: 2));
        await ttsRepo.stop();
      } else {
        expect(ttsRepo.currentState, TtsPlaybackState.voiceUnavailable);
      }
    });

    testWidgets('Native Telugu speech synthesis or graceful missing voice handling',
        (tester) async {
      await _ensureRenderSurface(tester);

      const teluguPhrase = 'హలో, మీరు ఎలా ఉన్నారు?';
      final stopwatch = Stopwatch()..start();

      final isTeAvailable = await ttsRepo.isOfflineVoiceAvailable('te');
      debugPrint('=== NATIVE TELUGU SPEECH SYNTHESIS EVALUATION ===');
      debugPrint('Input text: "$teluguPhrase"');
      debugPrint('Telugu offline voice available: $isTeAvailable');

      final success = await ttsRepo.speakTranslation(
        text: teluguPhrase,
        targetLanguageCode: 'te',
        isAutoPlay: false,
      );
      stopwatch.stop();

      debugPrint('Synthesis result: $success');
      debugPrint('Engine state: ${ttsRepo.currentState}');
      debugPrint('Latency: ${stopwatch.elapsedMilliseconds} ms');
      debugPrint('=================================================');

      if (isTeAvailable) {
        expect(success, isTrue);
        await tester.pump(const Duration(seconds: 2));
        await ttsRepo.stop();
      } else {
        // Strict requirement: Never fabricate success or substitute English pronunciation for Telugu!
        expect(ttsRepo.currentState, TtsPlaybackState.voiceUnavailable);
        debugPrint('[IntegrationTest] Telugu voice requires Android TTS voice data download.');
      }
    });

    testWidgets('End-to-End Automatic TTS Playback in Live Translation Workflow',
        (tester) async {
      await _ensureRenderSurface(tester);

      final asrResult = ASRRecognitionResult(
        text: 'Hello, how are you?',
        detectedLanguageCode: 'en',
        detectedLanguageName: 'English',
        confidence: 0.98,
        audioDuration: const Duration(seconds: 2),
        timestamp: DateTime.now(),
        isFinal: true,
        isMock: false,
      );

      final vm = LiveTranslationViewModel(
        initialRecognition: asrResult,
        translationRepository: translationRepo,
        ttsRepository: ttsRepo,
        initialTargetLanguageCode: 'en',
      );

      debugPrint('=== END-TO-END RECOGNIZE -> TRANSLATE -> AUTOMATIC TTS ===');
      debugPrint('Original recognized input: "${asrResult.text}"');

      // Wait for translation to complete and automatic playback to trigger
      await tester.pump(const Duration(milliseconds: 500));

      debugPrint('Translated text: "${vm.translatedText}"');
      debugPrint('Is playing audio automatically: ${vm.isPlayingAudio}');
      debugPrint('==========================================================');

      expect(vm.isTranslationComplete, isTrue);
      expect(vm.translatedText.isNotEmpty, isTrue);

      // Verify manual stop
      if (vm.isPlayingAudio) {
        await vm.playTranslation(); // Taps to stop
        await tester.pump(const Duration(milliseconds: 100));
        expect(vm.isPlayingAudio, isFalse);
      }

      // Verify manual replay
      await vm.playTranslation(); // Taps to replay
      await tester.pump(const Duration(milliseconds: 100));
      debugPrint('Manual replay audio playing: ${vm.isPlayingAudio}');

      await vm.stopPlayback();
    });
  });
}

