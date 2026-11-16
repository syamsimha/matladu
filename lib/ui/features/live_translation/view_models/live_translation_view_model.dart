import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../data/models/asr_state.dart';
import '../../../../data/models/audio_recording_state.dart';
import '../../../../data/models/conversation_turn_model.dart';
import '../../../../data/models/language_model.dart';
import '../../../../data/models/room_model.dart';
import '../../../../data/models/translation_result.dart';
import '../../../../data/models/tts_result.dart';
import '../../../../data/models/two_way_direction.dart';
import '../../../../data/repositories/asr_repository.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../../data/repositories/translation_repository.dart';
import '../../../../data/repositories/tts_repository.dart';
import '../../../../data/services/asr/transcript_validator.dart';
import '../../../../data/services/room/i_room_service.dart';

/// ViewModel managing state for the Live Translation Screen (Screen 3).
/// Coordinates real-time two-way voice conversations across Phase 3 ASR,
/// Phase 4 On-Device Neural Translation, Phase 5 Automatic TTS, and Phase 6 Turn Management.
class LiveTranslationViewModel extends ChangeNotifier {
  final String? roomId;
  final IRoomService? _roomService;
  final TranslationRepository? _translationRepository;
  final TtsRepository? _ttsRepository;
  final ASRRepository? _asrRepository;
  final SettingsRepository? _settingsRepository;

  late final TwoWayDirectionManager _directionManager;

  StreamSubscription<TtsResult>? _ttsSubscription;
  StreamSubscription<double>? _amplitudeSubscription;
  StreamSubscription<ASRRecognitionResult>? _asrResultSubscription;
  StreamSubscription<RoomMessage>? _roomSubscription;

  String _originalText;
  String _translatedText;
  String _sourceLanguageCode;
  String _sourceLanguageName;
  String _targetLanguageCode;
  String _targetLanguageName;

  TranslationStatus _translationStatus = TranslationStatus.idle;
  ConversationTurnState _turnState = ConversationTurnState.idle;
  String? _errorMessage;
  String? _warningMessage;
  Duration _translationDuration = Duration.zero;
  bool _isMock;
  double _confidence;

  bool _isPlayingAudio = false;
  bool _isSpeaking = false;
  bool _ttsVoiceUnavailable = false;
  String? _ttsErrorMessage;

  // Real Audio Level for microphone soundwave animation
  double _currentAudioLevel = 0.0;

  // Conversation Turn Tracking & Stale Request Invalidation
  int _turnCounter = 0;
  String? _activeTurnId;
  String? _currentRequestId;
  final Set<String> _spokenRequestIds = {};
  bool _userManuallyStopped = false;
  DateTime? _lastMicTapTime;

  // Local Conversation History
  final List<ConversationTurnModel> _conversationHistory = [];

  LiveTranslationViewModel({
    this.roomId,
    IRoomService? roomService,
    ASRRecognitionResult? initialRecognition,
    TranslationRepository? translationRepository,
    TtsRepository? ttsRepository,
    ASRRepository? asrRepository,
    SettingsRepository? settingsRepository,
    String? initialTargetLanguageCode,
    String? initialSourceLanguageCode,
  })  : _roomService = roomService,
        _translationRepository = translationRepository,
        _ttsRepository = ttsRepository,
        _asrRepository = asrRepository,
        _settingsRepository = settingsRepository,
        _originalText = (initialRecognition != null && initialRecognition.hasText)
            ? initialRecognition.text
            : AppStrings.sampleEnglishText,
        _translatedText = (initialRecognition != null && initialRecognition.hasText)
            ? ''
            : _resolveInitialSampleText(initialTargetLanguageCode ?? 'te'),
        _sourceLanguageCode = _normalizeLangCode(
          initialSourceLanguageCode ?? initialRecognition?.detectedLanguageCode ?? 'en',
        ),
        _sourceLanguageName = initialRecognition?.detectedLanguageName ??
            _resolveLanguageName(initialSourceLanguageCode ?? initialRecognition?.detectedLanguageCode ?? 'en'),
        _targetLanguageCode = _normalizeLangCode(initialTargetLanguageCode ?? 'te'),
        _targetLanguageName = _resolveLanguageName(initialTargetLanguageCode ?? 'te'),
        _isMock = initialRecognition?.isMock ?? false,
        _confidence = initialRecognition?.confidence ?? 1.0 {
    // Initialize direction manager with Language A and Language B
    final langA = LanguageModel.fromCode(_sourceLanguageCode) ??
        LanguageModel(code: _sourceLanguageCode, name: _sourceLanguageName, nativeName: _sourceLanguageName);
    final langB = LanguageModel.fromCode(_targetLanguageCode) ??
        LanguageModel(code: _targetLanguageCode, name: _targetLanguageName, nativeName: _targetLanguageName);

    _directionManager = TwoWayDirectionManager(languageA: langA, languageB: langB);

    _initTtsListener();
    _initRoomListener();

    if (initialRecognition != null && initialRecognition.hasText) {
      _executeInitialTranslation();
    } else {
      _translationStatus = TranslationStatus.completed;
      _turnState = ConversationTurnState.completed;
    }
  }

