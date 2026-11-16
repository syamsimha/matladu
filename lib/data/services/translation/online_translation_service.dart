import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../models/translation_result.dart';
import '../asr/transcript_validator.dart';
import '../local_storage_service.dart';
import 'i_translation_service.dart';

/// Privacy-Preserving Online Neural Translation Service.
///
/// PERMANENT FREE FOREVER POLICY & DATA HANDLING:
/// 1. Matladu is 100% Free Forever. No subscriptions, ads, or paid credits.
/// 2. Audio recordings, microphone buffers, and speech audio NEVER leave the device.
/// 3. Only recognized text is transmitted to the external translation provider (MyMemory API).
/// 4. Recognized and translated text are NEVER logged in console or system logs.
/// 5. Operates without bundled secret API keys (uses keyless public tier with optional contact email).
/// 6. Verified provider free tier limits:
///    - Guaranteed baseline (Anonymous): 5,000 chars/day per IP.
///    - Potential elevated allowance (requires verified owner-controlled email): 50,000 chars/day.
///    - Query limit: 500 bytes per request (safe segmentation threshold: 400 bytes).
///    - Rate limits: Subject to provider dynamic throttling; sensible client-side pacing is enforced.
/// 7. Data retention disclosure: MyMemory retains submitted text segments in their public collaborative
///    translation memory. Standard network request metadata (including user's IP) is received by the provider.
/// 8. When quota is exhausted (HTTP 429), the provider response is authoritative. The system marks quota status,
///    persists the exhaustion timestamp across app restarts, avoids redundant network calls, and triggers
///    seamless, 100% free automatic offline fallback to on-device ML Kit.
class OnlineTranslationService implements ITranslationService {
  final _resultController = StreamController<TranslationResult>.broadcast();
  final _quotaExhaustedController = StreamController<bool>.broadcast();
  final LocalStorageService? _storageService;
  final String? _customEndpointUrl;
  final String? _contactEmail;
  final bool _isDeveloperEmailVerified;
  HttpClient? _httpClient;

  /// Verified MyMemory API limits from official documentation.
  static const int maxQueryBytes = 400; // Safe threshold below documented 500-byte limit
  static const int guaranteedDailyCharQuotaAnonymous = 5000;
  static const int potentialDailyCharQuotaIdentified = 50000;
  static const String defaultContactEmail = 'support@matladu.app';

  /// Backward-compatible aliases
  static int get dailyCharQuotaIdentified => potentialDailyCharQuotaIdentified;
  static int get dailyCharQuotaAnonymous => guaranteedDailyCharQuotaAnonymous;
  static String get contactEmail => defaultContactEmail;

  /// Conservative cooldown period before retrying online translation after confirmed quota exhaustion.
  /// MyMemory resets quotas on a rolling 24-hour cycle or midnight UTC.
  static const Duration expectedResetCooldown = Duration(hours: 24);

  /// Pacing delay between sequential network requests to prevent server flooding.
  static const Duration requestPacingInterval = Duration(milliseconds: 300);

  /// Network socket connection and response timeout (not to be confused with rate limiting).
  static const Duration requestTimeout = Duration(seconds: 7);

  /// Accurate public privacy disclosure for Online Mode.
  /// Transparently discloses external text processing, IP receipt, and provider data retention.
  static const String privacyDisclosure =
      'Online Mode transmits recognized speech text to the external MyMemory translation API. '
      'Audio recordings and microphone PCM data remain strictly on-device. '
      'The API provider receives standard network request metadata, including the user\'s IP address. '
      'The developer contact email is included in the request if configured. '
      'Submitted text segments may be retained by the provider according to their terms (public collaborative translation memory). '
      'Offline Mode does not transmit translation content externally.';

  /// Default public keyless endpoint.
  static const String defaultEndpoint = 'https://api.mymemory.translated.net/get';

  // Quota & Rate Limit State
  bool _isDailyQuotaExhausted = false;
  DateTime? _quotaExhaustedAtUtc;
  DateTime? _lastRequestTimeUtc;
  int _estimatedCharsSentToday = 0;
  DateTime _lastTrackingResetDate = DateTime.now();

