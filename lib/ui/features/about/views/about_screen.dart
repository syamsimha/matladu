import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/responsive/responsive_layout.dart';
import '../../../../core/widgets/matladu_logo.dart';

/// Screen 7: About
/// Reproduces the official reference design with large hero logo,
/// version pill, mission description, 3 feature highlight cards, and copyright footer.
/// Fully responsive on phones, tablets, and large displays.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppDarkColors.background : AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppStrings.aboutTitle,
          style: AppTypography.headlineMedium.copyWith(
            fontSize: 18,
            color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
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
                        const Spacer(flex: 2),

                        // 1. Center Hero Branding: Dual Speech-Bubble Logo
                        MatladuLogo(size: context.isCompact ? 90 : 110),

                        const SizedBox(height: 18),

                        // "Matladu" Title
                        Text(
                          AppStrings.appName,
                          style: AppTypography.displayLarge.copyWith(
                            fontSize: context.isCompact ? 24 : 28,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                          ),
                        ),

                        const SizedBox(height: 6),

                        // "Speak • Translate • Connect" Tagline
                        Text(
                          AppStrings.tagline,
                          style: AppTypography.tagline.copyWith(
                            fontSize: 13,
                            color: isDark ? AppDarkColors.textSecondary : AppColors.textSecondary,
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Version Pill: Version 1.0.0
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2E1065) : const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(20),
                            border: isDark ? Border.all(color: const Color(0xFF7E22CE).withValues(alpha: 0.4), width: 1) : null,
                          ),
                          child: Text(
                            AppStrings.version,
                            style: AppTypography.caption.copyWith(
                              color: isDark ? const Color(0xFFC084FC) : const Color(0xFF7E22CE),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Description
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            AppStrings.aboutDescription,
                            style: AppTypography.bodyMedium.copyWith(
                              fontSize: 14,
                              color: isDark ? AppDarkColors.textSecondary : AppColors.textSecondary,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const Spacer(flex: 2),

                        const SizedBox(height: 16),

                        // 2. Three Feature Highlight Cards (Online Translation, Offline Support, Privacy First)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildFeatureCard(
                                  isDark: isDark,
                                  icon: Icons.bolt_rounded,
                                  iconColor: AppColors.statusYellow,
                                  title: AppStrings.featureOnline,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildFeatureCard(
                                  isDark: isDark,
                                  icon: Icons.download_rounded,
                                  iconColor: isDark ? AppDarkColors.primary : AppColors.primary,
                                  title: AppStrings.featureOffline,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildFeatureCard(
                                  isDark: isDark,
                                  icon: Icons.shield_rounded,
                                  iconColor: isDark ? AppDarkColors.statusGreen : AppColors.statusGreen,
                                  title: AppStrings.featurePrivacy,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(flex: 3),

                        const SizedBox(height: 24),

                        // 3. Footer: "Made with ❤️ for everyone" & "© 2026 Matladu"
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            children: [
                              Text(
                                AppStrings.madeWithLove,
                                style: AppTypography.caption.copyWith(
                                  color: isDark ? AppDarkColors.textSecondary : AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                AppStrings.copyright,
                                style: AppTypography.caption.copyWith(
                                  color: isDark ? AppDarkColors.textMuted : AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
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
  }

  Widget _buildFeatureCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? AppDarkColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppDarkColors.border : AppColors.borderLight,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.3) : AppColors.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: iconColor),
          const SizedBox(height: 10),
          Text(
            title,
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
              fontSize: 12,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
