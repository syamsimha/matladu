import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/responsive/responsive_layout.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../../data/repositories/tts_repository.dart';
import '../../../../data/services/engine/engine_selection_manager.dart';
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    SettingsViewModel? existingVm;
    try {
      existingVm = context.read<SettingsViewModel>();
    } catch (_) {}

    if (existingVm != null) {
      return ChangeNotifierProvider<SettingsViewModel>.value(
        value: existingVm,
        child: _buildScaffold(context, isDark),
      );
    }

    return ChangeNotifierProvider(
      create: (ctx) {
        TtsRepository? ttsRepo;
        try {
          ttsRepo = ctx.read<TtsRepository>();
        } catch (_) {}
        EngineSelectionManager? engineMgr;
        try {
          engineMgr = ctx.read<EngineSelectionManager>();
        } catch (_) {}
        return SettingsViewModel(
          settingsRepository: ctx.read<SettingsRepository>(),
          ttsRepository: ttsRepo,
          engineSelectionManager: engineMgr,
        );
      },
      child: _buildScaffold(context, isDark),
    );
  }

  Widget _buildScaffold(BuildContext context, bool isDark) {
    return Scaffold(
        backgroundColor: isDark ? AppDarkColors.background : AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            AppStrings.settingsTitle,
            style: AppTypography.headlineMedium.copyWith(
              fontSize: 18,
              color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
            ),
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
                    Material(
                      color: isDark ? AppDarkColors.cardLightGreen : AppColors.cardLightGreen,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.pushNamed(context, AppRoutes.connectionMode),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? AppDarkColors.statusGreenBorder : const Color(0xFFBBF7D0),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isDark ? AppDarkColors.cardShadow : AppColors.cardShadow,
                                blurRadius: 10,
                                offset: const Offset(0, 3),
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
                              color: isDark ? AppDarkColors.statusGreenBg : const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.wifi_rounded,
                              color: isDark ? AppDarkColors.statusGreen : AppColors.statusGreen,
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
                                    color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  vm.isOnlineActive
                                      ? AppStrings.onlineModeActive
                                      : 'Offline on-device mode',
                                  style: AppTypography.caption.copyWith(
                                    color: isDark ? AppDarkColors.statusGreen : AppColors.statusGreen,
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
                            activeThumbColor: Colors.white,
                            activeTrackColor: isDark ? AppDarkColors.statusGreen : AppColors.statusGreen,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: isDark ? AppDarkColors.border : AppColors.borderLight,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                    const SizedBox(height: 18),

                    // 2. Settings Menu Items Grouped Card
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppDarkColors.surface : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isDark ? AppDarkColors.border : AppColors.borderLight,
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? AppDarkColors.cardShadow : AppColors.cardShadow,
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Item 1: Offline Language Packs
                          _buildSettingsTile(
                            context: context,
                            icon: Icons.archive_outlined,
                            title: AppStrings.offlineLanguagePacks,
                            subtitle: AppStrings.manageDownloadedPacks,
                            onTap: () {
                              Navigator.pushNamed(context, AppRoutes.offlinePacks);
                            },
                          ),
                          Divider(
                            height: 1,
                            indent: 68,
                            color: isDark ? AppDarkColors.border : AppColors.borderLight,
                          ),

                          // Item 2: App Preferences
                          _buildSettingsTile(
                            context: context,
                            icon: Icons.tune_rounded,
                            title: AppStrings.appPreferences,
                            subtitle: AppStrings.themeVoiceSpeed,
                            onTap: () {
                              _showPreferencesDialog(context, vm, isDark);
                            },
                          ),
                          Divider(
                            height: 1,
                            indent: 68,
                            color: isDark ? AppDarkColors.border : AppColors.borderLight,
                          ),

                          // Item 3: Speech Settings
                          _buildSettingsTile(
                            context: context,
                            icon: Icons.mic_none_rounded,
                            title: AppStrings.speechSettings,
                            subtitle: AppStrings.recognitionAndTts,
                            onTap: () {
                              _showSpeechSettingsDialog(context, vm, isDark);
                            },
                          ),
                          Divider(
                            height: 1,
                            indent: 68,
                            color: isDark ? AppDarkColors.border : AppColors.borderLight,
                          ),

                          // Item 4: Cache & Storage
                          _buildSettingsTile(
                            context: context,
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
                          Divider(
                            height: 1,
                            indent: 68,
                            color: isDark ? AppDarkColors.border : AppColors.borderLight,
                          ),

                          // Item 5: About Matladu
                          _buildSettingsTile(
                            context: context,
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
                        _showResetConfirmation(context, vm, isDark);
                      },
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isDark ? AppDarkColors.cardLightRed : AppColors.cardLightRed,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.refresh_rounded,
                              color: isDark ? AppDarkColors.errorRed : AppColors.errorRed,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppStrings.resetSettings,
                              style: AppTypography.button.copyWith(
                                color: isDark ? AppDarkColors.errorRed : AppColors.errorRed,
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
      );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

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
                color: isDark ? AppDarkColors.surfaceSecondary : AppColors.cardLightBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isDark ? AppDarkColors.primary : AppColors.primary,
                size: 22,
              ),
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
                      color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(
                      color: isDark ? AppDarkColors.textMuted : AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? AppDarkColors.textMuted : AppColors.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  void _showPreferencesDialog(BuildContext context, SettingsViewModel vm, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final voices = vm.availableVoices;
            final selectedVoice = vm.selectedVoiceName;
            final speed = vm.settings.speechSpeed;

            return AlertDialog(
              backgroundColor: isDark ? AppDarkColors.surface : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isDark ? AppDarkColors.border : AppColors.borderLight,
                ),
              ),
              title: Text(
                AppStrings.appPreferences,
                style: AppTypography.headlineMedium.copyWith(
                  color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Voice Selection
                    Text(
                      'Voice Selection:',
                      style: TextStyle(
                        color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? AppDarkColors.surfaceSecondary : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppDarkColors.border : AppColors.borderLight,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          isExpanded: true,
                          value: (selectedVoice != null && voices.any((v) => v.name == selectedVoice))
                              ? selectedVoice
                              : null,
                          hint: Text(
                            'System Default (Offline)',
                            style: TextStyle(
                              color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                          dropdownColor: isDark ? AppDarkColors.surface : Colors.white,
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                'System Default (Offline)',
                                style: TextStyle(
                                  color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ...voices.map((voice) {
                              final isOffline = voice.isOfflineAvailable;
                              final badge = isOffline ? 'Offline' : 'Network Req';
                              return DropdownMenuItem<String?>(
                                value: voice.name,
                                child: Text(
                                  '${voice.displayName.split(' - ').first} - $badge',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isOffline
                                        ? (isDark ? AppDarkColors.textPrimary : AppColors.textPrimary)
                                        : (isDark ? AppDarkColors.textMuted : AppColors.textMuted),
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setDialogState(() {
                              vm.updateSelectedVoice(val);
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Voice Preview Button
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.volume_up_rounded, size: 16),
                        label: const Text('Preview Voice', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? AppDarkColors.primary : AppColors.primary,
                          side: BorderSide(
                            color: isDark ? AppDarkColors.primary : AppColors.primary,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () {
                          vm.previewVoice(
                            voiceName: selectedVoice,
                            sampleText: 'Matladu: Listen. Convert. Translate.',
                          );
                        },
                      ),
                    ),

                    const Divider(height: 24),

                    // 2. Speech Output Speed
                    Text(
                      'Speech Output Speed: ${speed.toStringAsFixed(1)}x',
                      style: TextStyle(
                        color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Slider(
                      value: speed,
                      min: 0.5,
                      max: 1.5,
                      divisions: 4,
                      label: '${speed}x',
                      activeColor: isDark ? AppDarkColors.primary : AppColors.primary,
                      onChanged: (val) {
                        setDialogState(() {
                          vm.updateSpeechSpeed(val);
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Done',
                    style: TextStyle(
                      color: isDark ? AppDarkColors.primary : AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSpeechSettingsDialog(BuildContext context, SettingsViewModel vm, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? AppDarkColors.surface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? AppDarkColors.border : AppColors.borderLight,
            ),
          ),
          title: Text(
            AppStrings.speechSettings,
            style: AppTypography.headlineMedium.copyWith(
              color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: Text(
                    'Auto-play Translations',
                    style: TextStyle(
                      color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Automatically speak translation when completed',
                    style: TextStyle(
                      color: isDark ? AppDarkColors.textMuted : AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  value: vm.settings.autoPlayAudio,
                  activeThumbColor: isDark ? AppDarkColors.primary : AppColors.primary,
                  onChanged: (val) => vm.updateAutoPlayAudio(val),
                ),
                SwitchListTile(
                  title: Text(
                    'Auto-detect Language',
                    style: TextStyle(
                      color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                    ),
                  ),
                  value: vm.settings.autoDetectLanguage,
                  activeThumbColor: isDark ? AppDarkColors.primary : AppColors.primary,
                  onChanged: (val) => vm.updateAutoDetect(val),
                ),
                SwitchListTile(
                  title: Text(
                    'Cloud Speech Recognition',
                    style: TextStyle(
                      color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Allow audio processing via Google Speech in Online Mode. Offline Mode always runs on-device Whisper.',
                    style: TextStyle(
                      color: isDark ? AppDarkColors.textMuted : AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  value: vm.cloudSpeechConsentGranted,
                  activeThumbColor: isDark ? AppDarkColors.primary : AppColors.primary,
                  onChanged: (val) => vm.updateCloudSpeechConsent(val),
                ),
                SwitchListTile(
                  title: Text(
                    'Noise Suppression',
                    style: TextStyle(
                      color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                    ),
                  ),
                  value: vm.settings.noiseSuppression,
                  activeThumbColor: isDark ? AppDarkColors.primary : AppColors.primary,
                  onChanged: (val) => vm.updateNoiseSuppression(val),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.settings_voice_rounded),
                  title: Text(
                    'System TTS Settings',
                    style: TextStyle(
                      color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    'Manage offline voice data',
                    style: TextStyle(
                      color: isDark ? AppDarkColors.textMuted : AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () async {
                    try {
                      const channel = MethodChannel('com.matladu.ai/tts_settings');
                      await channel.invokeMethod('openTtsSettings');
                    } catch (_) {}
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Done',
                style: TextStyle(
                  color: isDark ? AppDarkColors.primary : AppColors.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showResetConfirmation(BuildContext context, SettingsViewModel vm, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? AppDarkColors.surface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? AppDarkColors.border : AppColors.borderLight,
            ),
          ),
          title: Text(
            'Reset All Settings?',
            style: TextStyle(
              color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
            ),
          ),
          content: Text(
            'This will restore all default preferences and clear cached offline data.',
            style: TextStyle(
              color: isDark ? AppDarkColors.textSecondary : AppColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? AppDarkColors.textMuted : AppColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final nav = Navigator.of(ctx);
                await vm.resetSettings();
                nav.pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Settings reset to default'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppDarkColors.errorRed : AppColors.errorRed,
              ),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }
}
