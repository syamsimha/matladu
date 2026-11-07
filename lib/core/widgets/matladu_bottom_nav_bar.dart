import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

/// 4-tab bottom navigation bar as depicted on Screen 2:
/// [Home, Offline, History, Settings] with cobalt-blue active styling.
class MatladuBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const MatladuBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.borderLight, width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                label: 'Home',
                icon: Icons.home_rounded,
              ),
              _buildNavItem(
                index: 1,
                label: 'Offline',
                icon: Icons.download_for_offline_outlined,
              ),
              _buildNavItem(
                index: 2,
                label: 'History',
                icon: Icons.history_rounded,
              ),
              _buildNavItem(
                index: 3,
                label: 'Settings',
                icon: Icons.settings_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final bool isActive = currentIndex == index;
    final Color itemColor = isActive ? AppColors.primary : AppColors.textMuted;

    return InkWell(
      onTap: () => onTabSelected(index),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: itemColor,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: itemColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

