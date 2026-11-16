import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/asr_state.dart';
import '../../../../data/models/audio_recording_state.dart';
import '../../../../data/models/connection_mode_model.dart';
import '../../../../data/models/language_model.dart';
import '../../../../data/models/translation_item_model.dart';
import '../../../../data/models/translation_result.dart';
import '../../../../data/repositories/asr_repository.dart';
import '../../../../data/repositories/audio_repository.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../../data/repositories/translation_repository.dart';
import '../../../../data/repositories/tts_repository.dart';
import '../../../../data/services/asr/android_speech_recognizer_service.dart';
import '../../../../data/services/asr/model_manager_service.dart';
import '../../../../data/services/engine/engine_selection_manager.dart';
import '../../../../data/services/network_connectivity_service.dart';

/// ViewModel managing state for the Home / Translator Screen,
/// including language selection, tabs, history, real-time microphone capture,
/// and provider-independent speech recognition (ASR).
class HomeViewModel extends ChangeNotifier {
  final TranslationRepository _translationRepository;
  final SettingsRepository _settingsRepository;
  final AudioRepository? _audioRepository;
  final ASRRepository? _asrRepository;
  final TtsRepository? _ttsRepository;
  final ModelManagerService? _modelManagerService;
  final NetworkConnectivityService? _networkConnectivityService;
  final EngineSelectionManager? _engineSelectionManager;

  HomeViewModel({
    required TranslationRepository translationRepository,
    required SettingsRepository settingsRepository,
    AudioRepository? audioRepository,
    ASRRepository? asrRepository,
    TtsRepository? ttsRepository,
    ModelManagerService? modelManagerService,
    NetworkConnectivityService? networkConnectivityService,
    EngineSelectionManager? engineSelectionManager,
  })  : _translationRepository = translationRepository,
        _settingsRepository = settingsRepository,
        _audioRepository = audioRepository,
        _asrRepository = asrRepository,
        _ttsRepository = ttsRepository,
        _modelManagerService = modelManagerService,
        _networkConnectivityService = networkConnectivityService,
        _engineSelectionManager = engineSelectionManager {
    _init();
  }

  late LanguageModel _sourceLanguage;
  late LanguageModel _targetLanguage;
  late ConnectionModeModel _connectionMode;

  bool _isListening = false;
  int _currentTab = 0; // 0: Home, 1: Offline, 2: History, 3: Settings
  List<TranslationItemModel> _history = [];

  // Phase 2 Real Audio Capture State
  double _currentAudioLevel = 0.0;
  Duration _recordingDuration = Duration.zero;
  String? _audioErrorMessage;
  AudioPermissionStatus _permissionStatus = AudioPermissionStatus.undetermined;

  // Phase 3 ASR State
  ASRRecognitionResult? _latestRecognitionResult;
  String _interimTranscription = '';
  String _latestTranslationText = '';
  ASRState _asrState = ASRState.idle;

  // On-Device Model & Network State
  bool _isSpeechModelInstalled = false;
  bool _isSpeechModelDownloading = false;
  double _speechModelDownloadProgress = 0.0;

  StreamSubscription<double>? _amplitudeSubscription;
  StreamSubscription<AudioCaptureState>? _captureStateSubscription;
  StreamSubscription<ASRRecognitionResult>? _asrResultSubscription;
  StreamSubscription<ASRState>? _asrStateSubscription;
  StreamSubscription<NetworkState>? _networkSubscription;
  Timer? _durationTimer;
  DateTime? _recordingStartTime;

  // Getters
  LanguageModel get sourceLanguage => _sourceLanguage;
  LanguageModel get targetLanguage => _targetLanguage;
  String get sourceLanguageCode => _sourceLanguage.code;
  String get targetLanguageCode => _targetLanguage.code;
  ConnectionModeModel get connectionMode => _connectionMode;
  bool get isListening => _isRecordingActive;
  int get currentTab => _currentTab;
  List<TranslationItemModel> get history => _history;