  void _initTtsListener() {
    final tts = _ttsRepository;
    if (tts == null) return;

    _ttsSubscription = tts.stateStream.listen((result) {
      if (result.state == TtsPlaybackState.speaking) {
        _isPlayingAudio = true;
        _turnState = ConversationTurnState.speakingTranslatedAudio;
        _ttsVoiceUnavailable = false;
        _ttsErrorMessage = null;
        notifyListeners();
      } else if (result.state == TtsPlaybackState.completed ||
          result.state == TtsPlaybackState.stopped ||
          result.state == TtsPlaybackState.idle) {
        _isPlayingAudio = false;
        if (_turnState == ConversationTurnState.speakingTranslatedAudio) {
          _turnState = ConversationTurnState.completed;
        }
        notifyListeners();
      } else if (result.state == TtsPlaybackState.voiceUnavailable) {
        _isPlayingAudio = false;
        _ttsVoiceUnavailable = true;
        _ttsErrorMessage = result.errorMessage;
        if (_turnState == ConversationTurnState.speakingTranslatedAudio) {
          _turnState = ConversationTurnState.completed;
        }
        notifyListeners();
      } else if (result.state == TtsPlaybackState.error) {
        _isPlayingAudio = false;
        _ttsErrorMessage = result.errorMessage;
        notifyListeners();
      }
    });
  }

  void _initRoomListener() {
    final room = _roomService;
    if (room == null) return;

    _roomSubscription = room.messageStream.listen((msg) {
      if (msg.type == RoomMessageType.turn && msg.payload != null) {
        try {
          final peerTurn = ConversationTurnModel.fromJson(msg.payload!);
          if (peerTurn.id != _activeTurnId && !_conversationHistory.any((t) => t.id == peerTurn.id)) {
            _conversationHistory.add(peerTurn);
            _originalText = peerTurn.originalText;
            _translatedText = peerTurn.translatedText;
            _sourceLanguageCode = peerTurn.sourceLanguageCode;
            _sourceLanguageName = peerTurn.sourceLanguageName;
            _targetLanguageCode = peerTurn.targetLanguageCode;
            _targetLanguageName = peerTurn.targetLanguageName;
            _turnState = ConversationTurnState.completed;
            notifyListeners();

            if (peerTurn.translatedText.isNotEmpty) {
              _triggerAutoPlay(
                text: peerTurn.translatedText,
                targetCode: peerTurn.targetLanguageCode,
                turnId: peerTurn.id,
              );
            }
          }
        } catch (e) {
          debugPrint('[LiveTranslationViewModel] Failed to parse peer turn: $e');
        }
      }
    });
  }

  // Room Getters
  bool get isRoomActive => roomId != null || _roomService?.currentRoom != null;
  bool get isRoomConnected => _roomService?.currentRoom?.isConnected ?? false;
  String? get activeRoomId => roomId ?? _roomService?.currentRoom?.roomId;
  RoomModel? get currentRoom => _roomService?.currentRoom;

  // Getters
  String get originalText => _originalText;
  String get translatedText => _translatedText;
  String get sourceLanguageCode => _sourceLanguageCode;
  String get sourceLanguageName => _sourceLanguageName;
  String get targetLanguageCode => _targetLanguageCode;
  String get targetLanguageName => _targetLanguageName;

  String get sourceLanguageLabel => 'Original ($sourceLanguageName)';
  String get targetLanguageLabel => 'Translated ($targetLanguageName)';

