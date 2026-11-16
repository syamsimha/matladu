import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/responsive/responsive_layout.dart';
import '../../../../core/widgets/circular_flag_avatar.dart';
import '../../../../data/models/offline_pack_model.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../../data/repositories/translation_repository.dart';
import '../../../../data/services/asr/model_manager_service.dart';
import '../../../../data/services/network_connectivity_service.dart';
import '../view_models/offline_packs_view_model.dart';

/// Screen 5: Offline Packs
/// Displays genuine download & installation tracking for Whisper ASR and Neural MT packs:
/// - Language name & model type
/// - Actual download size and installed size
/// - Real byte-based progress percentage (downloadedBytes / totalBytes)
/// - Installation & verification states
/// - Download, Cancel, Retry, and Delete actions.
class OfflinePacksScreen extends StatelessWidget {
  const OfflinePacksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return ChangeNotifierProvider(
      create: (ctx) {
        ModelManagerService? modelManager;
        try {
          modelManager = ctx.read<ModelManagerService>();
        } catch (_) {}
        TranslationRepository? translationRepo;
        try {
          translationRepo = ctx.read<TranslationRepository>();
        } catch (_) {}
        NetworkConnectivityService? connectivity;
        try {
          connectivity = ctx.read<NetworkConnectivityService>();
        } catch (_) {}
        return OfflinePacksViewModel(
          settingsRepository: ctx.read<SettingsRepository>(),
          modelManagerService: modelManager,
          translationRepository: translationRepo,
          networkConnectivityService: connectivity,
        );
      },
      child: Scaffold(
        backgroundColor: isDark ? AppDarkColors.background : AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            AppStrings.offlinePacksTitle,
            style: AppTypography.headlineMedium.copyWith(
              fontSize: 18,
              color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
            ),
          ),
          centerTitle: true,
          actions: [
            Consumer<OfflinePacksViewModel>(
              builder: (context, vm, _) => IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 22),
                tooltip: 'Verify Disk Packs',
                color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                onPressed: () => vm.verifyInstalledPacks(),
              ),
            ),
          ],
        ),
        body: Consumer<OfflinePacksViewModel>(
          builder: (context, vm, _) {
            final whisper = vm.whisperPack;

            return SafeArea(
              child: ResponsiveContentWrapper(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  children: [
                    // 1. Top Notice Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppDarkColors.cardLightBlue : AppColors.cardLightBlue,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? AppDarkColors.border : const Color(0xFFBFDBFE),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            color: AppColors.statusYellow,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.noDownloadRequired,
                                  style: AppTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  AppStrings.useOnlineInstantly,
                                  style: AppTypography.caption.copyWith(
                                    color: isDark ? AppDarkColors.primary : AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 2. Section: Speech Recognition (ASR) Model
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Speech Recognition (ASR) Model',
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? AppDarkColors.primary.withValues(alpha: 0.15) : AppColors.cardLightBlue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              whisper.modelType,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppDarkColors.primary : AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Whisper Speech Model Card
                    _buildPackCard(
                      context: context,
                      vm: vm,
                      pack: whisper,
                      isDark: isDark,
                      isWhisper: true,
                    ),

                    const SizedBox(height: 12),

                    // 3. Section: Available Packs
                    if (vm.availablePacks.isNotEmpty) ...[
                      Text(
                        'Available Translation Packs',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...vm.availablePacks.map((pack) => _buildPackCard(
                            context: context,
                            vm: vm,
                            pack: pack,
                            isDark: isDark,
                            isWhisper: false,
                          )),
                      const SizedBox(height: 16),
                    ],

                    // 4. Section: Downloaded Packs
                    Text(
                      AppStrings.downloadedPacks,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (vm.downloadedPacks.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? AppDarkColors.surface : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppDarkColors.border : AppColors.borderLight,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'No translation packs installed on device.',
                            style: TextStyle(
                              color: isDark ? AppDarkColors.textMuted : AppColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      ...vm.downloadedPacks.map((pack) => _buildPackCard(
                            context: context,
                            vm: vm,
                            pack: pack,
                            isDark: isDark,
                            isWhisper: false,
                          )),
                    ],

                    const SizedBox(height: 20),

                    // 5. Bottom Reassurance Notice
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppDarkColors.cardLightBlue : AppColors.cardLightBlue,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? AppDarkColors.border : const Color(0xFFBFDBFE),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            color: isDark ? AppDarkColors.primary : AppColors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              AppStrings.offlineNoticeBottom,
                              style: AppTypography.caption.copyWith(
                                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPackCard({
    required BuildContext context,
    required OfflinePacksViewModel vm,
    required OfflinePackModel pack,
    required bool isDark,
    required bool isWhisper,
  }) {
    final bool isReady = pack.isReady;
    final bool isDownloading = pack.isDownloading;
    final bool isVerifying = pack.installState == PackInstallState.verifying;
    final bool isPaused = pack.installState == PackInstallState.paused;
    final bool isFailed = pack.isFailed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppDarkColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isReady
              ? (isDark ? AppDarkColors.statusGreenBorder : const Color(0xFFBBF7D0))
              : (isDark ? AppDarkColors.border : AppColors.borderLight),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? AppDarkColors.cardShadow : AppColors.cardShadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isWhisper) ...[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isReady
                        ? (isDark ? AppDarkColors.statusGreen : AppColors.statusGreen)
                        : (isDark ? AppDarkColors.surfaceVariant : AppColors.cardLightBlue),
                  ),
                  child: Icon(
                    isReady ? Icons.check_rounded : Icons.mic_none_rounded,
                    color: isReady ? Colors.white : (isDark ? AppDarkColors.primary : AppColors.primary),
                    size: 20,
                  ),
                ),
              ] else ...[
                if (isReady)
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? AppDarkColors.statusGreen : AppColors.statusGreen,
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                  )
                else
                  CircularFlagAvatar(languageCode: pack.languageCode, size: 32),
              ],
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack.languageName,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${pack.stateBadgeLabel} - ${pack.sizeInMB} MB',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isReady ? FontWeight.w700 : FontWeight.w500,
                        color: isReady
                            ? (isDark ? AppDarkColors.statusGreen : AppColors.statusGreen)
                            : (isFailed
                                ? AppColors.errorRed
                                : (isDark ? AppDarkColors.textMuted : AppColors.textMuted)),
                      ),
                    ),
                  ],
                ),
              ),

              // Action buttons
              if (isReady) ...[
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: isDark ? AppDarkColors.errorRed : AppColors.errorRed,
                    size: 22,
                  ),
                  tooltip: 'Delete Pack',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: isDark ? AppDarkColors.surface : Colors.white,
                        title: Text('Delete ${pack.languageName}?'),
                        content: const Text(
                          'Deleting this pack will require a re-download before offline translation can run.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.errorRed,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              if (isWhisper) {
                                vm.deleteSpeechModel();
                              } else {
                                vm.deletePack(pack.id);
                              }
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ] else if (pack.installState == PackInstallState.deleting) ...[
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ] else if (isDownloading || isVerifying) ...[
                SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: () {
                      if (isWhisper) {
                        vm.cancelSpeechModelDownload();
                      } else {
                        vm.cancelDownload(pack.id);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ] else if (isPaused || isFailed) ...[
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () {
                      if (isWhisper) {
                        vm.downloadSpeechModel();
                      } else {
                        vm.downloadPack(pack);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: const Text('Retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
              ] else ...[
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () {
                      if (isWhisper) {
                        vm.downloadSpeechModel();
                      } else {
                        vm.downloadPack(pack);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppDarkColors.primary : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: Text(
                      AppStrings.download,
                      style: AppTypography.button.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),

          // Real-time progress bar & byte progress text
          if (isDownloading || isVerifying) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (isVerifying || pack.downloadProgress <= 0.0) ? null : pack.downloadProgress,
                minHeight: 6,
                backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? AppDarkColors.primary : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    isVerifying
                        ? 'Verifying model checksums...'
                        : pack.byteProgressText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppDarkColors.textMuted : AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isVerifying
                      ? 'Verifying'
                      : (pack.downloadProgress > 0.0 ? '${pack.progressPercent}%' : 'In progress'),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppDarkColors.primary : AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],

          if (pack.errorMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              pack.errorMessage!,
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }
}
