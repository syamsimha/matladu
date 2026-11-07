import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Custom illustration widget depicting a Cloud with Wi-Fi rays
/// connecting to a Smartphone with a green checkmark on screen,
/// surrounded by sparkles, exactly matching Screen 8 (Connection Mode).
class ConnectedCloudPhoneWidget extends StatelessWidget {
  final double size;

  const ConnectedCloudPhoneWidget({
    super.key,
    this.size = 180.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Sparkles ✨
          Positioned(
            top: size * 0.12,
            left: size * 0.10,
            child: Icon(Icons.auto_awesome, size: 20, color: AppColors.primaryLight.withOpacity(0.6)),
          ),
          Positioned(
            top: size * 0.22,
            right: size * 0.08,
            child: Icon(Icons.auto_awesome, size: 24, color: AppColors.primaryLight.withOpacity(0.7)),
          ),
          Positioned(
            bottom: size * 0.18,
            left: size * 0.14,
            child: Icon(Icons.auto_awesome, size: 16, color: AppColors.primaryLight.withOpacity(0.5)),
          ),

          // Main Cloud with Wi-Fi waves
          Positioned(
            top: size * 0.14,
            left: size * 0.12,
            child: Container(
              width: size * 0.60,
              height: size * 0.45,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(size * 0.22),
                border: Border.all(color: AppColors.primaryLight.withOpacity(0.4), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.wifi_rounded,
                    size: size * 0.28,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),

          // Smartphone overlayed on right
          Positioned(
            bottom: size * 0.08,
            right: size * 0.14,
            child: Container(
              width: size * 0.38,
              height: size * 0.64,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(4, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(5),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Container(
                    width: size * 0.18,
                    height: size * 0.18,
                    decoration: const BoxDecoration(
                      color: AppColors.statusGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

