import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/responsive/responsive_layout.dart';
import '../../../../core/widgets/connected_cloud_phone_widget.dart';

/// Screen 8: Connection Mode
/// Matches the official reference design with cloud + phone illustration,
/// "Connected!" status, Auto-switch guarantee card, and "Got it" button.
/// Fully responsive on phones, tablets, and varied aspect ratios.
class ConnectionModeScreen extends StatelessWidget {
  const ConnectionModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          AppStrings.connectionMode,
          style: AppTypography.headlineMedium.copyWith(fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 24),
            color: AppColors.textPrimary,
            onPressed: () => Navigator.pop(context),
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
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const Spacer(flex: 2),

                          // 1. Cloud + Smartphone Wi-Fi Illustration with Sparkles
                          ConnectedCloudPhoneWidget(
                            size: context.isCompact ? 160 : 190,
                          ),

                          const SizedBox(height: 24),

                          // 2. "Connected!" Headline
                          Text(
                            AppStrings.connected,
                            style: AppTypography.displayLarge.copyWith(
                              fontSize: context.isCompact ? 22 : 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Subtitle
                          Text(
                            AppStrings.connectedSubtitle,
                            style: AppTypography.bodyMedium.copyWith(
                              fontSize: context.isCompact ? 13 : 15,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const Spacer(flex: 2),

                          const SizedBox(height: 20),

                          // 3. Green "Auto Switch Enabled" Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.cardLightGreen,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFBBF7D0),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: const BoxDecoration(
                                    color: AppColors.statusGreen,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        AppStrings.autoSwitchEnabled,
                                        style: AppTypography.titleMedium.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: AppColors.textGreenDark,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        AppStrings.autoSwitchSubtitle,
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.textGreenDark.withOpacity(0.8),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(flex: 3),

                          const SizedBox(height: 20),

                          // 4. "Got it" Solid Blue Pill Button
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(26),
                                  ),
                                ),
                                child: Text(
                                  AppStrings.gotIt,
                                  style: AppTypography.button.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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
}