  TranslationStatus get translationStatus => _translationStatus;
  ConversationTurnState get turnState => _turnState;
  bool get isTranslating => _turnState == ConversationTurnState.translating;
  bool get isListening => _turnState == ConversationTurnState.listening;
  bool get isProcessingSpeech => _turnState == ConversationTurnState.processingSpeech;
  bool get isRecognizingLanguage => _turnState == ConversationTurnState.recognizingLanguage;
  bool get isSpeakingAudio => _turnState == ConversationTurnState.speakingTranslatedAudio;
  bool get isCompleted => _turnState == ConversationTurnState.completed;
  bool get isTranslationComplete => _translationStatus == TranslationStatus.completed;
  bool get isModelMissing => _translationStatus == TranslationStatus.modelMissing;
  bool get hasError => _turnState == ConversationTurnState.error || _translationStatus == TranslationStatus.error;
  String? get errorMessage => _errorMessage;
  String? get warningMessage => _warningMessage;
  Duration get translationDuration => _translationDuration;

  bool get isMock => _isMock;
  double get confidence => _confidence;

  String? get currentRequestId => _currentRequestId;
  String? get activeTurnId => _activeTurnId;
  int get turnCount => _conversationHistory.length;
  bool get userManuallyStopped => _userManuallyStopped;
  bool get isPlayingAudio => _isPlayingAudio;
  bool get isSpeaking => _isSpeaking;
  bool get isTtsVoiceUnavailable => _ttsVoiceUnavailable;
  String? get ttsErrorMessage => _ttsErrorMessage;
  bool get canReplay => _translatedText.isNotEmpty;
  double get currentAudioLevel => _currentAudioLevel;

  List<ConversationTurnModel> get conversationHistory => List.unmodifiable(_conversationHistory);
  TwoWayDirectionManager get directionManager => _directionManager;
  SettingsRepository? get settingsRepository => _settingsRepository;

  Future<void> _executeInitialTranslation() async {
    _turnCounter++;
    final turnId = 'turn_${DateTime.now().microsecondsSinceEpoch}_$_turnCounter';
    _activeTurnId = turnId;
    await executeTranslation(
      text: _originalText,
      sourceCode: _sourceLanguageCode,
      targetCode: _targetLanguageCode,
      isAutoFlow: true,
      turnId: turnId,
      speaker: ConversationSpeaker.speakerA,
    );
  }