  // Model & Network Getters
  bool get isSpeechModelInstalled => _isSpeechModelInstalled;
  bool get isSpeechModelDownloading => _isSpeechModelDownloading;
  double get speechModelDownloadProgress => _speechModelDownloadProgress;
  bool get isNetworkConnected => _networkConnectivityService?.isConnected ?? false;
  bool get isValidatedInternet => _networkConnectivityService?.isValidatedInternet ?? false;

  // Real Audio Getters
  bool get _isRecordingActive =>
      _asrRepository?.isRecording ?? (_audioRepository?.isRecording ?? _isListening);
  bool get isRecording => _isRecordingActive;
  double get currentAudioLevel => _currentAudioLevel;
  Duration get recordingDuration => _recordingDuration;
  String? get audioErrorMessage => _audioErrorMessage;
  AudioPermissionStatus get permissionStatus => _permissionStatus;
  AudioCaptureState get captureState =>
      _asrRepository?.captureState ??
      (_audioRepository?.state ?? (_isListening ? AudioCaptureState.recording : AudioCaptureState.idle));
  Uint8List? get lastCapturedAudio =>
      _asrRepository?.capturedBytes ?? _audioRepository?.capturedBytes;
  int get totalBytesCaptured =>
      _asrRepository?.capturedBytes.length ?? (_audioRepository?.totalBytesCaptured ?? 0);

  // ASR Getters
  ASRRecognitionResult? get latestRecognitionResult => _latestRecognitionResult;
  String get interimTranscription => _interimTranscription;
  String get recognizedText => _latestRecognitionResult?.text ?? '';
  String get displayTranscriptionText {
    if (_interimTranscription.isNotEmpty) return _interimTranscription;
    if (_latestRecognitionResult != null && _latestRecognitionResult!.hasText) {
      return _latestRecognitionResult!.text;
    }
    return '';
  }
  String get latestTranslationText => _latestTranslationText;
  TtsRepository? get ttsRepository => _ttsRepository;
  bool get isPlayingTts => _ttsRepository?.isSpeaking ?? false;
  ASRState get asrState => _asrRepository?.asrState ?? _asrState;
  bool get hasRecognizedSpeech =>
      _latestRecognitionResult != null &&
      _latestRecognitionResult!.hasText &&
      !_latestRecognitionResult!.hasError;
  String? get detectedLanguageCode => _latestRecognitionResult?.detectedLanguageCode;
  String? get detectedLanguageName => _latestRecognitionResult?.detectedLanguageName;

  String _resolvedSourceCode = 'en';
  String _resolvedTargetCode = 'te';

  String get resolvedSourceCode => _resolvedSourceCode;
  String get resolvedTargetCode => _resolvedTargetCode;

  // Concept A: User-Selected Connection Mode
  ConnectionModeType get selectedConnectionMode =>
      _engineSelectionManager?.activeMode ?? _connectionMode.type;

  String get selectedModeLabel {
    switch (selectedConnectionMode) {
      case ConnectionModeType.automatic:
        return 'Automatic';
      case ConnectionModeType.cloudAi:
        return 'Online';
      case ConnectionModeType.onDevice:
        return 'Offline';
      case ConnectionModeType.peerToPeer:
        return 'P2P';
    }
  }

  // Concept B: Actual Network Availability
  NetworkAvailability get networkAvailability {
    if (_engineSelectionManager != null) {
      return _engineSelectionManager.networkAvailability;
    }
    if (_networkConnectivityService == null || !_networkConnectivityService.isConnected) {
      return NetworkAvailability.disconnected;
    }
    if (!_networkConnectivityService.isValidatedInternet) {
      return NetworkAvailability.unavailable;
    }
    return NetworkAvailability.connected;
  }

  String get networkAvailabilityLabel {
    switch (networkAvailability) {
      case NetworkAvailability.connected:
        return 'Connected';
      case NetworkAvailability.disconnected:
        return 'Disconnected';
      case NetworkAvailability.unavailable:
        return 'Internet Unavailable';
    }
  }

  // Concept C: Actual Translation Engine in Use
  TranslationEngineInUse get translationEngineInUse {
    if (_engineSelectionManager != null) {
      return _engineSelectionManager.translationEngineInUse;
    }
    if (isOnlineEngineActive) {
      return TranslationEngineInUse.onlineMyMemory;
    }
    return _isSpeechModelInstalled ? TranslationEngineInUse.localMlKit : TranslationEngineInUse.unavailable;
  }

