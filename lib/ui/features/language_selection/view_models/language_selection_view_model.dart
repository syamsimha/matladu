import 'package:flutter/material.dart';
import '../../../../data/models/language_model.dart';

/// ViewModel managing state for the Select Language Screen (Screen 4).
class LanguageSelectionViewModel extends ChangeNotifier {
  final bool isSelectingSource;
  String _searchQuery = '';
  String _selectedCategory = 'All'; // 'All', 'Popular', 'Indian', 'Others'
  late LanguageModel _selectedLanguage;

  LanguageSelectionViewModel({
    required this.isSelectingSource,
    LanguageModel? initialLanguage,
  }) {
    _selectedLanguage = initialLanguage ??
        (isSelectingSource
            ? LanguageModel.autoDetect
            : (LanguageModel.fromCode('te') ?? LanguageModel.defaultLanguages.first));
  }

  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  LanguageModel get selectedLanguage => _selectedLanguage;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void selectLanguage(LanguageModel lang) {
    // Auto Detect is strictly permitted ONLY for source language
    if (!isSelectingSource && lang.code == 'auto') return;
    _selectedLanguage = lang;
    notifyListeners();
  }

  List<LanguageModel> get filteredLanguages {
    final list = LanguageModel.defaultLanguages.where((l) {
      final matchesSearch = l.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          l.nativeName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' || l.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    // Auto Detect is available ONLY for the source language, NEVER the target language
    if (isSelectingSource) {
      final matchesAutoSearch = _searchQuery.isEmpty ||
          'auto detect'.contains(_searchQuery.toLowerCase()) ||
          'auto'.contains(_searchQuery.toLowerCase());
      final matchesAutoCat = _selectedCategory == 'All' || _selectedCategory == 'Popular';
      if (matchesAutoSearch && matchesAutoCat) {
        list.insert(0, LanguageModel.autoDetect);
      }
    }

    return list;
  }
}

