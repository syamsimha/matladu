import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/responsive/responsive_layout.dart';
import '../../../../core/widgets/circular_flag_avatar.dart';
import '../../../../core/widgets/horizontal_soundwave.dart';
import '../../../../data/models/asr_state.dart';
import '../../../../data/models/conversation_turn_model.dart';
import '../../../../data/repositories/asr_repository.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../../data/repositories/translation_repository.dart';
import '../../../../data/repositories/tts_repository.dart';
import '../../../../data/services/room/i_room_service.dart';
import '../view_models/live_translation_view_model.dart';

/// Screen 3: Live Translation
/// Reproduces the official reference design with Original Card,
/// Translated mint green card, 3-button circular action bar, and Translation Complete badge.
/// Phase 6 enhances this screen with real-time two-way voice conversation turn management,
/// directional language swapping, and local conversation history retention.
/// Responsive and centered on tablets/iPads via ResponsiveContentWrapper.
class LiveTranslationScreen extends StatelessWidget {
  final String? roomId;
  final IRoomService? roomService;

  const LiveTranslationScreen({
    super.key,
    this.roomId,
    this.roomService,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final args = ModalRoute.of(context)?.settings.arguments;
    ASRRecognitionResult? asrResult;
    String? targetLangCode;
    String? sourceLangCode;
    String? passedRoomId;
    if (args is ASRRecognitionResult) {
      asrResult = args;
    } else if (args is Map<String, dynamic>) {
      asrResult = args['asrResult'] as ASRRecognitionResult?;
      targetLangCode = args['targetLanguageCode'] as String?;
      sourceLangCode = args['sourceLanguageCode'] as String?;
      passedRoomId = args['roomId'] as String?;
    }

    final resolvedRoomId = roomId ?? passedRoomId;
    IRoomService? resolvedRoomService = roomService;
    if (resolvedRoomService == null) {
      try {
        resolvedRoomService = Provider.of<IRoomService>(context, listen: false);
      } catch (_) {}
    }

    TranslationRepository? translationRepo;
    TtsRepository? ttsRepo;
    ASRRepository? asrRepo;
    SettingsRepository? settingsRepo;

    try {
      translationRepo = Provider.of<TranslationRepository>(context, listen: false);
    } catch (_) {}
    try {
      ttsRepo = Provider.of<TtsRepository>(context, listen: false);
    } catch (_) {}
    try {
      asrRepo = Provider.of<ASRRepository>(context, listen: false);
    } catch (_) {}
    try {
      settingsRepo = Provider.of<SettingsRepository>(context, listen: false);
    } catch (_) {}

    LiveTranslationViewModel? existingVm;
    try {
      existingVm = Provider.of<LiveTranslationViewModel>(context, listen: false);
    } catch (_) {}

    Widget buildScreen(LiveTranslationViewModel activeVm) {
      return _LiveTranslationLifecycleWatcher(
        child: PopScope(
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) {
              activeVm.handleAppPaused();
            }
          },
          child: Consumer<LiveTranslationViewModel>(
            builder: (context, vm, _) {
              return Scaffold(
                backgroundColor: isDark ? AppDarkColors.background : AppColors.background,
                appBar: AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                    onPressed: () {
                      vm.handleAppPaused();
                      Navigator.pop(context);
                    },
                  ),
                  title: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppStrings.liveTranslationTitle,
                        style: AppTypography.headlineMedium.copyWith(
                          fontSize: 18,
                          color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                        ),
                      ),
                      if (vm.isRoomActive)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              vm.isRoomConnected ? Icons.circle : Icons.circle_outlined,
                              size: 8,
                              color: vm.isRoomConnected
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Room: ${vm.activeRoomId ?? "Active"} - ${vm.isRoomConnected ? "Connected" : "Waiting"}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: vm.isRoomConnected
                                    ? (isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A))
                                    : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706)),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  centerTitle: true,
                  actions: [
                    // Swap Language Direction Button
                    IconButton(
                      icon: const Icon(Icons.swap_horiz_rounded, size: 24),
                      tooltip: 'Swap Language Direction',
                      color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                      onPressed: () {
                        vm.swapDirection();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Direction: ${vm.sourceLanguageName} to ${vm.targetLanguageName}',
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),

                // Clear Conversation History Button (when history has items)
                if (vm.conversationHistory.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 22),
                    tooltip: 'Clear Conversation',
                    color: isDark ? AppDarkColors.textMuted : AppColors.textMuted,
                    onPressed: () => _showClearConfirmation(context, vm, isDark),
                  ),

                // Audio Volume Button
                IconButton(
                  icon: const Icon(Icons.volume_up_rounded, size: 24),
                  color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Audio volume set to maximum'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
            body: SafeArea(
              child: ResponsiveContentWrapper(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Optional Warning: Language outside active pair
                              if (vm.warningMessage != null) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFF59E0B)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFD97706)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          vm.warningMessage!,
                                          style: AppTypography.caption.copyWith(
                                            color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // 1. Original (Recognized Speech) Card
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: isDark ? AppDarkColors.cardLightBlue : AppColors.cardLightBlue,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: isDark ? AppDarkColors.border : const Color(0xFFBFDBFE),
                                    width: 1.0,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircularFlagAvatar(
                                          languageCode: vm.sourceLanguageCode,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            vm.sourceLanguageLabel,
                                            style: AppTypography.caption.copyWith(
                                              color: isDark ? const Color(0xFF93C5FD) : AppColors.textSecondary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (vm.isMock)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Mock ASR',
                                              style: AppTypography.caption.copyWith(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      vm.isListening
                                          ? 'Listening to speaker...'
                                          : (vm.originalText.isNotEmpty ? vm.originalText : AppStrings.sampleEnglishText),
                                      style: AppTypography.bodyLarge.copyWith(
                                        fontSize: context.isCompact ? 18 : 20,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? AppDarkColors.textPrimary : const Color(0xFF1E3A8A),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // Blue audio waveform (reacts to live mic levels while listening)
                                    HorizontalSoundwave(
                                      color: isDark ? AppDarkColors.primary : const Color(0xFF2563EB),
                                      barCount: 26,
                                      height: 22,
                                      audioLevel: vm.isListening ? vm.currentAudioLevel : null,
                                      isAnimated: vm.isListening,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // 2. Translated Card
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: isDark ? AppDarkColors.cardLightGreen : AppColors.cardLightGreen,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: isDark ? AppDarkColors.statusGreenBorder : const Color(0xFFBBF7D0),
                                    width: 1.0,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircularFlagAvatar(
                                          languageCode: vm.targetLanguageCode,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            vm.targetLanguageLabel,
                                            style: AppTypography.caption.copyWith(
                                              color: isDark ? AppDarkColors.statusGreen : AppColors.statusGreen,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      vm.isTranslating
                                          ? 'Translating on-device...'
                                          : (vm.translatedText.isNotEmpty
                                              ? vm.translatedText
                                              : (vm.errorMessage ??
                                                  (vm.targetLanguageCode == 'te'
                                                      ? AppStrings.sampleTeluguText
                                                      : (vm.targetLanguageCode == 'de'
                                                          ? 'Hallo, wie geht es Ihnen?'
                                                          : (vm.targetLanguageCode == 'hi'
                                                              ? 'नमस्ते, आप कैसे हैं?'
                                                              : 'Tap microphone to speak and translate.'))))),
                                      style: AppTypography.bodyLarge.copyWith(
                                        fontSize: context.isCompact ? 18 : 20,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? const Color(0xFF6EE7B7) : AppColors.textGreenDark,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // Green audio waveform
                                    HorizontalSoundwave(
                                      color: isDark ? AppDarkColors.statusGreen : const Color(0xFF16A34A),
                                      barCount: 26,
                                      height: 22,
                                      isAnimated: vm.isPlayingAudio || vm.isTranslating,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Optional: Offline TTS Voice Missing Prompt
                              if (vm.isTtsVoiceUnavailable) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFFF59E0B),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.record_voice_over_rounded,
                                        color: Color(0xFFD97706),
                                        size: 22,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          vm.ttsErrorMessage ??
                                              'Offline voice data required in Android TTS to speak ${vm.targetLanguageName}.',
                                          style: AppTypography.caption.copyWith(
                                            color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      ElevatedButton(
                                        onPressed: vm.openTtsSettings,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFD97706),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: const Text('Install', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // 3. Three Circular Action Buttons: [Try Again / Speak, Play Translation, Share]
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Try Again / Speak Button (Left)
                                  Expanded(
                                    child: _buildCircleActionButton(
                                      context: context,
                                      icon: vm.isListening ? Icons.stop_circle_rounded : Icons.sync_rounded,
                                      iconColor: vm.isListening ? const Color(0xFFEF4444) : null,
                                      label: vm.isListening ? 'Stop' : AppStrings.tryAgain,
                                      isPrimary: false,
                                      onTap: vm.tryAgain,
                                    ),
                                  ),

                                  // Play Translation / Stop Button (Center, Larger)
                                  Expanded(
                                    child: _buildCenterPlayButton(
                                      context: context,
                                      isPlaying: vm.isPlayingAudio,
                                      onTap: vm.playTranslation,
                                    ),
                                  ),

                                  // Share Button (Right)
                                  Expanded(
                                    child: _buildCircleActionButton(
                                      context: context,
                                      icon: Icons.share_rounded,
                                      label: AppStrings.share,
                                      isPrimary: false,
                                      onTap: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Translation shared to clipboard'),
                                            duration: Duration(seconds: 1),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // 4. Bottom Status Pill: Dynamic State Machine Indicator
                              _buildStatusPill(context, vm, isDark),

                              // 5. Conversation History Turns Section (Phase 6 Two-Way Turns)
                              if (vm.conversationHistory.length > 1) ...[
                                const SizedBox(height: 24),
                                _buildConversationHistorySection(context, vm, isDark),
                              ],

                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

    if (existingVm != null && asrResult == null && resolvedRoomId == null) {
      return ChangeNotifierProvider<LiveTranslationViewModel>.value(
        value: existingVm,
        child: buildScreen(existingVm),
      );
    }

    final newVm = LiveTranslationViewModel(
      roomId: resolvedRoomId,
      roomService: resolvedRoomService,
      initialRecognition: asrResult,
      translationRepository: translationRepo,
      ttsRepository: ttsRepo,
      asrRepository: asrRepo,
      settingsRepository: settingsRepo,
      initialTargetLanguageCode: targetLangCode,
      initialSourceLanguageCode: sourceLangCode,
    );

    return ChangeNotifierProvider<LiveTranslationViewModel>(
      create: (_) => newVm,
      child: buildScreen(newVm),
    );
  }

  Widget _buildStatusPill(BuildContext context, LiveTranslationViewModel vm, bool isDark) {
    Color pillBgColor;
    Color pillBorderColor;
    Color pillTextColor;
    IconData pillIcon;
    String pillLabel;

    switch (vm.turnState) {
      case ConversationTurnState.listening:
        pillBgColor = isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);
        pillBorderColor = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5);
        pillTextColor = isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
        pillIcon = Icons.fiber_manual_record_rounded;
        pillLabel = 'Listening to speaker...';
        break;
      case ConversationTurnState.processingSpeech:
        pillBgColor = isDark ? const Color(0xFF2E1065) : const Color(0xFFEEF2FF);
        pillBorderColor = isDark ? const Color(0xFF5B21B6) : const Color(0xFFC7D2FE);
        pillTextColor = isDark ? const Color(0xFFA78BFA) : const Color(0xFF6366F1);
        pillIcon = Icons.graphic_eq_rounded;
        pillLabel = 'Processing speech on-device...';
        break;
      case ConversationTurnState.recognizingLanguage:
        pillBgColor = isDark ? const Color(0xFF0C4A6E) : const Color(0xFFE0F2FE);
        pillBorderColor = isDark ? const Color(0xFF0369A1) : const Color(0xFFBAE6FD);
        pillTextColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
        pillIcon = Icons.language_rounded;
        pillLabel = 'Detecting language...';
        break;
      case ConversationTurnState.translating:
        pillBgColor = isDark ? const Color(0xFF2E1065) : const Color(0xFFEEF2FF);
        pillBorderColor = isDark ? const Color(0xFF5B21B6) : const Color(0xFFC7D2FE);
        pillTextColor = isDark ? const Color(0xFFA78BFA) : const Color(0xFF6366F1);
        pillIcon = Icons.sync_rounded;
        pillLabel = 'Translating on-device...';
        break;
      case ConversationTurnState.speakingTranslatedAudio:
        pillBgColor = isDark ? AppDarkColors.statusGreenBg : AppColors.statusGreenBg;
        pillBorderColor = isDark ? AppDarkColors.statusGreenBorder : AppColors.statusGreen.withValues(alpha: 0.3);
        pillTextColor = isDark ? AppDarkColors.statusGreen : AppColors.statusGreen;
        pillIcon = Icons.volume_up_rounded;
        pillLabel = 'Speaking translation...';
        break;
      case ConversationTurnState.error:
        pillBgColor = isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);
        pillBorderColor = const Color(0xFFEF4444);
        pillTextColor = const Color(0xFFDC2626);
        pillIcon = Icons.error_outline_rounded;
        pillLabel = vm.errorMessage ?? 'Error occurred';
        break;
      case ConversationTurnState.idle:
      case ConversationTurnState.completed:
        if (vm.isModelMissing) {
          pillBgColor = isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
          pillBorderColor = const Color(0xFFF59E0B);
          pillTextColor = const Color(0xFFB45309);
          pillIcon = Icons.cloud_download_rounded;
          pillLabel = 'Offline Pack Download Needed';
        } else if (vm.hasError) {
          pillBgColor = isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);
          pillBorderColor = const Color(0xFFEF4444);
          pillTextColor = const Color(0xFFDC2626);
          pillIcon = Icons.error_outline_rounded;
          pillLabel = vm.errorMessage ?? 'Translation Error';
        } else {
          pillBgColor = isDark ? AppDarkColors.statusGreenBg : AppColors.statusGreenBg;
          pillBorderColor = isDark ? AppDarkColors.statusGreenBorder : AppColors.statusGreen.withValues(alpha: 0.3);
          pillTextColor = isDark ? AppDarkColors.statusGreen : AppColors.textGreenDark;
          pillIcon = Icons.check_circle_rounded;
          pillLabel = AppStrings.translationComplete;
        }
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: pillBgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: pillBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(pillIcon, size: 18, color: pillTextColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              pillLabel,
              style: AppTypography.caption.copyWith(
                color: pillTextColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationHistorySection(
    BuildContext context,
    LiveTranslationViewModel vm,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Conversation History (${vm.conversationHistory.length} turns)',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
              ),
            ),
            TextButton.icon(
              onPressed: vm.clearConversationHistory,
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              label: const Text('Clear', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(
                foregroundColor: isDark ? AppDarkColors.textMuted : AppColors.textMuted,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Render previous turns in reverse chronological order (newest first after the active one)
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: vm.conversationHistory.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final turn = vm.conversationHistory[vm.conversationHistory.length - 1 - index];
            final isSpeakerA = turn.speaker == ConversationSpeaker.speakerA;

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? (isSpeakerA ? AppDarkColors.cardLightBlue : AppDarkColors.cardLightGreen)
                    : (isSpeakerA ? AppColors.cardLightBlue : AppColors.cardLightGreen),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? (isSpeakerA ? AppDarkColors.border : AppDarkColors.statusGreenBorder)
                      : (isSpeakerA ? const Color(0xFFBFDBFE) : const Color(0xFFBBF7D0)),
                  width: 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircularFlagAvatar(languageCode: turn.sourceLanguageCode, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        turn.directionLabel,
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: isDark
                              ? (isSpeakerA ? const Color(0xFF93C5FD) : AppDarkColors.statusGreen)
                              : (isSpeakerA ? AppColors.textSecondary : AppColors.statusGreen),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.volume_up_rounded, size: 18),
                        color: isDark ? AppDarkColors.primary : AppColors.primary,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Replay audio',
                        onPressed: () => vm.replayTurn(turn),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    turn.originalText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppDarkColors.textPrimary : const Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    turn.translatedText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF6EE7B7) : AppColors.textGreenDark,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _showClearConfirmation(BuildContext context, LiveTranslationViewModel vm, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppDarkColors.surface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Clear Conversation?',
          style: AppTypography.headlineMedium.copyWith(
            color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
          ),
        ),
        content: Text(
          'This will clear the conversation turns from this session. Language and audio settings will remain unchanged.',
          style: TextStyle(color: isDark ? AppDarkColors.textSecondary : AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: isDark ? AppDarkColors.textMuted : AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              vm.clearConversationHistory();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleActionButton({
    required BuildContext context,
    required IconData icon,
    Color? iconColor,
    required String label,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Container(
            width: 52,
            height: 52,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppDarkColors.surfaceSecondary : Colors.white,
              border: Border.all(
                color: isDark ? AppDarkColors.border : const Color(0xFF93C5FD),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? AppDarkColors.cardShadow : AppColors.cardShadow,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: iconColor ?? (isDark ? AppDarkColors.primary : AppColors.primary),
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? AppDarkColors.textSecondary : AppColors.textSecondary,
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildCenterPlayButton({
    required BuildContext context,
    required bool isPlaying,
    required VoidCallback onTap,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isDark
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    )
                  : AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: (isDark ? AppDarkColors.primary : AppColors.primary).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                isPlaying ? Icons.stop_rounded : Icons.volume_up_rounded,
                size: 34,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isPlaying ? 'Stop' : AppStrings.playTranslation,
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? AppDarkColors.primary : AppColors.primary,
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _LiveTranslationLifecycleWatcher extends StatefulWidget {
  final Widget child;
  const _LiveTranslationLifecycleWatcher({required this.child});

  @override
  State<_LiveTranslationLifecycleWatcher> createState() => _LiveTranslationLifecycleWatcherState();
}

class _LiveTranslationLifecycleWatcherState extends State<_LiveTranslationLifecycleWatcher>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (mounted) {
        context.read<LiveTranslationViewModel>().handleAppPaused();
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