  String get translationEngineLabel {
    switch (translationEngineInUse) {
      case TranslationEngineInUse.onlineMyMemory:
        return 'MyMemory Online';
      case TranslationEngineInUse.localMlKit:
        return 'Local ML Kit';
      case TranslationEngineInUse.unavailable:
        return 'Unavailable';
    }
  }

  // Dynamic Validated Status Pill & Engine Readiness
  bool get isOnlineEngineActive {
    if (selectedConnectionMode == ConnectionModeType.onDevice) {
      return false; // Authoritative offline: NEVER online
    }
    if (_engineSelectionManager != null) {
      return _engineSelectionManager.currentResolution.translationEngine == EngineType.onlineCloud;
    }
    return (selectedConnectionMode == ConnectionModeType.cloudAi ||
            selectedConnectionMode == ConnectionModeType.automatic) &&
        _networkConnectivityService?.isValidatedInternet == true;
  }

  String get statusPillText {
    if (isRecording) {
      return 'Recording - ${recordingDuration.inSeconds}s';
    }
    if (asrState == ASRState.transcribing) {
      return 'Transcribing...';
    }
    if (_isSpeechModelDownloading) {
      final pct = (_speechModelDownloadProgress * 100).toInt();
      return 'Installing model ($pct%)';
    }
    if (asrState == ASRState.error || _permissionStatus == AudioPermissionStatus.permanentlyDenied) {
      return 'Speech service unavailable';
    }

    final isConnected = networkAvailability == NetworkAvailability.connected;

    final mode = selectedConnectionMode;
    if (mode == ConnectionModeType.onDevice) {
      // 100% On-Device mode: NEVER show online!
      if (!_isSpeechModelInstalled) {
        return 'Pack Needed';
      }
      return 'Offline - Ready';
    } else if (mode == ConnectionModeType.cloudAi) {
      // Online mode: Online provider only!
      if (!isConnected) {
        return 'Offline';
      }
      return 'Online - Ready';
    } else {
      // Automatic mode:
      if (!isConnected) {
        return _isSpeechModelInstalled ? 'Offline - Ready' : 'Pack Needed';
      }
      if (isOnlineEngineActive) {
        return 'Auto (Online)';
      }
      if (!_isSpeechModelInstalled) {
        return 'Pack Needed';
      }
      return 'Auto (Offline)';
    }
  }

  IconData get statusPillIcon {
    if (isRecording) {
      return Icons.fiber_manual_record_rounded;
    }
    if (asrState == ASRState.transcribing) {
      return Icons.sync_rounded;
    }
    if (_isSpeechModelDownloading) {
      return Icons.downloading_rounded;
    }
    if (asrState == ASRState.error || _permissionStatus == AudioPermissionStatus.permanentlyDenied) {
      return Icons.error_outline_rounded;
    }
    if (selectedConnectionMode == ConnectionModeType.onDevice) {
      return Icons.offline_bolt_rounded;
    }
    if (isOnlineEngineActive) {
      return Icons.cloud_done_rounded;
    }
    if (networkAvailability == NetworkAvailability.disconnected) {
      return Icons.wifi_off_rounded;
    }
    if (!_isSpeechModelInstalled) {
      return Icons.download_for_offline_rounded;
    }
    return Icons.wifi_rounded;
  }

  Color getStatusPillColor(bool isDark) {
    if (isRecording) {
      return isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
    }
    if (asrState == ASRState.transcribing) {
      return isDark ? const Color(0xFFA78BFA) : const Color(0xFF6366F1);
    }
    if (isOnlineEngineActive) {
      return isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
    }
    if (_isSpeechModelDownloading || !_isSpeechModelInstalled) {
      return isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
    }
    if (asrState == ASRState.error || _permissionStatus == AudioPermissionStatus.permanentlyDenied) {
      return isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
    }
    if (_networkConnectivityService?.isValidatedInternet == true) {
      return isDark ? AppDarkColors.statusGreen : AppColors.statusGreen;
    }
    return isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
  }

