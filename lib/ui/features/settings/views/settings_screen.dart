import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/responsive/responsive_layout.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../view_models/settings_view_model.dart';

/// Screen 6: Settings
/// Reproduces the official reference design with top green connection mode card
/// with switch, grouped menu items with rounded icons and chevrons,
/// and light-red "Reset Settings" button.
/// Fully responsive on Android, iOS, tablets, and varied aspect ratios.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => SettingsViewModel(
        settingsRepository: ctx.read<SettingsRepository>(),
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            AppStrings.settingsTitle,
            style: AppTypography.headlineMedium.copyWith(fontSize: 18),
          ),
          centerTitle: true,
        ),
        body: Consumer<SettingsViewModel>(
          builder: (context, vm, _) {
            return SafeArea(
              child: ResponsiveContentWrapper(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  children: [
                    // 1. Top Connection Mode Card with Green Switch Toggle
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardLightGreen,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFBBF7D0),
                          width: 1.0,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.cardShadow,
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Green Wi-Fi Icon
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.wifi_rounded,
                              color: AppColors.statusGreen,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Title & Subtitle
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.connectionMode,
                                  style: AppTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  vm.isOnlineActive
                                      ? AppStrings.onlineModeActive
                                      : 'Offline on-device mode',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.statusGreen,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Green Active Switch Toggle
                          Switch(
                            value: vm.isOnlineActive,
                            onChanged: vm.toggleOnlineMode,
                            activeColor: Colors.white,
                            activeTrackColor: AppColors.statusGreen,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: AppColors.borderLight,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 2. Settings Menu Items Grouped Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: AppColors.borderLight,
                          width: 1.0,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.cardShadow,
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Item 1: Offline Language Packs
                          _buildSettingsTile(
                            icon: Icons.archive_outlined,
                            title: AppStrings.offlineLanguagePacks,
                            subtitle: AppStrings.manageDownloadedPacks,
                            onTap: () {
                              Navigator.pushNamed(context, AppRoutes.offlinePacks);
                            },
                          ),
                          const Divider(height: 1, indent: 68),

                          // Item 2: App Preferences
                          _buildSettingsTile(
                            icon: Icons.tune_rounded,
                            title: AppStrings.appPreferences,
                            subtitle: AppStrings.themeVoiceSpeed,
                            onTap: () {
                              _showPreferencesDialog(context, vm);
                            },
                          ),
                          const Divider(height: 1, indent: 68),

                          // Item 3: Speech Settings
                          _buildSettingsTile(
                            icon: Icons.mic_none_rounded,
                            title: AppStrings.speechSettings,
                            subtitle: AppStrings.recognitionAndTts,
                            onTap: () {
                              _showSpeechSettingsDialog(context, vm);
                            },
                          ),
                          const Divider(height: 1, indent: 68),

                          // Item 4: Cache & Storage
                          _buildSettingsTile(
                            icon: Icons.inventory_2_outlined,
                            title: AppStrings.cacheAndStorage,
                            subtitle: vm.cacheSizeMB > 0
                                ? 'Clear cache (${vm.cacheSizeMB} MB)'
                                : 'Cache cleared (0.0 MB)',
                            onTap: () {
                              vm.clearCache();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Cache cleared successfully'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1, indent: 68),

                          // Item 5: About Matladu AI
                          _buildSettingsTile(
                            icon: Icons.info_outline_rounded,
                            title: AppStrings.aboutMatladuAi,
                            subtitle: AppStrings.version,
                            onTap: () {
                              Navigator.pushNamed(context, AppRoutes.about);
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // 3. Reset Settings Button (Light Red Background)
                    InkWell(
                      borderRadius: BorderRadius.circular(26),
                      onTap: () {
                        _showResetConfirmation(context, vm);
                      },
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.cardLightRed,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: const Color(0xFFFECACA),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.refresh_rounded,
                              color: AppColors.errorRed,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppStrings.resetSettings,
                              style: AppTypography.button.copyWith(
                                color: AppColors.errorRed,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.cardLightBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  void _showPreferencesDialog(BuildContext context, SettingsViewModel vm) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(AppStrings.appPreferences, style: AppTypography.headlineMedium),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Speech Output Speed:'),
              Slider(
                value: vm.settings.speechSpeed,
                min: 0.5,
                max: 1.5,
                divisions: 4,
                label: '${vm.settings.speechSpeed}x',
                activeColor: AppColors.primary,
                onChanged: (val) => vm.updateSpeechSpeed(val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  void _showSpeechSettingsDialog(BuildContext context, SettingsViewModel vm) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(AppStrings.speechSettings, style: AppTypography.headlineMedium),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Auto-detect Language'),
                value: vm.settings.autoDetectLanguage,
                activeColor: AppColors.primary,
                onChanged: (val) => vm.updateAutoDetect(val),
              ),
              SwitchListTile(
                title: const Text('Noise Suppression'),
                value: vm.settings.noiseSuppression,
                activeColor: AppColors.primary,
                onChanged: (val) => vm.updateNoiseSuppression(val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  void _showResetConfirmation(BuildContext context, SettingsViewModel vm) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Reset All Settings?'),
          content: const Text(
            'This will restore all default preferences and clear cached offline data.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await vm.resetSettings();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Settings reset to default'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
              ),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }
}