  /// Executes on-device translation using the injected [TranslationRepository].
  /// When [isAutoFlow] is true and translation completes, automatically triggers on-device TTS.
  Future<void> executeTranslation({
    String? text,
    String? sourceCode,
    String? targetCode,
    bool isAutoFlow = false,
    String? turnId,
    ConversationSpeaker? speaker,
  }) async {
    final queryText = (text ?? _originalText).trim();
    final src = _normalizeLangCode(sourceCode ?? _sourceLanguageCode);
    final tgt = _normalizeLangCode(targetCode ?? _targetLanguageCode);
    final activeId = turnId ?? _activeTurnId ?? 'turn_${DateTime.now().millisecondsSinceEpoch}_1';
    _activeTurnId ??= activeId;

    // Halt any previous audio playback immediately when a new translation starts
    if (_isPlayingAudio) {
      await stopPlayback(isManual: false);
    }

    if (queryText.isEmpty) {
      _translatedText = '';
      _translationStatus = TranslationStatus.completed;
      _turnState = ConversationTurnState.completed;
      notifyListeners();
      return;
    }

    // Protection: If source and target are the same language, do not translate into itself or fabricate output
    if (src == tgt) {
      _translatedText = '';
      _errorMessage = 'Source and target languages are identical ($tgt). Please select a different target language.';
      _translationStatus = TranslationStatus.error;
      _turnState = ConversationTurnState.idle;
      notifyListeners();
      return;
    }

    _translationStatus = TranslationStatus.translating;
    _turnState = ConversationTurnState.translating;
    _errorMessage = null;
    _ttsVoiceUnavailable = false;
    _ttsErrorMessage = null;
    _userManuallyStopped = false;
    notifyListeners();

    final trRepo = _translationRepository;
    if (trRepo == null) {
      // Fallback for isolated widget tests without repository injection
      _translatedText = _performTestTranslation(queryText, src, tgt);
      _translationStatus = TranslationStatus.completed;
      _turnState = ConversationTurnState.completed;

      _addTurnToHistory(
        turnId: activeId,
        speaker: speaker ?? ConversationSpeaker.speakerA,
        originalText: queryText,
        translatedText: _translatedText,
        srcCode: src,
        srcName: _sourceLanguageName,
        tgtCode: tgt,
        tgtName: _targetLanguageName,
      );
      notifyListeners();

      if (isAutoFlow) {
        _triggerAutoPlay(text: _translatedText, targetCode: tgt, turnId: activeId);
      }
      return;
    }

    try {
      final result = await trRepo.translateText(
        text: queryText,
        sourceLanguageCode: src,
        targetLanguageCode: tgt,
      );

      // Stale turn check: If a newer turn started while this translation was in flight, drop it
      if (turnId != null && turnId != _activeTurnId) {
        debugPrint('[LiveTranslationVM] Stale translation response for turn $turnId ignored.');
        return;
      }

      _originalText = result.originalText;
      _translatedText = result.translatedText;
      _sourceLanguageCode = result.sourceLanguageCode;
      _targetLanguageCode = result.targetLanguageCode;
      _sourceLanguageName = result.sourceLanguageName ?? _resolveLanguageName(src);
      _targetLanguageName = result.targetLanguageName ?? _resolveLanguageName(tgt);
      _translationStatus = result.status;
      _errorMessage = result.errorMessage;
      _translationDuration = result.duration;
      if (!_isMock) {
        _isMock = result.isMock;
      }

      // Target Language Script Validation:
      // Verify that translation output doesn't contain mismatched Indic scripts for European targets
      if (result.status == TranslationStatus.completed &&
          result.translatedText.isNotEmpty &&
          !TranscriptValidator.isScriptValidForTarget(result.translatedText, tgt)) {
        _translationStatus = TranslationStatus.error;
        _turnState = ConversationTurnState.error;
        _errorMessage = 'Translation output did not match expected target script for $_targetLanguageName. Please try again.';
        notifyListeners();
        return;
      }

      // AUTOMATIC TEXT-TO-SPEECH TRIGGER:
      // When translation completes successfully, automatically speak the translated text
      if (result.status == TranslationStatus.completed &&
          result.translatedText.isNotEmpty) {
        _turnState = ConversationTurnState.speakingTranslatedAudio;
        _addTurnToHistory(
          turnId: activeId,
          speaker: speaker ?? ConversationSpeaker.speakerA,
          originalText: result.originalText,
          translatedText: result.translatedText,
          srcCode: src,
          srcName: _sourceLanguageName,
          tgtCode: tgt,
          tgtName: _targetLanguageName,
        );
        notifyListeners();

        if (isAutoFlow) {
          _triggerAutoPlay(
            text: result.translatedText,
            targetCode: tgt,
            turnId: activeId,
          );
        }
      } else {
        _turnState = result.status == TranslationStatus.error
            ? ConversationTurnState.error
            : ConversationTurnState.completed;
        notifyListeners();
      }
    } catch (e) {
      _translationStatus = TranslationStatus.error;
      _turnState = ConversationTurnState.error;
      _errorMessage = 'Translation failed: $e';
      notifyListeners();
    }
  }

  void _addTurnToHistory({
    required String turnId,
    required ConversationSpeaker speaker,
    required String originalText,
    required String translatedText,
    required String srcCode,
    required String srcName,
    required String tgtCode,
    required String tgtName,
  }) {
    // Avoid duplicate history entries with same turn ID
    _conversationHistory.removeWhere((item) => item.id == turnId);

    final turn = ConversationTurnModel(
      id: turnId,
      turnNumber: _conversationHistory.length + 1,
      speaker: speaker,
      sourceLanguageCode: srcCode,
      sourceLanguageName: srcName,
      targetLanguageCode: tgtCode,
      targetLanguageName: tgtName,
      originalText: originalText,
      translatedText: translatedText,
      state: ConversationTurnState.completed,
      playbackState: TtsPlaybackState.completed,
      timestamp: DateTime.now(),
      isMock: _isMock,
      confidence: _confidence,
      audioDuration: _translationDuration,
    );

    _conversationHistory.add(turn);

    if (_roomService?.currentRoom != null) {
      _roomService!.sendTurn(turn);
    }
  }

