import 'package:flutter/material.dart';
import '../../data/models/language_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

/// Language selection bar with Source & Target pills and a central Swap button.
class LanguageSelectorBar extends StatelessWidget {
  final LanguageModel sourceLang;
  final LanguageModel targetLang;
  final VoidCallback onSelectSource;
  final VoidCallback onSelectTarget;
  final VoidCallback onSwap;

  const LanguageSelectorBar({
    super.key,
    required this.sourceLang,
    required this.targetLang,
    required this.onSelectSource,
    required this.onSelectTarget,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Source Language Pill
          Expanded(
            child: _LanguagePill(
              language: sourceLang,
              label: 'From',
              onTap: onSelectSource,
            ),
          ),

          // Central Swap Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Material(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onSwap,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: const Icon(
                    Icons.swap_horiz_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),

          // Target Language Pill
          Expanded(
            child: _LanguagePill(
              language: targetLang,
              label: 'To',
              onTap: onSelectTarget,
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguagePill extends StatelessWidget {
  final LanguageModel language;
  final String label;
  final VoidCallback onTap;

  const _LanguagePill({
    required this.language,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: AppTypography.caption.copyWith(
                fontSize: 10,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  language.flagEmoji,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    language.name,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

