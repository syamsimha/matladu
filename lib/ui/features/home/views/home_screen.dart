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
import '../view_models/home_view_model.dart';

/// Screen 2: Home / Translator
/// Matches the official reference design with custom top bar, online status pill,
/// concentric glowing mic rings, language selector card, "Try saying" soundwave card,
/// and 4-tab bottom navigation bar. Built to be 100% overflow-free and responsive.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeViewModel>(
      builder: (context, vm, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
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
                                  // Hamburger Menu Icon
                                  IconButton(
                                    icon: const Icon(Icons.menu_rounded, size: 26),
                                    color: AppColors.textPrimary,
                                    onPressed: () {
                                      Navigator.pushNamed(context, AppRoutes.settings)
                                          .then((_) => vm.refreshFromSettings());
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
                                        ),
                                      ),
                                    ],
                                  ),

                                  // VIP Crown Icon
                                  IconButton(
                                    icon: const Icon(
                                      Icons.workspace_premium_rounded,
                                      size: 26,
                                      color: AppColors.crownGold,
                                    ),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Matladu AI Premium • Active'),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),

                            // 2. Status Pill: 🟢 Online • Ready
                            GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(context, AppRoutes.connectionMode)
                                    .then((_) => vm.refreshFromSettings());
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.statusGreenBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.statusGreen.withOpacity(0.25),
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.wifi_rounded,
                                      size: 15,
                                      color: AppColors.statusGreen,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      AppStrings.onlineReady,
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.statusGreen,
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
                            ConcentricRippleRings(
                              isListening: vm.isListening,
                              onTap: () {
                                vm.startListening(() {
                                  Navigator.pushNamed(context, AppRoutes.liveTranslation);
                                });
                              },
                            ),

                            const SizedBox(height: 12),

                            // "Tap to Speak" & "Speak naturally in any language"
                            Text(
                              AppStrings.tapToSpeak,
                              style: AppTypography.headlineMedium.copyWith(
                                fontSize: context.isCompact ? 18 : 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppStrings.speakNaturally,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: context.isCompact ? 12 : 13,
                              ),
                            ),

                            const Spacer(flex: 1),

                            // 4. Language Selector Card: [Flag] English (Detect) ⇄ [Flag] Telugu (తెలుగు)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: AppColors.borderLight, width: 1.0),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: AppColors.cardShadow,
                                      blurRadius: 12,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Left Language: English (Detect)
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          final result = await Navigator.pushNamed(
                                            context,
                                            AppRoutes.languageSelection,
                                            arguments: {'isSelectingSource': true},
                                          );
                                          if (result != null) {
                                            vm.setSourceLanguage(result as dynamic);
                                          }
                                        },
                                        child: Row(
                                          children: [
                                            CircularFlagAvatar(
                                              languageCode: vm.sourceLanguage.code,
                                              size: 28,
                                            ),
                                            const SizedBox(width: 10),
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
                                                    ),
                                                  ),
                                                  Text(
                                                    '(Detect)',
                                                    style: AppTypography.caption.copyWith(
                                                      fontSize: 11,
                                                      color: AppColors.textMuted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Center Swap Button ⇄
                                    InkWell(
                                      onTap: vm.swapLanguages,
                                      borderRadius: BorderRadius.circular(14),
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: AppColors.cardLightBlue,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.swap_horiz_rounded,
                                          color: AppColors.primary,
                                          size: 22,
                                        ),
                                      ),
                                    ),

                                    // Right Language: Telugu (తెలుగు)
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          final result = await Navigator.pushNamed(
                                            context,
                                            AppRoutes.languageSelection,
                                            arguments: {'isSelectingSource': false},
                                          );
                                          if (result != null) {
                                            vm.setTargetLanguage(result as dynamic);
                                          }
                                        },
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            CircularFlagAvatar(
                                              languageCode: vm.targetLanguage.code,
                                              size: 28,
                                            ),
                                            const SizedBox(width: 10),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  vm.targetLanguage.name,
                                                  style: AppTypography.titleMedium.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                Text(
                                                  '(${vm.targetLanguage.nativeName})',
                                                  style: AppTypography.caption.copyWith(
                                                    fontSize: 11,
                                                    color: AppColors.textMuted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(color: AppColors.borderLight, width: 1.0),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: AppColors.cardShadow,
                                        blurRadius: 14,
                                        offset: Offset(0, 4),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
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
                        style: AppTypography.headlineMedium,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (vm.history.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No saved translations yet.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: vm.history.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final item = vm.history[i];
                          return ListTile(
                            title: Text(item.sourceText, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(item.translatedText),
                            trailing: Text(
                              '${item.sourceLanguageCode.toUpperCase()} → ${item.targetLanguageCode.toUpperCase()}',
                              style: const TextStyle(fontSize: 11, color: AppColors.primary),
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