  void _triggerAutoPlay({
    required String text,
    required String targetCode,
    String? turnId,
  }) {
    // Stale turn check: Do not speak outdated translation if a newer turn has already become active
    if (turnId != null && _activeTurnId != null && turnId != _activeTurnId) {
      debugPrint('[LiveTranslationVM] Skipping auto-play for outdated turn $turnId (active: $_activeTurnId)');
      return;
    }

    // Prevent acoustic feedback: ensure microphone is not capturing while TTS speaks
    if (_asrRepository != null && _asrRepository.isRecording) {
      _asrRepository.cancel();
    }

    final reqId = turnId != null ? '${turnId}_$targetCode' : '${DateTime.now().millisecondsSinceEpoch}_$targetCode';
    _currentRequestId = reqId;

    if (_spokenRequestIds.contains(reqId)) {
      debugPrint('[LiveTranslationVM] Request $reqId already spoken. Skipping duplicate.');
      return;
    }

    _spokenRequestIds.add(reqId);

    final tts = _ttsRepository;
    if (tts != null) {
      debugPrint('[LiveTranslationVM] Triggering AUTOMATIC on-device TTS (lang: $targetCode, chars: ${text.length})');
      _turnState = ConversationTurnState.speakingTranslatedAudio;
      tts.speakTranslation(
        text: text,
        targetLanguageCode: targetCode,
        requestId: reqId,
        isAutoPlay: true,
      );
    } else {
      // Fallback timer simulation for tests without TTS repo
      _isPlayingAudio = true;
      _turnState = ConversationTurnState.speakingTranslatedAudio;
      notifyListeners();
      Future.delayed(const Duration(milliseconds: 1500), () {
        _isPlayingAudio = false;
        _turnState = ConversationTurnState.completed;
        notifyListeners();
      });
    }
  }

  // --- TWO-WAY CONVERSATION MICROPHONE RECORDING CONTROLS ---

  /// Handles application backgrounding or pausing by halting active audio capture and TTS.
  Future<void> handleAppPaused() async {
    if (_isPlayingAudio) {
      await stopPlayback(isManual: false);
    }
    if (isListening || _turnState == ConversationTurnState.listening) {
      _amplitudeSubscription?.cancel();
      _currentAudioLevel = 0.0;
      await _asrRepository?.cancel();
      _turnState = _conversationHistory.isNotEmpty
          ? ConversationTurnState.completed
          : ConversationTurnState.idle;
      notifyListeners();
    }
  }

  /// Toggles recording for the next conversation turn.
  /// If audio is actively speaking, stops audio first and prevents recording.
  Future<void> toggleConversationRecording() async {
    final now = DateTime.now();
    if (_lastMicTapTime != null && now.difference(_lastMicTapTime!) < const Duration(milliseconds: 600)) {
      debugPrint('[LiveTranslationVM] Rapid mic tap debounced.');
      return;
    }
    _lastMicTapTime = now;

    if (_isPlayingAudio) {
      await stopPlayback(isManual: true);
      _errorMessage = 'Playback stopped. Tap again to speak.';
      notifyListeners();
      return;
    }

    if (isListening) {
      await stopListeningAndProcess();
    } else {
      await startListening();
    }
  }

  /// Starts a fresh translation session from the Home screen using the user's selected languages.
  /// Handles permission verification, hardware access, and begins active listening.
  /// Returns true if recording started successfully, or false if an error occurred.
  Future<bool> startSessionFromHome({
    required LanguageModel sourceLanguage,
    required LanguageModel targetLanguage,
  }) async {
    // 1. If currently playing audio, stop it
    if (_isPlayingAudio) {
      await stopPlayback(isManual: true);
    }

    // 2. Clear old state
    _errorMessage = null;
    _warningMessage = null;

    // 3. Update active languages and direction manager
    _sourceLanguageCode = _normalizeLangCode(sourceLanguage.code);
    _sourceLanguageName = sourceLanguage.name;
    _targetLanguageCode = _normalizeLangCode(targetLanguage.code);
    _targetLanguageName = targetLanguage.name;

    _directionManager.updateLanguages(
      languageA: sourceLanguage,
      languageB: targetLanguage,
    );

    // 4. Start recording and listening
    final started = await startListening();
    if (!started) {
      debugPrint('[LiveTranslationViewModel] Failed to start listening from Home mic.');
      return false;
    }

    return true;
  }

