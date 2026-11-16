import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/responsive/responsive_layout.dart';
import '../../../../core/widgets/circular_flag_avatar.dart';
import '../../../../data/models/language_model.dart';
import '../view_models/language_selection_view_model.dart';

/// Screen 4: Select Language
/// Matches the official reference design with search bar, filter chips
/// (All, Popular, Indian, Others), circular flag avatars, radio selections,
/// and full-width "Done (1 Selected)" button.
/// Responsive across phones, tablets, and varied aspect ratios.
class LanguageSelectionScreen extends StatelessWidget {
  final bool isSelectingSource;
  final LanguageModel? currentLanguage;

  const LanguageSelectionScreen({
    super.key,
    this.isSelectingSource = true,
    this.currentLanguage,
  });

  static bool _isOfflineSupported(String code) {
    const offlineCodes = {'en', 'de', 'te', 'hi', 'bn', 'mr', 'ta', 'ur', 'gu', 'kn'};
    return offlineCodes.contains(code.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return ChangeNotifierProvider(
      create: (_) => LanguageSelectionViewModel(
        isSelectingSource: isSelectingSource,
        initialLanguage: currentLanguage ??
            (isSelectingSource
                ? LanguageModel.autoDetect
                : (LanguageModel.fromCode('te') ?? LanguageModel.defaultLanguages[0])),
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppDarkColors.background : AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            AppStrings.selectLanguageTitle,
            style: AppTypography.headlineMedium.copyWith(
              fontSize: 18,
              color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
            ),
          ),
          centerTitle: true,
        ),
        body: Consumer<LanguageSelectionViewModel>(
          builder: (context, vm, _) {
            final languages = vm.filteredLanguages;

            return SafeArea(
              child: ResponsiveContentWrapper(
                child: Column(
                  children: [
                    // 1. Search Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: TextField(
                        onChanged: vm.setSearchQuery,
                        style: TextStyle(
                          color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: AppStrings.searchLanguagesHint,
                          hintStyle: TextStyle(
                            color: isDark ? AppDarkColors.textMuted : AppColors.textMuted,
                          ),
                          fillColor: isDark ? AppDarkColors.surface : Colors.white,
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: isDark ? AppDarkColors.textMuted : AppColors.textMuted,
                            size: 22,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                              color: isDark ? AppDarkColors.border : AppColors.borderLight,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                              color: isDark ? AppDarkColors.border : AppColors.borderLight,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 2. Filter Category Chips (All, Popular, Indian, Others)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip(
                              context: context,
                              label: AppStrings.filterAll,
                              isSelected: vm.selectedCategory == 'All',
                              onTap: () => vm.setCategory('All'),
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              context: context,
                              label: AppStrings.filterPopular,
                              isSelected: vm.selectedCategory == 'Popular',
                              onTap: () => vm.setCategory('Popular'),
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              context: context,
                              label: AppStrings.filterIndian,
                              isSelected: vm.selectedCategory == 'Indian',
                              onTap: () => vm.setCategory('Indian'),
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              context: context,
                              label: AppStrings.filterOthers,
                              isSelected: vm.selectedCategory == 'Others',
                              onTap: () => vm.setCategory('Others'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 3. Language List
                    Expanded(
                      child: languages.isEmpty
                          ? Center(
                              child: Text(
                                'No matching languages found.',
                                style: TextStyle(
                                  color: isDark ? AppDarkColors.textMuted : AppColors.textMuted,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              itemCount: languages.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 16,
                                color: isDark ? AppDarkColors.border : AppColors.borderLight,
                              ),
                              itemBuilder: (context, index) {
                                final item = languages[index];
                                final bool isSelected =
                                    vm.selectedLanguage.code == item.code;

                                return InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => vm.selectLanguage(item),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 6,
                                    ),
                                    child: Row(
                                      children: [
                                        // Circular Flag Icon
                                        CircularFlagAvatar(
                                          languageCode: item.code,
                                          size: 32,
                                        ),
                                        const SizedBox(width: 14),

                                        // Language Names
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      item.name,
                                                      style: AppTypography.titleMedium
                                                          .copyWith(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w700,
                                                        color: isDark
                                                            ? AppDarkColors.textPrimary
                                                            : AppColors.textPrimary,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  if (item.code != 'auto')
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: _isOfflineSupported(item.code)
                                                            ? (isDark
                                                                ? const Color(0xFF064E3B)
                                                                : const Color(0xFFD1FAE5))
                                                            : (isDark
                                                                ? const Color(0xFF1E293B)
                                                                : const Color(0xFFF1F5F9)),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        _isOfflineSupported(item.code)
                                                            ? 'Offline Ready'
                                                            : 'Online',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w600,
                                                          color: _isOfflineSupported(item.code)
                                                              ? (isDark
                                                                  ? const Color(0xFF34D399)
                                                                  : const Color(0xFF047857))
                                                              : (isDark
                                                                  ? const Color(0xFF94A3B8)
                                                                  : const Color(0xFF64748B)),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '(${item.nativeName})',
                                                style: AppTypography.caption
                                                    .copyWith(
                                                  fontSize: 12,
                                                  color: isDark
                                                      ? AppDarkColors.textMuted
                                                      : AppColors.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Radio Selection Checkmark
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isSelected
                                                ? (isDark
                                                    ? AppDarkColors.primary
                                                    : AppColors.primary)
                                                : (isDark
                                                    ? AppDarkColors.surfaceSecondary
                                                    : Colors.white),
                                            border: Border.all(
                                              color: isSelected
                                                  ? (isDark
                                                      ? AppDarkColors.primary
                                                      : AppColors.primary)
                                                  : (isDark
                                                      ? AppDarkColors.border
                                                      : AppColors.borderLight),
                                              width: isSelected ? 0 : 2,
                                            ),
                                          ),
                                          child: isSelected
                                              ? const Icon(
                                                  Icons.check_rounded,
                                                  color: Colors.white,
                                                  size: 16,
                                                )
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),

                    // 4. Sticky Bottom Action Button: Done (1 Selected)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context, vm.selectedLanguage);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? AppDarkColors.primary
                                : AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                          child: Text(
                            AppStrings.doneOneSelected,
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        constraints: const BoxConstraints(minHeight: 38), // Accessible touch target
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppDarkColors.primary : AppColors.primary)
              : (isDark ? AppDarkColors.surfaceSecondary : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (isDark ? AppDarkColors.primary : AppColors.primary)
                : (isDark ? AppDarkColors.border : AppColors.borderLight),
            width: 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isDark ? AppDarkColors.primary : AppColors.primary)
                        .withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: isSelected
                  ? Colors.white
                  : (isDark ? AppDarkColors.textSecondary : AppColors.textSecondary),
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
