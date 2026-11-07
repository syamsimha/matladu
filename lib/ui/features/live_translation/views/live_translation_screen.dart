import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/circular_flag_avatar.dart';
import '../../../../core/widgets/horizontal_soundwave.dart';
import '../view_models/live_translation_view_model.dart';

/// Screen 3: Live Translation
/// Reproduces the official reference design with Original (English) light blue card,
/// Translated (Telugu) mint green card, 3-button circular action bar, and Translation Complete badge.
/// Fully responsive and overflow-safe across small phones, tablets, and large displays.
class LiveTranslationScreen extends StatelessWidget {
  const LiveTranslationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LiveTranslationViewModel(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            AppStrings.liveTranslationTitle,
            style: AppTypography.headlineMedium.copyWith(fontSize: 18),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.volume_up_rounded, size: 24),
              color: AppColors.textPrimary,
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
        body: Consumer<LiveTranslationViewModel>(
          builder: (context, vm, _) {
            return SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Column(
                            children: [
                              // 1. Original (English) Light Blue Card
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.cardLightBlue,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: const Color(0xFFBFDBFE),
                                    width: 1.0,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const CircularFlagAvatar(
                                          languageCode: 'en',
                                          size: 24,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          AppStrings.originalEnglish,
                                          style: AppTypography.caption.copyWith(
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      AppStrings.sampleEnglishText,
                                      style: AppTypography.bodyLarge.copyWith(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1E3A8A),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // Blue audio waveform
                                    const HorizontalSoundwave(
                                      color: Color(0xFF2563EB),
                                      barCount: 26,
                                      height: 22,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // 2. Translated (Telugu) Mint Green Card
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.cardLightGreen,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: const Color(0xFFBBF7D0),
                                    width: 1.0,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const CircularFlagAvatar(
                                          languageCode: 'te',
                                          size: 24,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          AppStrings.translatedTelugu,
                                          style: AppTypography.caption.copyWith(
                                            color: AppColors.statusGreen,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      AppStrings.sampleTeluguText,
                                      style: AppTypography.bodyLarge.copyWith(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textGreenDark,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // Green audio waveform
                                    HorizontalSoundwave(
                                      color: const Color(0xFF16A34A),
                                      barCount: 26,
                                      height: 22,
                                      isAnimated: vm.isPlayingAudio,
                                    ),
                                  ],
                                ),
                              ),

                              const Spacer(),

                              const SizedBox(height: 20),

                              // 3. Three Circular Action Buttons: [Try Again, Play Translation, Share]
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Try Again Button (Left)
                                  _buildCircleActionButton(
                                    icon: Icons.sync_rounded,
                                    label: AppStrings.tryAgain,
                                    isPrimary: false,
                                    onTap: vm.tryAgain,
                                  ),

                                  // Play Translation Button (Center, Larger)
                                  _buildCenterPlayButton(
                                    isPlaying: vm.isPlayingAudio,
                                    onTap: vm.playTranslation,
                                  ),

                                  // Share Button (Right)
                                  _buildCircleActionButton(
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
                                ],
                              ),

                              const SizedBox(height: 28),

                              // 4. Bottom Status Pill: ✔ Translation Complete!
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.statusGreenBg,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: AppColors.statusGreen.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 18,
                                      color: AppColors.statusGreen,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppStrings.translationComplete,
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.textGreenDark,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCircleActionButton({
    required IconData icon,
    required String label,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: const Color(0xFF93C5FD),
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildCenterPlayButton({
    required bool isPlaying,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.volume_up_rounded,
                size: 34,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.playTranslation,
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