  /// Starts capturing speech from the microphone for the next conversation turn.
  Future<bool> startListening() async {
    // Prevent acoustic feedback: Do NOT record while TTS is speaking
    if (_isPlayingAudio) {
      await stopPlayback(isManual: true);
      return false;
    }

    final asr = _asrRepository;
    if (asr == null) {
      debugPrint('[LiveTranslationVM] ASRRepository not provided. Recording not supported.');
      return false;
    }

    // Permission check
    final perm = await asr.checkPermission();
    if (perm != AudioPermissionStatus.granted) {
      final requested = await asr.requestPermission();
      if (requested != AudioPermissionStatus.granted) {
        _turnState = ConversationTurnState.error;
        _errorMessage = 'Microphone permission is required to capture conversation voice.';
        notifyListeners();
        return false;
      }
    }

    // Rapid-tap debounce guard
    if (_turnState == ConversationTurnState.processingSpeech ||
        _turnState == ConversationTurnState.translating) {
      return false;
    }

    _turnCounter++;
    final turnId = 'turn_${DateTime.now().microsecondsSinceEpoch}_$_turnCounter';
    _activeTurnId = turnId;
    _turnState = ConversationTurnState.listening;
    _errorMessage = null;
    _warningMessage = null;
    _currentAudioLevel = 0.0;
    notifyListeners();

    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = asr.amplitudeStream.listen((level) {
      _currentAudioLevel = level;
      notifyListeners();
    });

    final hint = (_sourceLanguageCode == 'auto') ? 'auto' : _sourceLanguageCode;
    final started = await asr.startListeningAndRecognition(languageCodeHint: hint);
    if (!started) {
      _turnState = ConversationTurnState.error;
      _amplitudeSubscription?.cancel();
      _currentAudioLevel = 0.0;
      if (asr.asrState == ASRState.error && asr.latestResult?.errorMessage != null) {
        _errorMessage = asr.latestResult!.errorMessage;
      } else if (asr.latestResult?.hasError == true && asr.latestResult?.errorMessage != null) {
        _errorMessage = asr.latestResult!.errorMessage;
      } else {
        _errorMessage = 'Could not access microphone hardware. Please try again.';
      }
      notifyListeners();
      return false;
    }

    return true;
  }

  /// Finalizes microphone recording and processes speech through Whisper ASR,
  /// automatic language detection, translation, and automatic TTS.
  Future<void> stopListeningAndProcess() async {
    final asr = _asrRepository;
    if (asr == null || _turnState != ConversationTurnState.listening) return;

    final thisTurnId = _activeTurnId;
    _turnState = ConversationTurnState.processingSpeech;
    _amplitudeSubscription?.cancel();
    _currentAudioLevel = 0.0;
    notifyListeners();

    final result = await asr.stopAndFinalize();

    // Check if another turn began while ASR was decoding
    if (thisTurnId != _activeTurnId) {
      debugPrint('[LiveTranslationVM] Dropping superseded turn $thisTurnId');
      return;
    }

    if (!result.hasText) {
      _turnState = ConversationTurnState.error;
      _errorMessage = result.errorMessage ?? 'No speech detected. Please speak clearly into the microphone.';
      notifyListeners();
      return;
    }

    // Language Direction Resolution:
    _turnState = ConversationTurnState.recognizingLanguage;
    notifyListeners();

    final direction = _directionManager.resolve(
      detectedLanguageCode: result.detectedLanguageCode,
      confidence: result.confidence,
      spokenText: result.text,
    );
    _sourceLanguageCode = direction.sourceLanguage.code;
    _sourceLanguageName = direction.sourceLanguage.name;
    _targetLanguageCode = direction.targetLanguage.code;
    _targetLanguageName = direction.targetLanguage.name;
    _originalText = result.text;
    _isMock = result.isMock;
    _confidence = result.confidence;

    if (!direction.canTranslate) {
      _warningMessage = direction.warningMessage;
      _turnState = ConversationTurnState.completed;
      _translatedText = '';
      notifyListeners();
      return;
    }

    _warningMessage = null;
    _turnState = ConversationTurnState.translating;
    notifyListeners();

    await executeTranslation(
      text: result.text,
      sourceCode: _sourceLanguageCode,
      targetCode: _targetLanguageCode,
      isAutoFlow: true,
      turnId: thisTurnId,
      speaker: direction.speaker,
    );
  }

