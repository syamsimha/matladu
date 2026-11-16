import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/asr_state.dart';
import '../../models/audio_recording_state.dart';
import '../../models/connection_mode_model.dart';
import '../../repositories/settings_repository.dart';
import '../engine/engine_selection_manager.dart';
import 'android_speech_recognizer_service.dart';
import 'i_asr_service.dart';
import 'model_manager_service.dart';
import 'online_asr_service.dart';
import 'sherpa_on_device_asr_service.dart';

/// Hybrid ASR Service dynamically dispatching between On-Device Whisper (0 Audio Egress)
/// and Android Google Speech Services (Consent-Gated Online ASR).
///
/// PRIVACY & COMPLIANCE BOUNDARY:
/// - In Offline Mode: Strictly 100% on-device Whisper. Zero audio egress.
/// - In Online Mode: Google Speech Services may be used ONLY when explicit user consent is granted
///   and the language is verified as supported. Audio is transmitted to Google's cloud servers.
/// - If consent is declined or revoked, speech recognition routes to on-device Whisper.
class HybridASRService implements IASRService {
  final SherpaOnDeviceASRService _onDeviceService;
  final OnlineASRService _onlineService;
  final AndroidSpeechRecognizerService _androidSpeechService;
  final EngineSelectionManager _engineSelectionManager;
  final SettingsRepository? _settingsRepository;

  IASRService? _activeStreamingService;

  final _resultController = StreamController<ASRRecognitionResult>.broadcast();
  final _stateController = StreamController<ASRState>.broadcast();

  StreamSubscription<ASRRecognitionResult>? _onDeviceResultSub;
  StreamSubscription<ASRRecognitionResult>? _onlineResultSub;
  StreamSubscription<ASRRecognitionResult>? _androidSpeechResultSub;
  StreamSubscription<ASRState>? _onDeviceStateSub;
  StreamSubscription<ASRState>? _onlineStateSub;
  StreamSubscription<ASRState>? _androidSpeechStateSub;

  HybridASRService({
    required SherpaOnDeviceASRService onDeviceService,
    required OnlineASRService onlineService,
    required EngineSelectionManager engineSelectionManager,
    AndroidSpeechRecognizerService? androidSpeechService,
    SettingsRepository? settingsRepository,
  })  : _onDeviceService = onDeviceService,
        _onlineService = onlineService,
        _androidSpeechService = androidSpeechService ?? AndroidSpeechRecognizerService(),
        _engineSelectionManager = engineSelectionManager,
        _settingsRepository = settingsRepository {
    _onDeviceResultSub = _onDeviceService.resultStream.listen(_resultController.add);
    _onlineResultSub = _onlineService.resultStream.listen(_resultController.add);
    _androidSpeechResultSub = _androidSpeechService.resultStream.listen(_resultController.add);
    _onDeviceStateSub = _onDeviceService.stateStream.listen(_stateController.add);
    _onlineStateSub = _onlineService.stateStream.listen(_stateController.add);
    _androidSpeechStateSub = _androidSpeechService.stateStream.listen(_stateController.add);
  }

  ModelManagerService get modelManager => _onDeviceService.modelManager;
  SherpaOnDeviceASRService get onDeviceService => _onDeviceService;
  OnlineASRService get onlineService => _onlineService;
  AndroidSpeechRecognizerService get androidSpeechService => _androidSpeechService;
  EngineSelectionManager get engineSelectionManager => _engineSelectionManager;

  @override
  Stream<ASRRecognitionResult> get resultStream => _resultController.stream;

  @override
  Stream<ASRState> get stateStream => _stateController.stream;

  @override
  ASRState get currentState => _activeStreamingService?.currentState ?? _onDeviceService.currentState;

  @override
  ASRRecognitionResult? get lastResult =>
      _activeStreamingService?.lastResult ??
      _androidSpeechService.lastResult ??
      _onDeviceService.lastResult ??
      _onlineService.lastResult;

  @override
  bool get isNativeCapture => _activeStreamingService?.isNativeCapture ?? false;

  @override
  Future<void> initialize() async {
    await _onDeviceService.initialize();
    await _onlineService.initialize();
    await _androidSpeechService.initialize();
  }

  @override
  Future<void> startStreamingRecognition(
    Stream<Uint8List> pcmStream, {
    required AudioCaptureConfig audioConfig,
    String? languageCodeHint,
  }) async {
    final isOnlineMode = _engineSelectionManager.currentResolution.translationEngine == EngineType.onlineCloud ||
        _engineSelectionManager.activeMode == ConnectionModeType.cloudAi;
    final consentGranted = _settingsRepository?.getCloudSpeechConsent() == true;
    final isSupportedOnlineLang = AndroidSpeechRecognizerService.isLanguageSupported(languageCodeHint);

    if (isOnlineMode && consentGranted && isSupportedOnlineLang) {
      debugPrint(
        '[HybridASRService] Routing audio to Android Google Speech Services (Consent: Granted, Lang: $languageCodeHint). Notice: Audio transmitted to Google Cloud.',
      );
      _activeStreamingService = _androidSpeechService;
    } else {
      debugPrint(
        '[HybridASRService] Routing audio stream to Sherpa-ONNX On-Device Whisper (0 Audio Egress, Lang: $languageCodeHint).',
      );
      _activeStreamingService = _onDeviceService;
    }

    await _activeStreamingService!.startStreamingRecognition(
      pcmStream,
      audioConfig: audioConfig,
      languageCodeHint: languageCodeHint,
    );
  }

  @override
  Future<ASRRecognitionResult> stopStreamingRecognition({Uint8List? recordedPcm}) async {
    final active = _activeStreamingService ?? _onDeviceService;
    final res = await active.stopStreamingRecognition(recordedPcm: recordedPcm);
    _activeStreamingService = null;
    return res;
  }

  @override
  Future<ASRRecognitionResult> transcribePcmBuffer(
    Uint8List pcmBytes, {
    required AudioCaptureConfig audioConfig,
    String? languageCodeHint,
  }) async {
    return await _onDeviceService.transcribePcmBuffer(
      pcmBytes,
      audioConfig: audioConfig,
      languageCodeHint: languageCodeHint,
    );
  }

  @override
  Future<void> cancelRecognition() async {
    await _activeStreamingService?.cancelRecognition();
    _activeStreamingService = null;
  }

  @override
  void reset() {
    _activeStreamingService?.reset();
    _onDeviceService.reset();
    _onlineService.reset();
    _androidSpeechService.reset();
    _activeStreamingService = null;
  }

  @override
  Future<void> dispose() async {
    await _onDeviceResultSub?.cancel();
    await _onlineResultSub?.cancel();
    await _androidSpeechResultSub?.cancel();
    await _onDeviceStateSub?.cancel();
    await _onlineStateSub?.cancel();
    await _androidSpeechStateSub?.cancel();
    await _onDeviceService.dispose();
    await _onlineService.dispose();
    await _androidSpeechService.dispose();
    await _resultController.close();
    await _stateController.close();
  }
}
