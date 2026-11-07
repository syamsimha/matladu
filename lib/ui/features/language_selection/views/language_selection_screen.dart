import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/circular_flag_avatar.dart';
import '../../../../data/models/language_model.dart';
import '../view_models/language_selection_view_model.dart';

/// Screen 4: Select Language
/// Matches the official reference design with search bar, filter chips
/// (All, Popular, Indian, Others), circular flag avatars, radio selections,
/// and full-width "Done (1 Selected)" button.
class LanguageSelectionScreen extends StatelessWidget {
  final bool isSelectingSource;

  const LanguageSelectionScreen({
    super.key,
    this.isSelectingSource = true,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LanguageSelectionViewModel(
        isSelectingSource: isSelectingSource,
        initialLanguage: isSelectingSource
            ? LanguageModel.defaultLanguages.first // English
            : LanguageModel.defaultLanguages[1], // Telugu
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            AppStrings.selectLanguageTitle,
            style: AppTypography.headlineMedium.copyWith(fontSize: 18),
          ),
          centerTitle: true,
        ),
        body: Consumer<LanguageSelectionViewModel>(
          builder: (context, vm, _) {
            final languages = vm.filteredLanguages;

            return SafeArea(
              child: Column(
                children: [
                  // 1. Search Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: TextField(
                      onChanged: vm.setSearchQuery,
                      decoration: InputDecoration(
                        hintText: AppStrings.searchLanguagesHint,
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.textMuted,
                          size: 22,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
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
                            label: AppStrings.filterAll,
                            isSelected: vm.selectedCategory == 'All',
                            onTap: () => vm.setCategory('All'),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: AppStrings.filterPopular,
                            isSelected: vm.selectedCategory == 'Popular',
                            onTap: () => vm.setCategory('Popular'),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: AppStrings.filterIndian,
                            isSelected: vm.selectedCategory == 'Indian',
                            onTap: () => vm.setCategory('Indian'),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
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
                        ? const Center(
                            child: Text(
                              'No matching languages found.',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            itemCount: languages.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 16),
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
                                            Text(
                                              item.name,
                                              style: AppTypography.titleMedium
                                                  .copyWith(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '(${item.nativeName})',
                                              style: AppTypography.caption
                                                  .copyWith(
                                                fontSize: 12,
                                                color: AppColors.textMuted,
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
                                              ? AppColors.primary
                                              : Colors.white,
                                          border: Border.all(
                                            color: isSelected
                                                ? AppColors.primary
                                                : AppColors.borderLight,
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
                          backgroundColor: AppColors.primary,
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderLight,
            width: 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