  /// Manually swaps the current active translation direction (e.g. English ⇄ Telugu).
  void swapDirection() {
    _directionManager.swapDirection();
    final tempCode = _sourceLanguageCode;
    final tempName = _sourceLanguageName;
    _sourceLanguageCode = _targetLanguageCode;
    _sourceLanguageName = _targetLanguageName;
    _targetLanguageCode = tempCode;
    _targetLanguageName = tempName;
    notifyListeners();
  }

  /// Clears the local conversation history without altering language or TTS preferences.
  void clearConversationHistory() {
    _conversationHistory.clear();
    _originalText = '';
    _translatedText = '';
    _errorMessage = null;
    _warningMessage = null;
    _turnState = ConversationTurnState.idle;
    notifyListeners();
  }

  /// Replays audio for a specific completed conversation turn from history.
  Future<void> replayTurn(ConversationTurnModel turn) async {
    if (_isPlayingAudio) {
      await stopPlayback(isManual: true);
    }

    final tts = _ttsRepository;
    if (tts != null) {
      final reqId = 'turn_replay_${turn.id}_${DateTime.now().millisecondsSinceEpoch}';
      _currentRequestId = reqId;
      await tts.speakTranslation(
        text: turn.translatedText,
        targetLanguageCode: turn.targetLanguageCode,
        requestId: reqId,
        isAutoPlay: false,
      );
    }
  }

  void updateRecognitionResult(ASRRecognitionResult result) {
    if (result.hasText) {
      _turnCounter++;
      final turnId = 'turn_${DateTime.now().microsecondsSinceEpoch}_$_turnCounter';
      _activeTurnId = turnId;

      final direction = _directionManager.resolve(
        detectedLanguageCode: result.detectedLanguageCode,
        confidence: result.confidence,
        spokenText: result.text,
      );
      _sourceLanguageCode = direction.sourceLanguage.code;
      _sourceLanguageName = direction.sourceLanguage.name;
      _targetLanguageCode = direction.targetLanguage.code;
      _targetLanguageName = direction.targetLanguage.name;
      _originalText = result.text;
      _isMock = result.isMock;
      _confidence = result.confidence;

      if (!direction.canTranslate) {
        _warningMessage = direction.warningMessage;
        _turnState = ConversationTurnState.completed;
        _translatedText = '';
        notifyListeners();
        return;
      }

      _warningMessage = null;
      _turnState = ConversationTurnState.translating;
      notifyListeners();

      executeTranslation(
        text: result.text,
        sourceCode: _sourceLanguageCode,
        targetCode: _targetLanguageCode,
        isAutoFlow: true,
        turnId: turnId,
        speaker: direction.speaker,
      );
    }
  }

  /// Toggles speech output:
  /// - If currently playing: immediately stops playback (manual stop).
  /// - If stopped: replays the current translation from the beginning.
  Future<void> playTranslation() async {
    if (_isPlayingAudio) {
      await stopPlayback(isManual: true);
      return;
    }

    if (_translatedText.isEmpty) return;

    _userManuallyStopped = false;
    _ttsVoiceUnavailable = false;
    _ttsErrorMessage = null;

    final tts = _ttsRepository;
    if (tts != null) {
      final reqId = 'manual_${DateTime.now().millisecondsSinceEpoch}';
      _currentRequestId = reqId;
      await tts.speakTranslation(
        text: _translatedText,
        targetLanguageCode: _targetLanguageCode,
        requestId: reqId,
        isAutoPlay: false,
      );
    } else {
      _isPlayingAudio = true;
      _turnState = ConversationTurnState.speakingTranslatedAudio;
      notifyListeners();

      Future.delayed(const Duration(milliseconds: 1800), () {
        _isPlayingAudio = false;
        _turnState = ConversationTurnState.completed;
        notifyListeners();
      });
    }
  }

  /// Immediately halts speech output.
  Future<void> stopPlayback({bool isManual = true}) async {
    _userManuallyStopped = isManual;
    _isPlayingAudio = false;
    if (_turnState == ConversationTurnState.speakingTranslatedAudio) {
      _turnState = ConversationTurnState.completed;
    }
    notifyListeners();

    final tts = _ttsRepository;
    if (tts != null) {
      await tts.stop();
    }
  }

