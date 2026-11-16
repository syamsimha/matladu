import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/responsive/responsive_layout.dart';
import '../../../../core/widgets/connected_cloud_phone_widget.dart';
import '../../../../data/models/connection_mode_model.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../../data/services/engine/engine_selection_manager.dart';
import '../../../../data/services/network_connectivity_service.dart';
import '../../settings/view_models/settings_view_model.dart';

/// Screen 8: Connection Mode
/// Matches the official reference design with cloud + phone illustration,
/// "Connected!" or "Offline Mode" status, Mode Selection, Privacy Disclosure, and "Got it" button.
/// Fully responsive on phones, tablets, and varied aspect ratios.
class ConnectionModeScreen extends StatelessWidget {
  const ConnectionModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    NetworkConnectivityService? connectivity;
    EngineSelectionManager? engineMgr;
    SettingsViewModel? settingsVm;
    SettingsRepository? settingsRepo;
    try {
      connectivity = Provider.of<NetworkConnectivityService>(context);
    } catch (_) {}
    try {
      engineMgr = Provider.of<EngineSelectionManager>(context);
    } catch (_) {}
    try {
      settingsVm = Provider.of<SettingsViewModel>(context);
    } catch (_) {}
    try {
      settingsRepo = Provider.of<SettingsRepository>(context);
    } catch (_) {}

    final activeMode = engineMgr?.activeMode ??
        settingsVm?.connectionMode.type ??
        settingsRepo?.getConnectionMode().type ??
        ConnectionModeType.automatic;

    final bool isOnline = connectivity?.isValidatedInternet == true;
    final bool isQuotaExhausted = engineMgr?.isQuotaExhausted ?? false;

    String headline;
    String subtitle;

    if (activeMode == ConnectionModeType.cloudAi) {
      if (!isOnline) {
        headline = 'No Internet Connection';
        subtitle = 'Online Mode requires an active internet connection. Please connect to internet or switch to Offline Mode.';
      } else if (isQuotaExhausted) {
        headline = 'Online Quota Exhausted';
        subtitle = 'Daily free online translation limit reached (HTTP 429). Switch to Offline Mode to continue translating for free.';
      } else {
        headline = 'Online Mode Active';
        subtitle = 'Connected to external translation API. Speech recognition and TTS remain 100% on-device.';
      }
    } else if (activeMode == ConnectionModeType.onDevice) {
      headline = 'Offline Mode Active';
      subtitle = '100% on-device neural translation, speech recognition, and TTS. Zero data leaves your device.';
    } else {
      // Automatic
      if (isOnline && !isQuotaExhausted) {
        headline = 'Connected - Automatic';
        subtitle = 'Smart Adaptive: Using free online translation while connected. Automatically switches to local translation when offline.';
      } else if (isQuotaExhausted) {
        headline = 'On-Device - Automatic';
        subtitle = 'Daily online quota reached. Smart Adaptive has seamlessly switched to 100% free on-device neural translation.';
      } else {
        headline = 'Offline - Automatic';
        subtitle = 'Device is disconnected from the internet. Smart Adaptive is running 100% on-device neural translation.';
      }
    }

    final resolution = engineMgr?.currentResolution;
    final String activeModeTitle = resolution?.statusTitle ?? AppStrings.autoSwitchEnabled;
    final String activeModeSubtitle = resolution?.statusDescription ?? AppStrings.autoSwitchSubtitle;
    final bool missingPack = resolution != null && !resolution.isReady && resolution.missingRequirement != null;

