import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/responsive/responsive_layout.dart';
import '../../../../core/widgets/circular_flag_avatar.dart';
import '../../../../core/widgets/concentric_ripple_rings.dart';
import '../../../../core/widgets/horizontal_soundwave.dart';
import '../../../../core/widgets/matladu_bottom_nav_bar.dart';
import '../../../../core/widgets/matladu_logo.dart';
import '../../theme/view_models/theme_view_model.dart';
import '../../live_translation/view_models/live_translation_view_model.dart';
import '../view_models/home_view_model.dart';
import '../../../../data/services/room/i_room_service.dart';
import 'widgets/room_talk_menu_bottom_sheet.dart';

/// Screen 2: Home / Translator
/// Matches the official reference design with custom top bar, online status pill,
/// concentric glowing mic rings, language selector card, "Try saying" soundwave card,
/// and 4-tab bottom navigation bar. Built to be 100% overflow-free and responsive.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<HomeViewModel>(
      builder: (context, vm, _) {
        return Scaffold(
          backgroundColor: isDark ? AppDarkColors.background : AppColors.background,
          body: SafeArea(
            child: ResponsiveContentWrapper(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: Column(
                          children: [
                            // 1. Top Custom App Bar
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Hamburger Menu Icon (Talk Rooms Navigation)
                                  IconButton(
                                    icon: Icon(
                                      Icons.menu_rounded,
                                      size: 26,
                                      color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                                    ),
                                    tooltip: 'Talk Rooms',
                                    onPressed: () {
                                      try {
                                        final roomService = Provider.of<IRoomService>(context, listen: false);
                                        RoomTalkMenuBottomSheet.show(
                                          context,
                                          roomService: roomService,
                                          sourceLanguageCode: vm.sourceLanguage.code,
                                          targetLanguageCode: vm.targetLanguage.code,
                                        );
                                      } catch (e) {
                                        debugPrint('[HomeScreen] Room service unavailable: $e');
                                      }
                                    },
                                  ),

                                  // Center Logo + Title
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const MatladuLogo(size: 32),
                                      const SizedBox(width: 8),
                                      Text(
                                        AppStrings.appName,
                                        style: AppTypography.displayMedium.copyWith(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Theme Toggle Button (Light/Dark mode)
                                  InkWell(
                                    key: const ValueKey('theme_toggle_button'),
                                    onTap: () {
                                      try {
                                        context.read<ThemeViewModel>().toggleTheme();
                                      } catch (_) {}
                                    },
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: isDark ? AppDarkColors.surface : const Color(0xFFF0F5FF),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isDark ? AppDarkColors.border : AppColors.borderLight,
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Icon(
                                        isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                                        size: 20,
                                        color: isDark ? const Color(0xFFFBBF24) : AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 2. Status Pill: Dynamic connectivity and readiness
                            GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(context, AppRoutes.connectionMode)
                                    .then((_) => vm.refreshFromSettings());
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: vm.getStatusPillBgColor(isDark),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: vm.getStatusPillColor(isDark).withValues(alpha: 0.25),
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      vm.statusPillIcon,
                                      size: 15,
                                      color: vm.getStatusPillColor(isDark),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      vm.statusPillText,
                                      style: AppTypography.caption.copyWith(
                                        color: vm.getStatusPillColor(isDark),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const Spacer(flex: 1),

                            // 3. Central Concentric Glowing Mic Rings & Labels
                            Builder(
                              builder: (context) {
                                LiveTranslationViewModel? liveVm;
                                try {
                                  liveVm = Provider.of<LiveTranslationViewModel>(context);
                                } catch (_) {}
                                final isListening = (liveVm?.isListening ?? false) || vm.isListening;
                                return ConcentricRippleRings(
                                  isListening: isListening,
                                  onTap: () async {
                                    if (liveVm != null) {
                                      final success = await liveVm.startSessionFromHome(
                                        sourceLanguage: vm.sourceLanguage,
                                        targetLanguage: vm.targetLanguage,
                                      );
                                      if (success && context.mounted) {
                                        Navigator.pushNamed(context, AppRoutes.liveTranslation);
                                      } else if (!success && context.mounted) {
                                        final err = liveVm?.errorMessage ?? 'Microphone hardware is unavailable. Please try again.';
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(err),
                                            backgroundColor: AppColors.errorRed,
                                            duration: const Duration(seconds: 3),
                                          ),
                                        );
                                      }
                                    } else {
                                      vm.startListening(() {
                                        Navigator.pushNamed(context, AppRoutes.liveTranslation);
                                      });
                                    }
                                  },
                                );
                              },
                            ),

                            const SizedBox(height: 12),

                            // "Tap to Speak" & "Speak naturally in any language"
                            Text(
                              AppStrings.tapToSpeak,
                              style: AppTypography.headlineMedium.copyWith(
                                fontSize: context.isCompact ? 18 : 20,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppStrings.speakNaturally,
                              style: AppTypography.caption.copyWith(
                                color: isDark ? AppDarkColors.textSecondary : AppColors.textSecondary,
                                fontSize: context.isCompact ? 12 : 13,
                              ),
                            ),

                            const Spacer(flex: 1),

                            // 4. Separate Language Selector Boxes: [Source Box] ⇄ [Target Box]
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  // Left: Separate Source Language Selection Box
                                  Expanded(
                                    child: InkWell(
                                      key: const ValueKey('source_language_box'),
                                      onTap: () async {
                                        final result = await Navigator.pushNamed(
                                          context,
                                          AppRoutes.languageSelection,
                                          arguments: {
                                            'isSelectingSource': true,
                                            'currentLanguage': vm.sourceLanguage,
                                          },
                                        );
                                        if (result != null) {
                                          vm.setSourceLanguage(result as dynamic);
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: isDark ? AppDarkColors.surface : Colors.white,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isDark ? AppDarkColors.border : AppColors.borderLight,
                                            width: 1.0,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: isDark ? Colors.black.withValues(alpha: 0.2) : AppColors.cardShadow,
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            CircularFlagAvatar(
                                              languageCode: vm.sourceLanguage.code,
                                              size: 28,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    vm.sourceLanguage.name,
                                                    style: AppTypography.titleMedium.copyWith(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 14,
                                                      color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    vm.sourceLanguage.code == 'auto'
                                                        ? '(Detect)'
                                                        : '(${vm.sourceLanguage.nativeName})',
                                                    style: AppTypography.caption.copyWith(
                                                      fontSize: 11,
                                                      color: isDark ? AppDarkColors.textSecondary : AppColors.textMuted,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  // Center Floating Swap Button ⇄
                                  InkWell(
                                    key: const ValueKey('swap_languages_button'),
                                    onTap: vm.swapLanguages,
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: isDark ? AppDarkColors.cardLightBlue : AppColors.cardLightBlue,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isDark ? AppDarkColors.border : AppColors.borderLight,
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.swap_horiz_rounded,
                                        color: isDark ? AppDarkColors.primary : AppColors.primary,
                                        size: 22,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  // Right: Separate Target Language Selection Box
                                  Expanded(
                                    child: InkWell(
                                      key: const ValueKey('target_language_box'),
                                      onTap: () async {
                                        final result = await Navigator.pushNamed(
                                          context,
                                          AppRoutes.languageSelection,
                                          arguments: {
                                            'isSelectingSource': false,
                                            'currentLanguage': vm.targetLanguage,
                                          },
                                        );
                                        if (result != null) {
                                          vm.setTargetLanguage(result as dynamic);
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: isDark ? AppDarkColors.surface : Colors.white,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isDark ? AppDarkColors.border : AppColors.borderLight,
                                            width: 1.0,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: isDark ? Colors.black.withValues(alpha: 0.2) : AppColors.cardShadow,
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            CircularFlagAvatar(
                                              languageCode: vm.targetLanguage.code,
                                              size: 28,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    vm.targetLanguage.name,
                                                    style: AppTypography.titleMedium.copyWith(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 14,
                                                      color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    '(${vm.targetLanguage.nativeName})',
                                                    style: AppTypography.caption.copyWith(
                                                      fontSize: 11,
                                                      color: isDark ? AppDarkColors.textSecondary : AppColors.textMuted,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 14),

                            // 5. "Try saying..." Prompt Card with Horizontal Soundwave Bars
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(22),
                                onTap: () {
                                  Navigator.pushNamed(context, AppRoutes.liveTranslation);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppDarkColors.surface : Colors.white,
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: isDark ? AppDarkColors.border : AppColors.borderLight,
                                      width: 1.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isDark ? Colors.black.withValues(alpha: 0.25) : AppColors.cardShadow,
                                        blurRadius: 14,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.lightbulb_rounded,
                                            size: 18,
                                            color: AppColors.statusYellow,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            AppStrings.trySaying,
                                            style: AppTypography.caption.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textSecondary,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        AppStrings.trySayingQuote,
                                        style: AppTypography.titleMedium.copyWith(
                                          fontStyle: FontStyle.italic,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      // Multi-colored purple/violet horizontal soundwave bars
                                      const HorizontalSoundwave(
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFF6366F1),
                                            Color(0xFFA855F7),
                                            Color(0xFF38BDF8),
                                          ],
                                        ),
                                        barCount: 30,
                                        height: 22,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 6. 4-Tab Bottom Navigation Bar (Home, Offline, History, Settings)
          bottomNavigationBar: MatladuBottomNavBar(
            currentIndex: vm.currentTab,
            onTabSelected: (index) {
              vm.setTab(index);
              if (index == 1) {
                Navigator.pushNamed(context, AppRoutes.offlinePacks)
                    .then((_) => vm.setTab(0));
              } else if (index == 2) {
                _showHistoryBottomSheet(context, vm);
              } else if (index == 3) {
                Navigator.pushNamed(context, AppRoutes.settings)
                    .then((_) {
                  vm.setTab(0);
                  vm.refreshFromSettings();
                });
              }
            },
          ),
        );
      },
    );
  }

  void _showHistoryBottomSheet(BuildContext context, HomeViewModel vm) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppDarkColors.surface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ResponsiveContentWrapper(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Translation History',
                        style: AppTypography.headlineMedium.copyWith(
                          color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  Divider(color: isDark ? AppDarkColors.border : AppColors.borderLight),
                  if (vm.history.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No saved translations yet.',
                          style: TextStyle(color: isDark ? AppDarkColors.textMuted : AppColors.textMuted),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: vm.history.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? AppDarkColors.border : AppColors.borderLight),
                        itemBuilder: (_, i) {
                          final item = vm.history[i];
                          return ListTile(
                            title: Text(
                              item.sourceText,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              item.translatedText,
                              style: TextStyle(
                                color: isDark ? AppDarkColors.textSecondary : AppColors.textSecondary,
                              ),
                            ),
                            trailing: Text(
                              ' -> ',
                              style: TextStyle(fontSize: 11, color: isDark ? AppDarkColors.primary : AppColors.primary),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) => vm.setTab(0));
  }
}
