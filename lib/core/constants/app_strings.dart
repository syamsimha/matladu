/// Application string constants exactly matching the 8-screen UI reference specification.
class AppStrings {
  AppStrings._();

  // App Identity & Slogans
  static const String appName = 'Matladu AI';
  static const String tagline = 'Speak • Translate • Connect';
  static const String splashSubtext = 'Break the language barrier\nwith just one microphone';
  static const String initializing = 'Initializing...';
  static const String version = 'Version 1.0.0';
  static const String aboutDescription =
      'A smart voice translator that bridges language barriers.';
  static const String madeWithLove = 'Made with ❤️ for everyone';
  static const String copyright = '© 2026 Matladu AI';

  // Home Screen (Screen 2)
  static const String onlineReady = 'Online • Ready';
  static const String tapToSpeak = 'Tap to Speak';
  static const String speakNaturally = 'Speak naturally in any language';
  static const String englishDetect = 'English\n(Detect)';
  static const String teluguDetect = 'Telugu\n(తెలుగు)';
  static const String trySaying = 'Try saying...';
  static const String trySayingQuote = '“Hello, how are you?”';

  // Bottom Navigation Bar
  static const String tabHome = 'Home';
  static const String tabOffline = 'Offline';
  static const String tabHistory = 'History';
  static const String tabSettings = 'Settings';

  // Live Translation Screen (Screen 3)
  static const String liveTranslationTitle = 'Live Translation';
  static const String originalEnglish = 'Original (English)';
  static const String sampleEnglishText = 'Hello, how are you?';
  static const String translatedTelugu = 'Translated (Telugu)';
  static const String sampleTeluguText = 'నమస్తే, మీరు ఎలా ఉన్నారు?';
  static const String tryAgain = 'Try Again';
  static const String playTranslation = 'Play Translation';
  static const String share = 'Share';
  static const String translationComplete = 'Translation Complete!';

  // Select Language Screen (Screen 4)
  static const String selectLanguageTitle = 'Select Language';
  static const String searchLanguagesHint = 'Search languages...';
  static const String filterAll = 'All';
  static const String filterPopular = 'Popular';
  static const String filterIndian = 'Indian';
  static const String filterOthers = 'Others';
  static const String doneOneSelected = 'Done (1 Selected)';

  // Offline Packs Screen (Screen 5)
  static const String offlinePacksTitle = 'Offline Packs';
  static const String noDownloadRequired = 'No download required';
  static const String useOnlineInstantly = 'Use online translation instantly!';
  static const String availablePacks = 'Available Packs';
  static const String downloadedPacks = 'Downloaded Packs';
  static const String download = 'Download';
  static const String readyToUse = 'Ready to use';
  static const String offlineNoticeBottom =
      'You can use Matladu AI without downloading any packs!';

  // Settings Screen (Screen 6)
  static const String settingsTitle = 'Settings';
  static const String connectionMode = 'Connection Mode';
  static const String onlineModeActive = 'Online mode active';
  static const String offlineLanguagePacks = 'Offline Language Packs';
  static const String manageDownloadedPacks = 'Manage downloaded packs';
  static const String appPreferences = 'App Preferences';
  static const String themeVoiceSpeed = 'Theme, Voice, Speed';
  static const String speechSettings = 'Speech Settings';
  static const String recognitionAndTts = 'Recognition & TTS';
  static const String cacheAndStorage = 'Cache & Storage';
  static const String clearCacheSample = 'Clear cache (24.5 MB)';
  static const String aboutMatladuAi = 'About Matladu AI';
  static const String resetSettings = 'Reset Settings';

  // About Screen (Screen 7)
  static const String aboutTitle = 'About';
  static const String featureOnline = 'Online\nTranslation';
  static const String featureOffline = 'Offline\nSupport';
  static const String featurePrivacy = 'Privacy\nFirst';

  // Connection Mode Screen (Screen 8)
  static const String connected = 'Connected!';
  static const String connectedSubtitle =
      'You are online.\nMatladu Ai will use online\ntranslation models.';
  static const String autoSwitchEnabled = 'Auto Switch Enabled';
  static const String autoSwitchSubtitle =
      'Switches to offline if internet\nis unavailable.';
  static const String gotIt = 'Got it';
}
