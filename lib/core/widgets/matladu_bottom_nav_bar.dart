import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../responsive/responsive_layout.dart';

/// 4-tab bottom navigation bar as depicted on Screen 2:
/// [Home, Offline, History, Settings] with cobalt-blue active styling.
/// Responsive and centered on tablets with comfortable minimum touch targets.
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppDarkColors.surface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppDarkColors.border : AppColors.borderLight,
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x33000000) : const Color(0x06000000),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ResponsiveContentWrapper(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  context: context,
                  index: 0,
                  label: 'Home',
                  icon: Icons.home_rounded,
                ),
                _buildNavItem(
                  context: context,
                  index: 1,
                  label: 'Offline',
                  icon: Icons.download_for_offline_outlined,
                ),
                _buildNavItem(
                  context: context,
                  index: 2,
                  label: 'History',
                  icon: Icons.history_rounded,
                ),
                _buildNavItem(
                  context: context,
                  index: 3,
                  label: 'Settings',
                  icon: Icons.settings_outlined,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required String label,
    required IconData icon,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isActive = currentIndex == index;
    final Color itemColor = isActive
        ? (isDark ? AppDarkColors.primary : AppColors.primary)
        : (isDark ? AppDarkColors.textMuted : AppColors.textMuted);

    return Expanded(
      child: InkWell(
        onTap: () => onTabSelected(index),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48), // Accessible touch target
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 24,
                color: itemColor,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: itemColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
