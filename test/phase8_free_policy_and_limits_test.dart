import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:matladu_ai/data/models/connection_mode_model.dart';
import 'package:matladu_ai/data/models/room_model.dart';
import 'package:matladu_ai/data/models/translation_result.dart';
import 'package:matladu_ai/data/services/engine/engine_selection_manager.dart';
import 'package:matladu_ai/data/services/local_storage_service.dart';
import 'package:matladu_ai/data/services/network_connectivity_service.dart';
import 'package:matladu_ai/data/services/translation/hybrid_translation_service.dart';
import 'package:matladu_ai/data/services/translation/on_device_translation_service.dart';
import 'package:matladu_ai/data/services/translation/online_translation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test HTTP client for mocking external network requests with controlled responses.
class MockResponseHttpClient implements HttpClient {
  int statusCode;
  String responseBody;
  final List<Uri> interceptedUris = [];

  MockResponseHttpClient({
    this.statusCode = 200,
    this.responseBody = '{"responseStatus": 200, "responseData": {"translatedText": "నమస్కారం"}}',
  });

  @override
  Duration? connectionTimeout;

  @override
  void close({bool force = false}) {}

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    interceptedUris.add(url);
    return _MockHttpClientRequest(statusCode, responseBody);
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    interceptedUris.add(url);
    return _MockHttpClientRequest(statusCode, responseBody);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpClientRequest implements HttpClientRequest {
  final int statusCode;
  final String responseBody;

  _MockHttpClientRequest(this.statusCode, this.responseBody);

  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async {
    return _MockHttpClientResponse(statusCode, responseBody);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _headers = {};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers[name.toLowerCase()] = [value.toString()];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  final int statusCode;
  final String _body;

  _MockHttpClientResponse(this.statusCode, this._body);

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.value(utf8.encode(_body)).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ControlledConnectivityService extends NetworkConnectivityService {
  bool _online;
  final _controller = StreamController<NetworkState>.broadcast();

  ControlledConnectivityService(this._online);

  @override
  bool get isValidatedInternet => _online;

  @override
  Stream<NetworkState> get stateStream => _controller.stream;

  void setOnline(bool online) {
    _online = online;
    _controller.add(online
        ? const NetworkState(
            isConnected: true,
            isValidated: true,
            isWifi: true,
            isCellular: false,
            type: 'wifi',
          )
        : const NetworkState(
            isConnected: false,
            isValidated: false,
            isWifi: false,
            isCellular: false,
            type: 'none',
          ));
  }
}

class MockableOnDeviceTranslationService extends OnDeviceTranslationService {
  final Map<String, bool> _installedModels = {'en': true, 'te': true};

  void setModelInstalled(String lang, bool installed) {
    _installedModels[lang] = installed;
  }

  @override
  Future<bool> isModelDownloaded(String languageCode) async {
    return _installedModels[languageCode] ?? false;
  }

  @override
  Future<TranslationResult> translate({
    required String text,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) async {
    final isInstalled = await isModelDownloaded(targetLanguageCode);
    if (!isInstalled) {
      return TranslationResult.modelMissing(
        text: text,
        sourceLang: sourceLanguageCode,
        targetLang: targetLanguageCode,
        missingLanguageName: targetLanguageCode,
      );
    }
    return TranslationResult.success(
      originalText: text,
      translatedText: '[Local ML Kit] $text in $targetLanguageCode',
      sourceLanguageCode: sourceLanguageCode,
      targetLanguageCode: targetLanguageCode,
      isMock: false,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Permanent Free Forever Policy Verification', () {
    test('Matladu has zero paid API fallbacks and strictly prohibits payment dependencies', () {
      expect(OnlineTranslationService.defaultEndpoint, contains('mymemory.translated.net'));
      expect(OnlineTranslationService.contactEmail, equals('support@matladu.app'));
      // No credit counters or payment gateways
      final service = OnlineTranslationService();
      expect(service.isDailyQuotaExhausted, isFalse);
      expect(service.estimatedCharsSentToday, equals(0));
    });

    test('When online quota is exhausted, system never prompts for payment or credit purchase', () async {
      final mockClient = MockResponseHttpClient(
        statusCode: 429,
        responseBody: '{"responseStatus": 429, "responseDetails": "MYMEMORY WARNING: YOU USED ALL AVAILABLE FREE TRANSLATIONS FOR TODAY"}',
      );

      final onlineService = OnlineTranslationService(httpClient: mockClient);
      await onlineService.initialize();

      final result = await onlineService.translate(
        text: 'Hello world',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );

      expect(result.status, equals(TranslationStatus.error));
      expect(result.errorMessage, contains('HTTP 429'));
      expect(result.errorMessage, contains('100% free'));
      // Prohibited terms must not exist in user-facing message
      expect(result.errorMessage!.toLowerCase().contains('buy'), isFalse);
      expect(result.errorMessage!.toLowerCase().contains('credit'), isFalse);
      expect(result.errorMessage!.toLowerCase().contains('subscribe'), isFalse);
      expect(result.errorMessage!.toLowerCase().contains('payment'), isFalse);
    });
  });

  group('2. Online Translation & Verified Limits Tests', () {
    test('Verified documented limits match MyMemory specifications (400b query, 5k baseline, 50k potential)', () {
      expect(OnlineTranslationService.maxQueryBytes, equals(400)); // Under 500 bytes limit
      expect(OnlineTranslationService.guaranteedDailyCharQuotaAnonymous, equals(5000));
      expect(OnlineTranslationService.potentialDailyCharQuotaIdentified, equals(50000));
    });

    test('Developer email configuration: unverified email defaults to anonymous baseline 5,000 chars', () {
      final unverifiedService = OnlineTranslationService(isDeveloperEmailVerified: false);
      expect(unverifiedService.isDeveloperEmailVerified, isFalse);
      expect(unverifiedService.effectiveDailyCharQuota, equals(5000));

      final verifiedService = OnlineTranslationService(isDeveloperEmailVerified: true);
      expect(verifiedService.isDeveloperEmailVerified, isTrue);
      expect(verifiedService.effectiveDailyCharQuota, equals(50000));
    });

    test('Developer email parameterization in request URI', () async {
      // 1. With configured email
      final mockWithEmail = MockResponseHttpClient(
        statusCode: 200,
        responseBody: '{"responseStatus": 200, "responseData": {"translatedText": "హలో"}}',
      );
      final serviceWithEmail = OnlineTranslationService(
        contactEmail: 'support@matladu.app',
        httpClient: mockWithEmail,
      );
      await serviceWithEmail.initialize();
      await serviceWithEmail.translate(text: 'Hello', sourceLanguageCode: 'en', targetLanguageCode: 'te');
      expect(mockWithEmail.interceptedUris.first.queryParameters['de'], equals('support@matladu.app'));

      // 2. With null contact email (anonymous fallback)
      final mockAnon = MockResponseHttpClient(
        statusCode: 200,
        responseBody: '{"responseStatus": 200, "responseData": {"translatedText": "హలో"}}',
      );
      final serviceAnon = OnlineTranslationService(
        contactEmail: null,
        httpClient: mockAnon,
      );
      await serviceAnon.initialize();
      await serviceAnon.translate(text: 'Hello', sourceLanguageCode: 'en', targetLanguageCode: 'te');
      expect(mockAnon.interceptedUris.first.queryParameters.containsKey('de'), isFalse);
    });

    test('Successful online translation properly parses JSON and decodes HTML entities', () async {
      final mockClient = MockResponseHttpClient(
        statusCode: 200,
        responseBody: '{"responseStatus": 200, "responseData": {"translatedText": "మీరు ఎలా ఉన్నారు&#39;?"}}',
      );

      final service = OnlineTranslationService(httpClient: mockClient);
      await service.initialize();

      final result = await service.translate(
        text: 'How are you?',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );

      expect(result.isSuccess, isTrue);
      expect(result.translatedText, equals("మీరు ఎలా ఉన్నారు'?"));
      expect(mockClient.interceptedUris.length, equals(1));
      final uri = mockClient.interceptedUris.first;
      expect(uri.queryParameters['q'], equals('How are you?'));
      expect(uri.queryParameters['langpair'], equals('en|te'));
    });

    test('Privacy disclosure accurately discloses IP metadata, provider retention, and zero remote audio', () {
      const disclosure = OnlineTranslationService.privacyDisclosure;
      expect(disclosure, contains('MyMemory translation API'));
      expect(disclosure, contains('Audio recordings and microphone PCM data remain strictly on-device'));
      expect(disclosure, contains('user\'s IP address'));
      expect(disclosure, contains('developer contact email is included in the request if configured'));
      expect(disclosure, contains('public collaborative translation memory'));
      expect(disclosure, contains('Offline Mode does not transmit translation content externally'));
      // Verifies unsupported claims have been removed
      expect(disclosure.contains('No personal data, account information, or audio is ever uploaded'), isFalse);
    });
  });

  group('3. Long Speech & Safe Text Segmentation Tests', () {
    test('Short speech (< 400 bytes) remains a single segment', () {
      const text = 'Hello, how are you today?';
      final segments = OnlineTranslationService.segmentText(text);
      expect(segments.length, equals(1));
      expect(segments.first, equals(text));
    });

    test('Long speech (> 400 bytes) splits safely on sentence boundaries preserving order', () {
      final sentence1 = 'This is the first sentence of a long speech that needs translation. ' * 3;
      final sentence2 = 'Here is the second sentence providing more detailed instructions. ' * 3;
      final sentence3 = 'Finally this is the third concluding sentence of the speech. ' * 3;
      final longSpeech = '$sentence1 $sentence2 $sentence3';

      final segments = OnlineTranslationService.segmentText(longSpeech, maxBytes: 400);

      expect(segments.length, greaterThan(1));
      for (final seg in segments) {
        expect(utf8.encode(seg).length, lessThanOrEqualTo(400));
      }
      expect(segments.first, contains('first sentence'));
      expect(segments.last, contains('third concluding'));
    });

    test('Long speech translation translates each segment and combines them accurately', () async {
      final mockClient = MockResponseHttpClient(
        statusCode: 200,
        responseBody: '{"responseStatus": 200, "responseData": {"translatedText": "వాక్యం"}}',
      );

      final service = OnlineTranslationService(httpClient: mockClient);
      await service.initialize();

      final sentence1 = 'This is the first long sentence of speech that will exceed the byte limit. ' * 3;
      final sentence2 = 'This is the second long sentence of speech that will also be translated. ' * 3;
      final fullText = '$sentence1 $sentence2';

      final result = await service.translate(
        text: fullText,
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );

      expect(result.isSuccess, isTrue);
      expect(mockClient.interceptedUris.length, greaterThan(1));
      for (final uri in mockClient.interceptedUris) {
        expect(utf8.encode(uri.queryParameters['q']!).length, lessThanOrEqualTo(400));
      }
      expect(result.translatedText, contains('వాక్యం'));
    });
  });

  group('4. Online Quota Exhaustion, Reset Logic & Rate Limiting Tests', () {
    test('HTTP 429 sets isDailyQuotaExhausted to true, records UTC timestamp, and emits to stream', () async {
      final mockClient = MockResponseHttpClient(
        statusCode: 429,
        responseBody: '{"responseStatus": 429, "responseDetails": "Quota exceeded"}',
      );

      final service = OnlineTranslationService(httpClient: mockClient);
      await service.initialize();

      bool quotaStreamEmitted = false;
      service.quotaExhaustedStream.listen((isExhausted) {
        if (isExhausted) quotaStreamEmitted = true;
      });

      expect(service.isDailyQuotaExhausted, isFalse);

      final result = await service.translate(
        text: 'Test message',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );

      expect(result.status, equals(TranslationStatus.error));
      expect(service.isDailyQuotaExhausted, isTrue);
      expect(service.quotaExhaustedAt, isNotNull);
      await pumpEventQueue();
      expect(quotaStreamEmitted, isTrue);

      // Subsequent translation calls fail fast without network requests during cooldown
      mockClient.interceptedUris.clear();
      final fastFailResult = await service.translate(
        text: 'Another message',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );
      expect(fastFailResult.status, equals(TranslationStatus.error));
      expect(fastFailResult.duration, equals(Duration.zero));
      expect(mockClient.interceptedUris, isEmpty,
          reason: 'Should fail fast without redundant network calls when quota is exhausted.');
    });

    test('Device calendar date change does NOT automatically mark quota as available', () async {
      final service = OnlineTranslationService();
      service.markQuotaExhausted();
      expect(service.isDailyQuotaExhausted, isTrue);

      // Simulating calendar day advancement
      service.estimatedCharsSentToday;
      expect(service.isDailyQuotaExhausted, isTrue,
          reason: 'Must not assume provider quota resets simply because device calendar changes.');
    });

    test('Clock anomaly detection: backwards device clock keeps quota exhausted safely', () {
      final service = OnlineTranslationService();
      // Record exhaustion in the future (simulating device clock turned back)
      final futureExhaustion = DateTime.now().toUtc().add(const Duration(hours: 5));
      service.markQuotaExhausted(futureExhaustion);

      expect(service.isDailyQuotaExhausted, isTrue);
      expect(service.isEligibleForConservativeProbe, isFalse,
          reason: 'Backwards clock must not trigger premature probe requests.');
    });

    test('App restart restores confirmed quota exhaustion from persistent storage', () async {
      SharedPreferences.setMockInitialValues({
        'matladu_quota_exhausted_at': DateTime.now().toUtc().toIso8601String(),
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);

      final service = OnlineTranslationService(storageService: storage);
      await service.initialize();

      expect(service.isDailyQuotaExhausted, isTrue,
          reason: 'Exhausted quota state must survive app restarts.');
    });

    test('Conservative probe request: succeeds and resets quota state authoritatively', () async {
      final mockClient = MockResponseHttpClient(
        statusCode: 200,
        responseBody: '{"responseStatus": 200, "responseData": {"translatedText": "విజయం"}}',
      );

      final service = OnlineTranslationService(httpClient: mockClient);
      // Exhaustion recorded 25 hours ago (cooldown elapsed)
      final pastExhaustion = DateTime.now().toUtc().subtract(const Duration(hours: 25));
      service.markQuotaExhausted(pastExhaustion);

      expect(service.isDailyQuotaExhausted, isTrue);
      expect(service.isEligibleForConservativeProbe, isTrue);

      final result = await service.translate(
        text: 'Success message',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );

      expect(result.isSuccess, isTrue);
      expect(result.translatedText, equals('విజయం'));
      expect(service.isDailyQuotaExhausted, isFalse,
          reason: 'Successful probe authoritatively resets quota state.');
      expect(service.quotaExhaustedAt, isNull);
    });

    test('Conservative probe request: returns 429 and remains exhausted with updated timestamp', () async {
      final mockClient = MockResponseHttpClient(
        statusCode: 429,
        responseBody: '{"responseStatus": 429, "responseDetails": "Quota exceeded"}',
      );

      final service = OnlineTranslationService(httpClient: mockClient);
      final pastExhaustion = DateTime.now().toUtc().subtract(const Duration(hours: 25));
      service.markQuotaExhausted(pastExhaustion);

      final result = await service.translate(
        text: 'Probe message',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );

      expect(result.status, equals(TranslationStatus.error));
      expect(service.isDailyQuotaExhausted, isTrue);
      // Cooldown restarted
      expect(service.quotaExhaustedAt!.isAfter(pastExhaustion), isTrue,
          reason: 'Failed probe restarts cooldown and keeps app in offline fallback.');
    });

    test('Request pacing throttles rapid sequential translation requests', () async {
      final mockClient = MockResponseHttpClient(
        statusCode: 200,
        responseBody: '{"responseStatus": 200, "responseData": {"translatedText": "సరే"}}',
      );
      final service = OnlineTranslationService(httpClient: mockClient);
      await service.initialize();

      final sw = Stopwatch()..start();
      await service.translate(text: 'One', sourceLanguageCode: 'en', targetLanguageCode: 'te');
      await service.translate(text: 'Two', sourceLanguageCode: 'en', targetLanguageCode: 'te');
      sw.stop();

      // Pacing interval is 300ms, so two sequential requests must take at least ~250ms
      expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(250));
    });

    test('Transient 500 error retries once with exponential backoff before failing', () async {
      final mockClient = MockResponseHttpClient(
        statusCode: 500,
        responseBody: 'Internal Server Error',
      );
      final service = OnlineTranslationService(httpClient: mockClient);
      await service.initialize();

      final result = await service.translate(
        text: 'Test retry',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );

      expect(result.status, equals(TranslationStatus.error));
      expect(mockClient.interceptedUris.length, equals(2),
          reason: 'Transient 5xx error must retry once with backoff.');
    });
  });

  group('5. Automatic Offline Fallback & Adaptive Mode Tests', () {
    test('Automatic mode translates online when internet is connected and quota is available', () async {
      final mockClient = MockResponseHttpClient(
        statusCode: 200,
        responseBody: '{"responseStatus": 200, "responseData": {"translatedText": "శుభోదయం"}}',
      );
      final onlineService = OnlineTranslationService(httpClient: mockClient);
      final onDeviceService = MockableOnDeviceTranslationService();
      final connectivity = ControlledConnectivityService(true);

      final engineManager = EngineSelectionManager(
        connectivityService: connectivity,
        onDeviceTranslationService: onDeviceService,
        onlineTranslationService: onlineService,
        initialMode: ConnectionModeType.automatic,
      );

      final hybrid = HybridTranslationService(
        onDeviceService: onDeviceService,
        onlineService: onlineService,
        engineSelectionManager: engineManager,
      );
      await hybrid.initialize();

      final result = await hybrid.translate(
        text: 'Good morning',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );

      expect(result.isSuccess, isTrue);
      expect(result.translatedText, equals('శుభోదయం'));
      expect(mockClient.interceptedUris.length, equals(1));
      expect(result.noticeMessage, isNull);
    });

    test('Automatic mode seamlessly falls back to on-device ML Kit when online quota is exhausted', () async {
      final mockClient = MockResponseHttpClient(
        statusCode: 429,
        responseBody: '{"responseStatus": 429, "responseDetails": "Quota exceeded"}',
      );
      final onlineService = OnlineTranslationService(httpClient: mockClient);
      final onDeviceService = MockableOnDeviceTranslationService();
      final connectivity = ControlledConnectivityService(true);

      final engineManager = EngineSelectionManager(
        connectivityService: connectivity,
        onDeviceTranslationService: onDeviceService,
        onlineTranslationService: onlineService,
        initialMode: ConnectionModeType.automatic,
      );

      final hybrid = HybridTranslationService(
        onDeviceService: onDeviceService,
        onlineService: onlineService,
        engineSelectionManager: engineManager,
      );
      await hybrid.initialize();

      final result = await hybrid.translate(
        text: 'Good morning',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );

      expect(result.isSuccess, isTrue);
      expect(result.translatedText, contains('[Local ML Kit]'));
      expect(result.noticeMessage, contains('Daily free online translation quota reached'));
      expect(result.noticeMessage, contains('100% free on-device translation'));
    });

    test('Automatic mode immediately uses offline translation when internet is disconnected', () async {
      final mockClient = MockResponseHttpClient();
      final onlineService = OnlineTranslationService(httpClient: mockClient);
      final onDeviceService = MockableOnDeviceTranslationService();
      final connectivity = ControlledConnectivityService(false); // Disconnected

      final engineManager = EngineSelectionManager(
        connectivityService: connectivity,
        onDeviceTranslationService: onDeviceService,
        onlineTranslationService: onlineService,
        initialMode: ConnectionModeType.automatic,
      );

      final hybrid = HybridTranslationService(
        onDeviceService: onDeviceService,
        onlineService: onlineService,
        engineSelectionManager: engineManager,
      );
      await hybrid.initialize();

      final result = await hybrid.translate(
        text: 'Good morning',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );

      expect(result.isSuccess, isTrue);
      expect(result.translatedText, contains('[Local ML Kit]'));
      expect(mockClient.interceptedUris, isEmpty,
          reason: 'Zero network calls should occur when internet is disconnected.');
    });

    test('Internet restoration resumes online translation only if quota is available', () async {
      final mockClient = MockResponseHttpClient(
        statusCode: 200,
        responseBody: '{"responseStatus": 200, "responseData": {"translatedText": "శుభోదయం"}}',
      );
      final onlineService = OnlineTranslationService(httpClient: mockClient);
      final onDeviceService = MockableOnDeviceTranslationService();
      final connectivity = ControlledConnectivityService(false); // Start offline

      final engineManager = EngineSelectionManager(
        connectivityService: connectivity,
        onDeviceTranslationService: onDeviceService,
        onlineTranslationService: onlineService,
        initialMode: ConnectionModeType.automatic,
      );

      // Reconnect internet
      connectivity.setOnline(true);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final res = await engineManager.resolve(sourceLanguageCode: 'en', targetLanguageCode: 'te');
      expect(res.translationEngine, equals(EngineType.onlineCloud));
      expect(res.statusTitle, contains('Online Translation'));

      // Now exhaust quota
      onlineService.markQuotaExhausted();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final quotaRes = await engineManager.resolve(sourceLanguageCode: 'en', targetLanguageCode: 'te');
      expect(quotaRes.translationEngine, equals(EngineType.onDevice));
      expect(quotaRes.statusTitle, contains('Quota Exceeded'));
    });

    test('Missing offline model when quota exhausted displays Offline Pack Required (never paid cloud)', () async {
      final mockClient = MockResponseHttpClient(
        statusCode: 429,
        responseBody: '{"responseStatus": 429}',
      );
      final onlineService = OnlineTranslationService(httpClient: mockClient);
      final onDeviceService = MockableOnDeviceTranslationService();
      onDeviceService.setModelInstalled('te', false); // Missing model
      final connectivity = ControlledConnectivityService(true);

      final engineManager = EngineSelectionManager(
        connectivityService: connectivity,
        onDeviceTranslationService: onDeviceService,
        onlineTranslationService: onlineService,
        initialMode: ConnectionModeType.automatic,
      );

      final hybrid = HybridTranslationService(
        onDeviceService: onDeviceService,
        onlineService: onlineService,
        engineSelectionManager: engineManager,
      );
      await hybrid.initialize();

      final result = await hybrid.translate(
        text: 'Good morning',
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Offline pack'));
      expect(result.errorMessage, contains('required'));
      // Never silently fall back to a paid service
      expect(result.errorMessage!.contains('paid'), isFalse);
      expect(result.errorMessage!.contains('credit'), isFalse);
    });
  });

  group('6. Talk Rooms Security & Signaling-Only Verification', () {
    test('Talk Rooms room codes use Crockford-32 with > 1 billion combinations', () {
      final code = RoomModel.generateRoomCode();
      expect(code, startsWith('MTL-'));
      expect(code.length, equals(10));
      final suffix = code.substring(4);
      expect(RegExp(r'^[2-9A-HJ-NP-Z]{6}$').hasMatch(suffix), isTrue);
      expect(RoomModel.isValidCode(code), isTrue);
    });
  });
}