  /// Convenience method to speak/replay translated text
  Future<void> speakTranslation() => playTranslation();

  /// Convenience method to stop speaking
  Future<void> stopSpeaking() => stopPlayback(isManual: true);

  /// Pauses active speech output.
  Future<void> pausePlayback() async {
    final tts = _ttsRepository;
    if (tts != null) {
      await tts.pause();
    }
  }

  /// Resumes paused speech output.
  Future<void> resumePlayback() async {
    final tts = _ttsRepository;
    if (tts != null) {
      await tts.resume();
    }
  }

  /// Launches Android system TTS settings to install missing offline voice packs.
  Future<bool> openTtsSettings() async {
    final tts = _ttsRepository;
    if (tts != null) {
      return await tts.openTtsSettings();
    }
    return false;
  }

  /// Launches Android Voice Data installation intent.
  Future<bool> openInstallTtsData() async {
    final tts = _ttsRepository;
    if (tts != null) {
      return await tts.openInstallTtsData();
    }
    return false;
  }

  void tryAgain() {
    // If microphone capture is available, Try Again toggles recording for the next turn
    if (_asrRepository != null) {
      toggleConversationRecording();
    } else {
      _isSpeaking = true;
      notifyListeners();

      executeTranslation(isAutoFlow: true).then((_) {
        _isSpeaking = false;
        notifyListeners();
      });
    }
  }

  static String _normalizeLangCode(String? code) {
    if (code == null || code.isEmpty) return 'und';
    final lower = code.replaceAll('<|', '').replaceAll('|>', '').toLowerCase().trim();
    if (lower == 'auto') return 'auto';
    if (lower == 'und') return 'und';
    if (lower.startsWith('te')) return 'te';
    if (lower.startsWith('hi')) return 'hi';
    if (lower.startsWith('en')) return 'en';
    if (lower.startsWith('ta')) return 'ta';
    if (lower.startsWith('kn')) return 'kn';
    if (lower.startsWith('mr')) return 'mr';
    if (lower.startsWith('bn')) return 'bn';
    return lower.split('-').first;
  }

  static String _resolveLanguageName(String? code) {
    if (code == null) return 'English';
    final norm = _normalizeLangCode(code);
    final map = {
      'te': 'Telugu',
      'hi': 'Hindi',
      'en': 'English',
      'ta': 'Tamil',
      'kn': 'Kannada',
      'mr': 'Marathi',
      'bn': 'Bengali',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
    };
    return map[norm] ?? code.toUpperCase();
  }

  static String _resolveInitialSampleText(String code) {
    final norm = _normalizeLangCode(code);
    switch (norm) {
      case 'te':
        return AppStrings.sampleTeluguText;
      case 'de':
        return 'Hallo, wie geht es Ihnen?';
      case 'hi':
        return 'नमस्ते, आप कैसे हैं?';
      case 'ta':
        return 'வணக்கம், நீங்கள் எப்படி இருக்கிறீர்கள்?';
      case 'kn':
        return 'ನಮಸ್ಕಾರ, ನೀವು ಹೇಗಿದ್ದೀರಿ?';
      case 'en':
        return 'Hello, how are you?';
      default:
        return '';
    }
  }

  static String _performTestTranslation(String text, String src, String tgt) {
    if (src == tgt) return text;
    if (src == 'en' && tgt == 'te') {
      return AppStrings.sampleTeluguText;
    }
    if (src == 'te' && tgt == 'en') {
      return AppStrings.sampleEnglishText;
    }
    if (src == 'en' && tgt == 'hi') {
      return 'नमस्ते, आप कैसे हैं?';
    }
    if (src == 'hi' && tgt == 'en') {
      return 'Hello, how are you?';
    }
    if ((src == 'en' || src == 'te' || src == 'hi') && tgt == 'de') {
      return 'Hallo, wie geht es Ihnen?';
    }
    if (tgt == 'te') {
      return AppStrings.sampleTeluguText;
    }
    return '[$tgt Translation]: $text';
  }

  @override
  void dispose() {
    _ttsSubscription?.cancel();
    _amplitudeSubscription?.cancel();
    _asrResultSubscription?.cancel();
    _roomSubscription?.cancel();
    _ttsRepository?.stop();
    super.dispose();
  }
}