  OnlineTranslationService({
    String? customEndpointUrl,
    String? contactEmail = defaultContactEmail,
    bool isDeveloperEmailVerified = false,
    LocalStorageService? storageService,
    HttpClient? httpClient,
  })  : _customEndpointUrl = customEndpointUrl,
        _contactEmail = contactEmail,
        _isDeveloperEmailVerified = isDeveloperEmailVerified,
        _storageService = storageService,
        _httpClient = httpClient;

  @override
  Stream<TranslationResult> get resultStream => _resultController.stream;

  /// Stream emitting quota exhaustion changes (true = exhausted, false = available).
  Stream<bool> get quotaExhaustedStream => _quotaExhaustedController.stream;

  /// Effective daily character allowance.
  /// Defaults to guaranteed anonymous allowance (5,000) unless a verified email is confirmed.
  int get effectiveDailyCharQuota =>
      _isDeveloperEmailVerified ? potentialDailyCharQuotaIdentified : guaranteedDailyCharQuotaAnonymous;

  /// Whether the developer contact email has been verified and confirmed controlled by project owner.
  bool get isDeveloperEmailVerified => _isDeveloperEmailVerified;

  /// Configured developer contact email.
  String? get configuredContactEmail => _contactEmail;

  /// Confirmed quota status: true when provider returns HTTP 429 or quota limit warning.
  bool get isDailyQuotaExhausted => _isDailyQuotaExhausted;

  /// UTC Timestamp when the quota exhaustion was authoritatively confirmed by the provider.
  DateTime? get quotaExhaustedAt => _quotaExhaustedAtUtc;

  /// Local client-side usage estimate of characters sent today.
  int get estimatedCharsSentToday {
    _checkDailyReset();
    return _estimatedCharsSentToday;
  }

  /// Checks whether conservative cooldown has elapsed since quota exhaustion.
  /// Safe against timezone shifts and backwards clock adjustments.
  bool get isEligibleForConservativeProbe {
    if (!_isDailyQuotaExhausted || _quotaExhaustedAtUtc == null) return true;
    final nowUtc = DateTime.now().toUtc();
    // Safe clock check: if current clock is before recorded exhaustion, device clock moved backwards.
    if (nowUtc.isBefore(_quotaExhaustedAtUtc!)) {
      debugPrint('[OnlineTranslationService] Clock anomaly detected (now < exhaustedAt). Remaining exhausted safely.');
      return false;
    }
    return nowUtc.difference(_quotaExhaustedAtUtc!) >= expectedResetCooldown;
  }

  /// Manually resets quota status (e.g. for testing or explicit user reset).
  void resetQuotaStatus() {
    _isDailyQuotaExhausted = false;
    _quotaExhaustedAtUtc = null;
    _storageService?.setQuotaExhaustedAt(null);
    _quotaExhaustedController.add(false);
    debugPrint('[OnlineTranslationService] Quota status reset to available.');
  }

  /// Marks quota as confirmed exhausted based on authoritative provider response.
  void markQuotaExhausted([DateTime? timestamp]) {
    final nowUtc = (timestamp ?? DateTime.now()).toUtc();
    _isDailyQuotaExhausted = true;
    _quotaExhaustedAtUtc = nowUtc;
    _storageService?.setQuotaExhaustedAt(nowUtc);
    _quotaExhaustedController.add(true);
    debugPrint('[OnlineTranslationService] Daily free online translation quota marked EXHAUSTED at $nowUtc.');
  }

  void _checkDailyReset() {
    final now = DateTime.now();
    if (now.day != _lastTrackingResetDate.day ||
        now.month != _lastTrackingResetDate.month ||
        now.year != _lastTrackingResetDate.year) {
      _estimatedCharsSentToday = 0;
      _lastTrackingResetDate = now;
      // NOTE: Provider quota reset is NOT assumed based on local calendar change.
      // We do NOT clear _isDailyQuotaExhausted here without authoritative provider evidence.
    }
  }

  @override
  Future<void> initialize() async {
    _httpClient ??= HttpClient()
      ..connectionTimeout = requestTimeout;
    _checkDailyReset();

    // Restore persisted quota status across app restarts
    final persisted = _storageService?.getQuotaExhaustedAt();
    if (persisted != null) {
      _quotaExhaustedAtUtc = persisted;
      _isDailyQuotaExhausted = true;
      debugPrint('[OnlineTranslationService] Restored confirmed quota exhaustion from storage (at: $persisted). Remaining in offline fallback.');
    }

    debugPrint(
      '[OnlineTranslationService] Initialized (Online Neural Translation Active • 0 Audio Egress • Free Forever • Quota: $effectiveDailyCharQuota chars/day).',
    );
  }