  Color getStatusPillBgColor(bool isDark) {
    if (isRecording) {
      return isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);
    }
    if (asrState == ASRState.transcribing) {
      return isDark ? const Color(0xFF2E1065) : const Color(0xFFEEF2FF);
    }
    if (isOnlineEngineActive) {
      return isDark ? const Color(0xFF0C4A6E) : const Color(0xFFE0F2FE);
    }
    if (_isSpeechModelDownloading || !_isSpeechModelInstalled) {
      return isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
    }
    if (asrState == ASRState.error || _permissionStatus == AudioPermissionStatus.permanentlyDenied) {
      return isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);
    }
    if (_networkConnectivityService?.isValidatedInternet == true) {
      return isDark ? AppDarkColors.statusGreenBg : AppColors.statusGreen.withValues(alpha: 0.12);
    }
    return isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
  }

  Color getStatusPillBorderColor(bool isDark) {
    if (isRecording) {
      return isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5);
    }
    if (asrState == ASRState.transcribing) {
      return isDark ? const Color(0xFF5B21B6) : const Color(0xFFC7D2FE);
    }
    if (isOnlineEngineActive) {
      return isDark ? const Color(0xFF0369A1) : const Color(0xFFBAE6FD);
    }
    if (_isSpeechModelDownloading || !_isSpeechModelInstalled) {
      return isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A);
    }
    if (asrState == ASRState.error || _permissionStatus == AudioPermissionStatus.permanentlyDenied) {
      return isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5);
    }
    if (_networkConnectivityService?.isValidatedInternet == true) {
      return isDark ? AppDarkColors.statusGreenBorder : AppColors.statusGreen.withValues(alpha: 0.25);
    }
    return isDark ? const Color(0xFF065F46) : const Color(0xFFA7F3D0);
  }

  void _init() {
    _sourceLanguage = _settingsRepository.getSourceLanguage();
    _targetLanguage = _settingsRepository.getTargetLanguage();
    _connectionMode = _settingsRepository.getConnectionMode();
    _history = _translationRepository.getHistory();

    if (_engineSelectionManager != null) {
      _engineSelectionManager.addListener(_onEngineManagerChanged);
      _onEngineManagerChanged();
    }

    if (_asrRepository != null) {
      _subscribeToAsrEvents();
    } else if (_audioRepository != null) {
      _subscribeToAudioEvents();
    }

    final netService = _networkConnectivityService;
    if (netService != null) {
      _networkSubscription = netService.stateStream.listen((_) {
        notifyListeners();
      });
    }

    checkModelAndNetworkStatus();

    notifyListeners();
  }

  void _onEngineManagerChanged() {
    if (_engineSelectionManager != null) {
      _connectionMode = ConnectionModeModel.fromType(_engineSelectionManager.activeMode);
    }
    notifyListeners();
  }

  /// Called when the application resumes from the background to immediately
  /// re-verify connectivity, re-resolve engines, and update UI state without restart.
  Future<void> handleAppResumed() async {
    if (_networkConnectivityService != null) {
      await _networkConnectivityService.checkConnectivity();
    }
    if (_engineSelectionManager != null) {
      await _engineSelectionManager.resolve(
        sourceLanguageCode: _resolvedSourceCode,
        targetLanguageCode: _resolvedTargetCode,
      );
    }
    notifyListeners();
  }

  /// Checks if the speech recognition model is installed in app-private storage.
  Future<void> checkModelAndNetworkStatus() async {
    final mm = _modelManagerService ?? _asrRepository?.modelManager;
    if (mm != null) {
      _isSpeechModelInstalled = await mm.isModelInstalled('whisper-tiny-multilingual');
    } else {
      _isSpeechModelInstalled = true;
    }
    notifyListeners();
  }

  /// Downloads and installs the Whisper Multilingual Tiny model (~103.6 MB) directly to app-private storage.
  Future<bool> downloadAndInstallSpeechModel({void Function(double)? onProgress}) async {
    final net = _networkConnectivityService;
    if (net != null && !net.isConnected) {
      _audioErrorMessage = 'Internet Connection Required to download Whisper speech model.';
      notifyListeners();
      return false;
    }

    final mm = _modelManagerService ?? _asrRepository?.modelManager;
    if (mm == null) return false;

    _isSpeechModelDownloading = true;
    _speechModelDownloadProgress = 0.0;
    notifyListeners();

    try {
      final success = await mm.downloadModel(
        'whisper-tiny-multilingual',
        onProgress: (progress) {
          _speechModelDownloadProgress = progress;
          onProgress?.call(progress);
          notifyListeners();
        },
      );

      _isSpeechModelInstalled = success;
      _isSpeechModelDownloading = false;

      final asrRepo = _asrRepository;
      if (success && asrRepo != null) {
        // Pre-warm recognizer so the first mic tap is instant
        unawaited(asrRepo.startListeningAndRecognition(languageCodeHint: 'auto').then((started) {
          if (started) {
            asrRepo.cancel();
          }
        }).catchError((_) {}));
      }

      notifyListeners();
      return success;
    } catch (e) {
      debugPrint('[HomeViewModel] Speech model download failed: $e');
      _isSpeechModelDownloading = false;
      notifyListeners();
      return false;
    }
  }

  /// Cancels an in-progress Whisper model download.
  void cancelSpeechModelDownload() {
    final mm = _modelManagerService ?? _asrRepository?.modelManager;
    mm?.cancelDownload('whisper-tiny-multilingual');
    _isSpeechModelDownloading = false;
    _speechModelDownloadProgress = 0.0;
    notifyListeners();
  }

  void _subscribeToAsrEvents() {
    final asrRepo = _asrRepository;
    if (asrRepo == null) return;

    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = asrRepo.amplitudeStream.listen((level) {
      _currentAudioLevel = level;
      notifyListeners();
    });

    _captureStateSubscription?.cancel();
    _captureStateSubscription = asrRepo.captureStateStream.listen((state) {
      if (state == AudioCaptureState.idle || state == AudioCaptureState.error) {
        _stopDurationTimer();
        _currentAudioLevel = 0.0;
      }
      notifyListeners();
    });

    _asrResultSubscription?.cancel();
    _asrResultSubscription = asrRepo.resultStream.listen((result) {
      if (result.isFinal) {
        _latestRecognitionResult = result;
        _interimTranscription = '';
      } else {
        _interimTranscription = result.text;
      }
      notifyListeners();
    });

    _asrStateSubscription?.cancel();
    _asrStateSubscription = asrRepo.asrStateStream.listen((state) {
      _asrState = state;
      notifyListeners();
    });
  }

  void _subscribeToAudioEvents() {
    final repo = _audioRepository;
    if (repo == null) return;

    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = repo.amplitudeStream.listen((level) {
      _currentAudioLevel = level;
      notifyListeners();
    });

    _captureStateSubscription?.cancel();
    _captureStateSubscription = repo.stateStream.listen((state) {
      if (state == AudioCaptureState.idle || state == AudioCaptureState.error) {
        _stopDurationTimer();
        _currentAudioLevel = 0.0;
      }
      notifyListeners();
    });
  }

  void refreshFromSettings() {
    _sourceLanguage = _settingsRepository.getSourceLanguage();
    _targetLanguage = _settingsRepository.getTargetLanguage();
    _connectionMode = _settingsRepository.getConnectionMode();
    _history = _translationRepository.getHistory();
    notifyListeners();
  }

  void setTab(int index) {
    _currentTab = index;
    notifyListeners();
  }

  Future<void> setSourceLanguage(LanguageModel language) async {
    _sourceLanguage = language;
    await _settingsRepository.setSourceLanguage(language);
    notifyListeners();
  }

  Future<void> setTargetLanguage(LanguageModel language) async {
    // Auto Detect is strictly prohibited for target language
    if (language.code == 'auto') return;
    _targetLanguage = language;
    await _settingsRepository.setTargetLanguage(language);
    notifyListeners();
  }

  Future<void> swapLanguages() async {
    if (_sourceLanguage.code == 'auto') {
      // Cannot set target language to Auto Detect. Target must remain a concrete language.
      final newSource = _targetLanguage;
      final newTargetCode = (_resolvedSourceCode.isNotEmpty && _resolvedSourceCode != 'auto')
          ? _resolvedSourceCode
          : 'en';
      final newTarget = LanguageModel.fromCode(newTargetCode) ?? LanguageModel.defaultLanguages.first;
      _sourceLanguage = newSource;
      _targetLanguage = newTarget;
    } else {
      final temp = _sourceLanguage;
      _sourceLanguage = _targetLanguage;
      _targetLanguage = temp;
    }

    await _settingsRepository.setSourceLanguage(_sourceLanguage);
    await _settingsRepository.setTargetLanguage(_targetLanguage);
    notifyListeners();
  }

  /// Toggles real microphone recording and speech recognition on and off.
  /// Handles runtime permissions gracefully with optional UI callbacks.
  Future<bool> toggleRecording({
    VoidCallback? onPermissionDenied,
    VoidCallback? onPermanentlyDenied,
    VoidCallback? onRecordingStopped,
    void Function(String modelName, int sizeMB)? onModelRequired,
    VoidCallback? onCloudSpeechConsentRequired,
  }) async {
    if (_asrRepository == null && _audioRepository == null) {
      // Fallback if neither repository is injected
      _isListening = !_isListening;
      notifyListeners();
      return _isListening;
    }

    // Concurrency guard: If currently transcribing, ignore new tap
    if (asrState == ASRState.transcribing) {
      debugPrint('[HomeViewModel] Recognition in progress, ignoring toggle.');
      return false;
    }

    // 1. If currently recording, stop it and finalize speech recognition
    if (isRecording) {
      final elapsedMs = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
          : 0;
      _stopDurationTimer();
      _isListening = false;
      _currentAudioLevel = 0.0;
      notifyListeners();

      if (_asrRepository != null) {
        _latestRecognitionResult = await _asrRepository.stopAndFinalize();
        _interimTranscription = '';

        if (elapsedMs > 0 && elapsedMs < 400 && (_latestRecognitionResult == null || !_latestRecognitionResult!.hasText)) {
          _audioErrorMessage = 'Speech too short. Please press, speak clearly, and release.';
          _interimTranscription = '';
          _latestRecognitionResult = null;
          _latestTranslationText = '';
          notifyListeners();
          onRecordingStopped?.call();
          return false;
        }

        // Spoken language detection and translation direction resolution:
        final rawDetected = _latestRecognitionResult?.detectedLanguageCode;
        final cleanDetected = _normalizeLangCode(rawDetected);
        final normSrc = _normalizeLangCode(_sourceLanguage.code);
        final normTgt = _normalizeLangCode(_targetLanguage.code);

        // TARGET LANGUAGE MUST NEVER CHANGE AUTOMATICALLY.
        // The language selected by the user as target remains strictly locked.
        final String tgtCode = normTgt;
        String srcCode = normSrc;
        bool isDetectionUncertain = false;

        if (normSrc == 'auto') {
          // Auto Detect applies ONLY to source language.
          if (cleanDetected.isNotEmpty && cleanDetected != 'auto' && cleanDetected != 'und') {
            srcCode = cleanDetected;
          } else {
            srcCode = 'und';
            isDetectionUncertain = true;
          }
        } else {
          // Explicit source language selected by user - use it authoritative.
          srcCode = normSrc;
        }

        _resolvedSourceCode = srcCode;
        _resolvedTargetCode = tgtCode;

        // Check confidence threshold: if confidence is below 0.35, or detection is uncertain or has error, do not silently guess or translate.
        final hasLowConfidence = isDetectionUncertain ||
            _latestRecognitionResult == null ||
            _latestRecognitionResult!.confidence < 0.35 ||
            _latestRecognitionResult!.hasError ||
            srcCode == 'und';

        // Never translate a language into itself merely because source detection failed or matched target.
        final isSelfTranslation = (srcCode == tgtCode);

        // Trigger translation for recognized speech only if valid, confident, and not translating into itself
        if (_latestRecognitionResult != null &&
            _latestRecognitionResult!.hasText &&
            !hasLowConfidence &&
            !isSelfTranslation) {
          try {
            final tr = await _translationRepository.translateText(
              text: _latestRecognitionResult!.text,
              sourceLanguageCode: srcCode,
              targetLanguageCode: tgtCode,
            );
            if (tr.status == TranslationStatus.completed && tr.translatedText.isNotEmpty) {
              _latestTranslationText = tr.translatedText;
            } else {
              _latestTranslationText = '';
            }
          } catch (e) {
            debugPrint('[HomeViewModel] On-device translation error: $e');
            _latestTranslationText = '';
          }
        } else {
          _latestTranslationText = '';
        }
      } else if (_audioRepository != null) {
        await _audioRepository.stopRecording();
      }

      notifyListeners();
      onRecordingStopped?.call();
      return false;
    }

    // 2. Pre-flight check: in strictly On-Device (Offline) mode, ensure the offline speech model is installed
    final isStrictlyOffline = selectedConnectionMode == ConnectionModeType.onDevice ||
        (selectedConnectionMode == ConnectionModeType.automatic && networkAvailability != NetworkAvailability.connected);

    final mm = _modelManagerService ?? _asrRepository?.modelManager;
    final isWhisperInstalled = mm != null ? await mm.isModelInstalled('whisper-tiny-multilingual') : true;
    _isSpeechModelInstalled = isWhisperInstalled;

    if (isStrictlyOffline) {
      if (!isWhisperInstalled) {
        _audioErrorMessage = 'Whisper speech model is required for offline speech recognition. Please download it in Offline Packs or switch to Online Mode.';
        notifyListeners();
        onModelRequired?.call('Whisper Multilingual Tiny', 104);
        return false;
      }
    } else {
      // In Online mode: check cloud speech recognition consent and language support
      final hint = (_sourceLanguage.code == 'auto') ? 'auto' : _sourceLanguage.code;
      final isSupportedByGoogle = AndroidSpeechRecognizerService.isLanguageSupported(hint);
      final hasCloudConsent = _settingsRepository.getCloudSpeechConsent();

      if (hasCloudConsent) {
        if (hint == 'auto') {
          // Google Cloud Speech requires selecting a specific spoken language locale.
          // If Whisper is installed, Auto Detect runs local Whisper LID seamlessly.
          // If Whisper is NOT installed, inform the user clearly:
          if (!isWhisperInstalled) {
            _audioErrorMessage = 'Cloud Speech Recognition requires selecting a specific spoken language. For Automatic Language Detection across languages, download the offline Whisper model in Offline Packs or select your language directly.';
            notifyListeners();
            onModelRequired?.call('Whisper Multilingual Tiny', 104);
            return false;
          }
        } else if (!isSupportedByGoogle && !isWhisperInstalled) {
          _audioErrorMessage = 'Speech recognition for ${_sourceLanguage.name} is not supported by Google speech services and requires the on-device Whisper model. Please download it in Offline Packs.';
          notifyListeners();
          onModelRequired?.call('Whisper Multilingual Tiny', 104);
          return false;
        }
      } else {
        // Cloud speech recognition is DISABLED (consent not granted)
        if (!isWhisperInstalled) {
          if (isSupportedByGoogle) {
            onCloudSpeechConsentRequired?.call();
            return false;
          } else {
            _audioErrorMessage = 'Speech recognition for ${_sourceLanguage.name} requires the on-device Whisper model. Please download it in Offline Packs.';
            notifyListeners();
            onModelRequired?.call('Whisper Multilingual Tiny', 104);
            return false;
          }
        }
        // If Whisper is installed and user has not enabled cloud speech, default to 100% private Whisper!
      }
    }

    // 3. Not recording: Check and verify permissions first
    _audioErrorMessage = null;
    _permissionStatus = _asrRepository != null
        ? await _asrRepository.checkPermission()
        : await _audioRepository!.checkPermission();

    if (_permissionStatus != AudioPermissionStatus.granted) {
      _permissionStatus = _asrRepository != null
          ? await _asrRepository.requestPermission()
          : await _audioRepository!.requestPermission();
    }

    if (_permissionStatus == AudioPermissionStatus.permanentlyDenied) {
      _audioErrorMessage = 'Microphone permission is permanently denied. Please enable it in Settings.';
      notifyListeners();
      onPermanentlyDenied?.call();
      return false;
    } else if (_permissionStatus != AudioPermissionStatus.granted) {
      _audioErrorMessage = 'Microphone permission is required to capture voice.';
      notifyListeners();
      onPermissionDenied?.call();
      return false;
    }

    // 4. Permission granted: Begin real microphone capture and speech recognition streaming
    // Respect the user's selected source language if they chose one; otherwise run automatic LID
    final hint = (_sourceLanguage.code == 'auto') ? 'auto' : _sourceLanguage.code;
    final success = _asrRepository != null
        ? await _asrRepository.startListeningAndRecognition(
            languageCodeHint: hint,
          )
        : await _audioRepository!.startRecording();

    if (success) {
      _recordingStartTime = DateTime.now();
      _isListening = true;
      _latestRecognitionResult = null;
      _interimTranscription = '';
      _latestTranslationText = '';
      _startDurationTimer();
      notifyListeners();
      return true;
    } else {
      if (_asrRepository != null && _asrRepository.asrState == ASRState.error) {
        _audioErrorMessage = _asrRepository.latestResult?.errorMessage ??
            (isStrictlyOffline
                ? 'On-device speech recognition model not ready. Please verify offline model files.'
                : 'Speech recognition service temporarily unavailable. Please try again.');
      } else if (_asrRepository != null && _asrRepository.latestResult?.hasError == true && _asrRepository.latestResult?.errorMessage != null) {
        _audioErrorMessage = _asrRepository.latestResult!.errorMessage;
      } else {
        _audioErrorMessage = 'Microphone hardware is unavailable or in use by another app. Please try again.';
      }
      notifyListeners();
      return false;
    }
  }

  /// Manually stops real-time recording and stores the captured audio.
  Future<Uint8List?> stopRecording() async {
    _stopDurationTimer();
    _currentAudioLevel = 0.0;
    _isListening = false;
    notifyListeners();

    if (_asrRepository != null) {
      _latestRecognitionResult = await _asrRepository.stopAndFinalize();
      _interimTranscription = '';
      return _asrRepository.capturedBytes;
    } else if (_audioRepository != null) {
      return await _audioRepository.stopRecording();
    }
    return null;
  }

  /// Cancels real-time recording and speech recognition.
  Future<void> cancelRecording() async {
    _stopDurationTimer();
    _currentAudioLevel = 0.0;
    _isListening = false;
    _interimTranscription = '';
    notifyListeners();

    if (_asrRepository != null) {
      await _asrRepository.cancel();
    } else if (_audioRepository != null) {
      await _audioRepository.cancelRecording();
    }
  }

  /// Legacy helper method preserved for simulated/transitional flows.
  void startListening(VoidCallback onDone) {
    if (_audioRepository != null && !_audioRepository.isRecording) {
      toggleRecording().then((started) {
        if (!started) onDone();
      });
      return;
    }

    _isListening = true;
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 1200), () {
      _isListening = false;
      notifyListeners();
      onDone();
    });
  }

  /// Opens application settings when permission was permanently denied.
  Future<bool> openAppSettings() async {
    if (_audioRepository != null) {
      return await _audioRepository.openAppSettings();
    }
    return false;
  }

  /// Handles application lifecycle interruptions (e.g., app minimized or backgrounded).
  void handleAppPaused() {
    if (_isRecordingActive) {
      debugPrint('[HomeViewModel] App paused while recording. Stopping capture safely.');
      stopRecording();
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _recordingDuration = Duration.zero;
    _durationTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final repoDuration = _asrRepository?.recordingDuration ?? _audioRepository?.recordingDuration;
      if (repoDuration != null) {
        _recordingDuration = repoDuration;
        notifyListeners();
      }
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  Future<void> clearHistory() async {
    await _translationRepository.clearHistory();
    _history = [];
    notifyListeners();
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

  @override
  void dispose() {
    _stopDurationTimer();
    _engineSelectionManager?.removeListener(_onEngineManagerChanged);
    _amplitudeSubscription?.cancel();
    _captureStateSubscription?.cancel();
    _asrResultSubscription?.cancel();
    _asrStateSubscription?.cancel();
    _networkSubscription?.cancel();
    super.dispose();
  }
}
