import 'package:flutter/material.dart';

/// ViewModel managing state for the Live Translation Screen (Screen 3).
class LiveTranslationViewModel extends ChangeNotifier {
  bool _isPlayingAudio = false;
  bool _isSpeaking = false;

  bool get isPlayingAudio => _isPlayingAudio;
  bool get isSpeaking => _isSpeaking;

  void playTranslation() {
    _isPlayingAudio = true;
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 1800), () {
      _isPlayingAudio = false;
      notifyListeners();
    });
  }

  void tryAgain() {
    _isSpeaking = true;
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 1200), () {
      _isSpeaking = false;
      notifyListeners();
    });
  }
}