  @override
  bool isLanguageSupported(String languageCode) {
    final norm = _normalizeCode(languageCode);
    return [
      'as', 'bn', 'brx', 'doi', 'gu', 'hi', 'kn', 'ks', 'kok',
      'mai', 'ml', 'mni', 'mr', 'ne', 'or', 'pa', 'sa', 'sat',
      'sd', 'ta', 'te', 'ur', 'en', 'de', 'es', 'fr',
    ].contains(norm);
  }

  @override
  bool isPairSupported(String sourceCode, String targetCode) {
    return isLanguageSupported(sourceCode) && isLanguageSupported(targetCode);
  }

  @override
  Future<bool> isModelDownloaded(String languageCode) async {
    // Online translation does not require local neural model pack downloads
    return true;
  }

  @override
  Future<bool> downloadModel(
    String languageCode, {
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(1.0);
    return true;
  }

  @override
  Future<bool> deleteModel(String languageCode) async {
    return true;
  }

  /// Safely segments longer recognized speech into sub-400 byte chunks
  /// respecting sentence boundaries, clause boundaries, and UTF-8 encoding.
  /// Preserves exact sentence order and meaning.
  static List<String> segmentText(String text, {int maxBytes = maxQueryBytes}) {
    final clean = text.trim();
    if (clean.isEmpty) return [];
    if (utf8.encode(clean).length <= maxBytes) {
      return [clean];
    }

    // 1. Split by sentence terminators: (. ! ? \n | Telugu । ॥)
    final sentenceRegex = RegExp(r'([^.!?\n।॥]+[.!?\n।॥]+|[^.!?\n।॥]+$)');
    final rawSentences = sentenceRegex
        .allMatches(clean)
        .map((m) => m.group(0)!.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (rawSentences.isEmpty) {
      rawSentences.add(clean);
    }

    final List<String> segments = [];
    String currentBuffer = '';

    void flushBuffer() {
      if (currentBuffer.trim().isNotEmpty) {
        segments.add(currentBuffer.trim());
        currentBuffer = '';
      }
    }

    for (final sentence in rawSentences) {
      final sentenceBytes = utf8.encode(sentence).length;

      if (sentenceBytes <= maxBytes) {
        final testBuffer = currentBuffer.isEmpty ? sentence : '$currentBuffer $sentence';
        if (utf8.encode(testBuffer).length <= maxBytes) {
          currentBuffer = testBuffer;
        } else {
          flushBuffer();
          currentBuffer = sentence;
        }
      } else {
        // Sentence itself exceeds maxBytes: split by clause punctuation (, ; : -)
        flushBuffer();
        final clauseRegex = RegExp(r'([^,;:—–-]+[,;:—–-]+|[^,;:—–-]+$)');
        final rawClauses = clauseRegex
            .allMatches(sentence)
            .map((m) => m.group(0)!.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        for (final clause in rawClauses) {
          final clauseBytes = utf8.encode(clause).length;
          if (clauseBytes <= maxBytes) {
            final testBuffer = currentBuffer.isEmpty ? clause : '$currentBuffer $clause';
            if (utf8.encode(testBuffer).length <= maxBytes) {
              currentBuffer = testBuffer;
            } else {
              flushBuffer();
              currentBuffer = clause;
            }
          } else {
            // Clause exceeds maxBytes: split by word boundary
            flushBuffer();
            final words = clause.split(RegExp(r'\s+'));
            for (final word in words) {
              if (word.isEmpty) continue;
              final testBuffer = currentBuffer.isEmpty ? word : '$currentBuffer $word';
              if (utf8.encode(testBuffer).length <= maxBytes) {
                currentBuffer = testBuffer;
              } else {
                flushBuffer();
                if (utf8.encode(word).length <= maxBytes) {
                  currentBuffer = word;
                } else {
                  // Indivisible long token: slice on code points
                  final runes = word.runes.toList();
                  String runeChunk = '';
                  for (final r in runes) {
                    final ch = String.fromCharCode(r);
                    if (utf8.encode(runeChunk + ch).length <= maxBytes) {
                      runeChunk += ch;
                    } else {
                      if (runeChunk.isNotEmpty) segments.add(runeChunk);
                      runeChunk = ch;
                    }
                  }
                  if (runeChunk.isNotEmpty) {
                    currentBuffer = runeChunk;
                  }
                }
              }
            }
          }
        }
      }
    }
    flushBuffer();
    return segments;
  }

  @override
  Future<TranslationResult> translate({
    required String text,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) async {
    final cleanText = text.trim();
    final normSrc = _normalizeCode(sourceLanguageCode);
    final normTgt = _normalizeCode(targetLanguageCode);

    if (cleanText.isEmpty) {
      return TranslationResult(
        originalText: '',
        translatedText: '',
        sourceLanguageCode: normSrc,
        targetLanguageCode: normTgt,
        status: TranslationStatus.completed,
        timestamp: DateTime.now(),
        isMock: false,
      );
    }

    if (normSrc == normTgt) {
      return TranslationResult(
        originalText: cleanText,
        translatedText: cleanText,
        sourceLanguageCode: normSrc,
        targetLanguageCode: normTgt,
        status: TranslationStatus.completed,
        timestamp: DateTime.now(),
        isMock: false,
      );
    }

    _checkDailyReset();

    // Check confirmed quota exhaustion before making failing network requests
    if (_isDailyQuotaExhausted) {
      if (!isEligibleForConservativeProbe) {
        debugPrint(
          '[OnlineTranslationService] Daily free online translation quota is exhausted. '
          'Cooldown active until ${_quotaExhaustedAtUtc?.add(expectedResetCooldown)}. '
          'Failing fast for offline fallback without network egress.',
        );
        return _buildErrorResult(
          cleanText,
          normSrc,
          normTgt,
          'Daily free online translation quota has been reached (HTTP 429). Switching to 100% free offline translation.',
          Duration.zero,
        );
      }
      debugPrint('[OnlineTranslationService] Cooldown period elapsed. Allowing conservative probe request to verify provider quota availability.');
    }

    final segments = segmentText(cleanText, maxBytes: maxQueryBytes);

    if (segments.length <= 1) {
      return _translateSingleSegment(cleanText, normSrc, normTgt);
    }

    // Long speech segmentation: translate each segment preserving order
    debugPrint(
      '[OnlineTranslationService] Segmented long speech into ${segments.length} chunks (query <= $maxQueryBytes bytes).',
    );

    final stopwatch = Stopwatch()..start();
    final List<String> translatedPieces = [];

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final segResult = await _translateSingleSegment(seg, normSrc, normTgt);

      if (!segResult.isSuccess) {
        stopwatch.stop();
        // If a segment fails, return error for the whole text so fallback can handle it cleanly
        return _buildErrorResult(
          cleanText,
          normSrc,
          normTgt,
          segResult.errorMessage ?? 'Online translation segment failed. Switching to offline translation.',
          stopwatch.elapsed,
        );
      }
      translatedPieces.add(segResult.translatedText);
    }
    stopwatch.stop();

    final combinedTranslation = translatedPieces.join(' ');
    final result = TranslationResult(
      originalText: cleanText,
      translatedText: combinedTranslation,
      sourceLanguageCode: normSrc,
      targetLanguageCode: normTgt,
      status: TranslationStatus.completed,
      duration: stopwatch.elapsed,
      timestamp: DateTime.now(),
      isMock: false,
    );
    _resultController.add(result);
    return result;
  }

  Future<TranslationResult> _translateSingleSegment(
    String segmentText,
    String normSrc,
    String normTgt, {
    bool isRetry = false,
  }) async {
    // PRIVACY ENFORCEMENT: Never log user-spoken text or transcript content in logs.
    debugPrint(
      '[OnlineTranslationService] Requesting online translation: $normSrc -> $normTgt (${segmentText.length} chars). Zero audio egress.',
    );

    // Sensible request pacing: throttle rapid requests
    if (_lastRequestTimeUtc != null) {
      final elapsed = DateTime.now().toUtc().difference(_lastRequestTimeUtc!);
      if (elapsed < requestPacingInterval) {
        await Future<void>.delayed(requestPacingInterval - elapsed);
      }
    }
    _lastRequestTimeUtc = DateTime.now().toUtc();

    _estimatedCharsSentToday += segmentText.length;

    final stopwatch = Stopwatch()..start();
    final baseUrl = _customEndpointUrl ?? defaultEndpoint;
    final encodedQuery = Uri.encodeQueryComponent(segmentText);
    final encodedLangPair = Uri.encodeQueryComponent('$normSrc|$normTgt');
    final emailParam = (_contactEmail != null && _contactEmail.isNotEmpty)
        ? '&de=${Uri.encodeQueryComponent(_contactEmail)}'
        : '';
    final uri = Uri.parse('$baseUrl?q=$encodedQuery&langpair=$encodedLangPair$emailParam');

    try {
      final client = _httpClient ?? HttpClient();
      final request = await client.getUrl(uri).timeout(requestTimeout);
      request.headers.set('User-Agent', 'Matladu-Voice-Translation/1.0');
      request.headers.set('Accept', 'application/json');

      final response = await request.close().timeout(requestTimeout);
      final responseBody = await response.transform(utf8.decoder).join();
      stopwatch.stop();

      if (response.statusCode == 200) {
        final decodedJson = jsonDecode(responseBody) as Map<String, dynamic>;
        final responseStatus = decodedJson['responseStatus'];

        if (responseStatus == 200 || responseStatus == '200') {
          final responseData = decodedJson['responseData'] as Map<String, dynamic>?;
          String? translatedText = responseData?['translatedText'] as String?;

          // Fallback to highest quality match if translatedText is missing or empty
          if (translatedText == null || translatedText.trim().isEmpty) {
            final matches = decodedJson['matches'] as List<dynamic>?;
            if (matches != null && matches.isNotEmpty) {
              for (final match in matches) {
                final matchText = match['translation'] as String?;
                if (matchText != null && matchText.trim().isNotEmpty) {
                  translatedText = matchText;
                  break;
                }
              }
            }
          }

          // If direct pair returned empty or missing translation, try English pivot
          if ((translatedText == null || translatedText.trim().isEmpty) &&
              normSrc != 'en' &&
              normTgt != 'en' &&
              !isRetry) {
            debugPrint('[OnlineTranslationService] Direct pair returned empty. Pivoting via English bridge ($normSrc -> en -> $normTgt)...');
            final step1 = await _translateSingleSegment(segmentText, normSrc, 'en', isRetry: true);
            if (step1.isSuccess &&
                step1.translatedText.isNotEmpty &&
                step1.translatedText.toLowerCase() != segmentText.trim().toLowerCase()) {
              final step2 = await _translateSingleSegment(step1.translatedText, 'en', normTgt, isRetry: true);
              if (step2.isSuccess && step2.translatedText.isNotEmpty) {
                return TranslationResult(
                  originalText: segmentText,
                  translatedText: step2.translatedText,
                  sourceLanguageCode: normSrc,
                  targetLanguageCode: normTgt,
                  status: TranslationStatus.completed,
                  duration: stopwatch.elapsed,
                  timestamp: DateTime.now(),
                  isMock: false,
                );
              }
            }
          }

          if (translatedText != null && translatedText.trim().isNotEmpty) {
            // Authoritative evidence that quota is available!
            if (_isDailyQuotaExhausted) {
              debugPrint('[OnlineTranslationService] Authoritative probe succeeded. Provider confirmed quota available again.');
              resetQuotaStatus();
            }

            final cleanResult = _decodeHtmlEntities(translatedText.trim());
            final bool hasScriptMismatch = !TranscriptValidator.isScriptValidForTarget(cleanResult, normTgt);

            // If direct translation echoed original text or returned mismatched script, pivot via English bridge
            if ((cleanResult.toLowerCase() == segmentText.trim().toLowerCase() || hasScriptMismatch) &&
                normSrc != 'en' &&
                normTgt != 'en' &&
                !isRetry) {
              debugPrint('[OnlineTranslationService] Direct translation echoed original text or had script mismatch. Pivoting via English bridge ($normSrc -> en -> $normTgt)...');
              final step1 = await _translateSingleSegment(segmentText, normSrc, 'en', isRetry: true);
              if (step1.isSuccess &&
                  step1.translatedText.isNotEmpty &&
                  step1.translatedText.toLowerCase() != segmentText.trim().toLowerCase()) {
                final step2 = await _translateSingleSegment(step1.translatedText, 'en', normTgt, isRetry: true);
                if (step2.isSuccess &&
                    step2.translatedText.isNotEmpty &&
                    TranscriptValidator.isScriptValidForTarget(step2.translatedText, normTgt)) {
                  return TranslationResult(
                    originalText: segmentText,
                    translatedText: step2.translatedText,
                    sourceLanguageCode: normSrc,
                    targetLanguageCode: normTgt,
                    status: TranslationStatus.completed,
                    duration: stopwatch.elapsed,
                    timestamp: DateTime.now(),
                    isMock: false,
                  );
                }
              }
            }

            // Reject invalid output if script mismatch remains
            if (hasScriptMismatch) {
              return _buildErrorResult(
                segmentText,
                normSrc,
                normTgt,
                'Translation provider returned mismatched language output for $normTgt. Switching to offline translation.',
                stopwatch.elapsed,
              );
            }

            final result = TranslationResult(
              originalText: segmentText,
              translatedText: cleanResult,
              sourceLanguageCode: normSrc,
              targetLanguageCode: normTgt,
              status: TranslationStatus.completed,
              duration: stopwatch.elapsed,
              timestamp: DateTime.now(),
              isMock: false,
            );
            return result;
          }
        } else if (responseStatus == 429 || responseStatus == '429' ||
            (decodedJson['responseDetails']?.toString().toUpperCase().contains('ALL AVAILABLE FREE TRANSLATIONS') ?? false)) {
          markQuotaExhausted();
          return _buildErrorResult(
            segmentText,
            normSrc,
            normTgt,
            'Daily free online translation quota has been reached (HTTP 429). Switching to 100% free offline translation.',
            stopwatch.elapsed,
          );
        }
      } else if (response.statusCode == 429) {
        markQuotaExhausted();
        return _buildErrorResult(
          segmentText,
          normSrc,
          normTgt,
          'Daily free online translation quota has been reached (HTTP 429). Switching to 100% free offline translation.',
          stopwatch.elapsed,
        );
      } else if (response.statusCode >= 500 && response.statusCode < 600 && !isRetry) {
        // Transient server error: retry once with exponential backoff
        debugPrint('[OnlineTranslationService] Provider returned HTTP ${response.statusCode}. Retrying once with 500ms backoff...');
        await Future<void>.delayed(const Duration(milliseconds: 500));
        return await _translateSingleSegment(segmentText, normSrc, normTgt, isRetry: true);
      }

      // If response was not 200/429 or parsing failed
      return _buildErrorResult(
        segmentText,
        normSrc,
        normTgt,
        'Online translation service returned HTTP ${response.statusCode}. Switching to offline translation.',
        stopwatch.elapsed,
      );
    } on TimeoutException {
      stopwatch.stop();
      debugPrint('[OnlineTranslationService] Network timeout contacting translation service.');
      return _buildErrorResult(
        segmentText,
        normSrc,
        normTgt,
        'Online translation request timed out. Please check internet connection or switch to Offline Mode.',
        stopwatch.elapsed,
      );
    } on SocketException catch (e) {
      stopwatch.stop();
      debugPrint('[OnlineTranslationService] Network connection error: ${e.message}');
      return _buildErrorResult(
        segmentText,
        normSrc,
        normTgt,
        'Cannot reach online translation server. Please check your network or switch to Offline Mode.',
        stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('[OnlineTranslationService] Translation exception: $e');
      return _buildErrorResult(
        segmentText,
        normSrc,
        normTgt,
        'Online translation error: $e',
        stopwatch.elapsed,
      );
    }
  }

  TranslationResult _buildErrorResult(
    String text,
    String src,
    String tgt,
    String message,
    Duration duration,
  ) {
    final result = TranslationResult(
      originalText: text,
      translatedText: '',
      sourceLanguageCode: src,
      targetLanguageCode: tgt,
      status: TranslationStatus.error,
      errorMessage: message,
      duration: duration,
      timestamp: DateTime.now(),
      isMock: false,
    );
    _resultController.add(result);
    return result;
  }

  /// Decodes common HTML entity representations returned by translation memory APIs.
  static String _decodeHtmlEntities(String input) {
    return input
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&#039;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#x27;', "'")
        .replaceAll('&#x2F;', '/');
  }

  static String _normalizeCode(String? code) {
    if (code == null || code.isEmpty) return 'en';
    final lower = code.replaceAll('<|', '').replaceAll('|>', '').toLowerCase().trim();
    return lower.split('-').first.split('_').first;
  }

  @override
  Future<void> dispose() async {
    _httpClient?.close(force: true);
    await _quotaExhaustedController.close();
    await _resultController.close();
  }
}