    return Scaffold(
      backgroundColor: isDark ? AppDarkColors.background : Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          AppStrings.connectionMode,
          style: AppTypography.headlineMedium.copyWith(
            fontSize: 18,
            color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 24),
            color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
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
                          const SizedBox(height: 12),

                          // 1. Cloud + Smartphone Wi-Fi Illustration with Sparkles
                          ConnectedCloudPhoneWidget(
                            size: context.isCompact ? 140 : 170,
                          ),

                          const SizedBox(height: 18),

                          // 2. Headline
                          Text(
                            headline,
                            style: AppTypography.displayLarge.copyWith(
                              fontSize: context.isCompact ? 22 : 26,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Subtitle
                          Text(
                            subtitle,
                            style: AppTypography.bodyMedium.copyWith(
                              fontSize: context.isCompact ? 13 : 15,
                              color: isDark ? AppDarkColors.textSecondary : AppColors.textSecondary,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 20),

                          // 3. Operating Mode Selection Chips (Wrap prevents overflow on compact screens)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              _buildModeChip(
                                context: context,
                                label: 'Automatic',
                                isSelected: activeMode == ConnectionModeType.automatic,
                                isDark: isDark,
                                onTap: () {
                                  engineMgr?.setUserMode(ConnectionModeType.automatic);
                                  settingsVm?.setConnectionMode(ConnectionModeType.automatic);
                                  settingsRepo?.setConnectionMode(ConnectionModeType.automatic);
                                },
                              ),
                              _buildModeChip(
                                context: context,
                                label: 'Online',
                                isSelected: activeMode == ConnectionModeType.cloudAi,
                                isDark: isDark,
                                onTap: () {
                                  engineMgr?.setUserMode(ConnectionModeType.cloudAi);
                                  settingsVm?.setConnectionMode(ConnectionModeType.cloudAi);
                                  settingsRepo?.setConnectionMode(ConnectionModeType.cloudAi);
                                },
                              ),
                              _buildModeChip(
                                context: context,
                                label: 'Offline',
                                isSelected: activeMode == ConnectionModeType.onDevice,
                                isDark: isDark,
                                onTap: () {
                                  engineMgr?.setUserMode(ConnectionModeType.onDevice);
                                  settingsVm?.setConnectionMode(ConnectionModeType.onDevice);
                                  settingsRepo?.setConnectionMode(ConnectionModeType.onDevice);
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // 4. Engine Status Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? AppDarkColors.cardLightGreen : AppColors.cardLightGreen,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isDark ? AppDarkColors.statusGreenBorder : const Color(0xFFBBF7D0),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: isDark ? AppDarkColors.statusGreen : AppColors.statusGreen,
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
                                        activeModeTitle,
                                        style: AppTypography.titleMedium.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: isDark ? AppDarkColors.statusGreen : AppColors.textGreenDark,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        activeModeSubtitle,
                                        style: AppTypography.caption.copyWith(
                                          color: isDark
                                              ? AppDarkColors.statusGreen.withValues(alpha: 0.8)
                                              : AppColors.textGreenDark.withValues(alpha: 0.8),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 5. Missing Offline Pack Guidance
                          if (missingPack) ...[
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () => Navigator.pushNamed(context, AppRoutes.offlinePacks),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? AppDarkColors.surfaceSecondary : AppColors.cardLightBlue,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDark ? AppDarkColors.primary : AppColors.primary,
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.download_rounded, size: 20, color: AppColors.primary),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Download required packs in Offline Packs ->',
                                        style: AppTypography.caption.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),

                          // 6. Online Translation Privacy & Free Forever Disclosure
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? AppDarkColors.surfaceSecondary : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.shield_outlined,
                                      size: 18,
                                      color: isDark ? AppDarkColors.textSecondary : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Privacy Notice: In Online Mode, recognized speech text is sent to the MyMemory translation API. Audio recordings and microphone PCM data remain strictly on-device. The API provider receives standard network request metadata, including your IP address. The developer contact email is included in the request if configured. Submitted text segments may be retained by the provider according to their terms. Offline Mode does not transmit translation content externally.',
                                        style: AppTypography.caption.copyWith(
                                          fontSize: 11,
                                          color: isDark ? AppDarkColors.textSecondary : AppColors.textSecondary,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.volunteer_activism_rounded,
                                      size: 14,
                                      color: AppColors.statusGreen,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '100% Free Forever: No subscriptions, advertisements, or paid credits.',
                                        style: AppTypography.caption.copyWith(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? AppDarkColors.statusGreen : AppColors.textGreenDark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const Spacer(),
                          const SizedBox(height: 16),

                          // 7. "Got it" Solid Blue Pill Button
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? AppDarkColors.primary : AppColors.primary,
                                  foregroundColor: Colors.white,
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

  Widget _buildModeChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppDarkColors.primary : AppColors.primary)
              : (isDark ? AppDarkColors.surfaceSecondary : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (isDark ? AppDarkColors.primary : AppColors.primary)
                : (isDark ? AppDarkColors.border : AppColors.borderLight),
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? AppDarkColors.textPrimary : AppColors.textPrimary),
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
