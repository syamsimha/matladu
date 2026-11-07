import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/matladu_logo.dart';

/// Screen 7: About
/// Reproduces the official reference design with large hero logo,
/// version pill, mission description, 3 feature highlight cards, and copyright footer.
/// Fully responsive and overflow-safe across all screen dimensions.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppStrings.aboutTitle,
          style: AppTypography.headlineMedium.copyWith(fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
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
                      const MatladuLogo(size: 110),

                      const SizedBox(height: 18),

                      // "Matladu AI" Title
                      Text(
                        AppStrings.appName,
                        style: AppTypography.displayLarge.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // "Speak • Translate • Connect" Tagline
                      Text(
                        AppStrings.tagline,
                        style: AppTypography.tagline.copyWith(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Version Pill: Version 1.0.0
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          AppStrings.version,
                          style: AppTypography.caption.copyWith(
                            color: const Color(0xFF7E22CE),
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
                            color: AppColors.textSecondary,
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
                                icon: Icons.bolt_rounded,
                                iconColor: AppColors.statusYellow,
                                title: AppStrings.featureOnline,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildFeatureCard(
                                icon: Icons.download_rounded,
                                iconColor: AppColors.primary,
                                title: AppStrings.featureOffline,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildFeatureCard(
                                icon: Icons.shield_rounded,
                                iconColor: AppColors.statusGreen,
                                title: AppStrings.featurePrivacy,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(flex: 3),

                      const SizedBox(height: 24),

                      // 3. Footer: "Made with ❤️ for everyone" & "© 2026 Matladu AI"
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          children: [
                            Text(
                              AppStrings.madeWithLove,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              AppStrings.copyright,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textMuted,
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
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color iconColor,
    required String title,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: Offset(0, 3),
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
              color: AppColors.textPrimary,
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
