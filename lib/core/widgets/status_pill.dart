import 'package:flutter/material.dart';
import '../../data/models/connection_mode_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

/// Small status badge indicating the current operational mode
/// (Cloud AI / Local On-Device / P2P Hotspot).
class StatusPill extends StatelessWidget {
  final ConnectionModeType modeType;
  final VoidCallback? onTap;

  const StatusPill({
    super.key,
    required this.modeType,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    String label;
    IconData icon;

    switch (modeType) {
      case ConnectionModeType.cloudAi:
        badgeColor = AppColors.onlineBadge;
        label = 'Cloud AI';
        icon = Icons.cloud_done_rounded;
        break;
      case ConnectionModeType.onDevice:
        badgeColor = AppColors.secondary;
        label = 'On-Device (Offline)';
        icon = Icons.phone_android_rounded;
        break;
      case ConnectionModeType.peerToPeer:
        badgeColor = AppColors.purpleAccent;
        label = 'P2P Hotspot';
        icon = Icons.wifi_tethering_rounded;
        break;
    }

    return Material(
      color: badgeColor.withOpacity(0.12),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: badgeColor.withOpacity(0.3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, size: 14, color: badgeColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: badgeColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

