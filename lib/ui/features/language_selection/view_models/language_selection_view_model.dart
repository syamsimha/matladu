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
    _selectedLanguage = initialLanguage ?? LanguageModel.defaultLanguages.first;
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
    _selectedLanguage = lang;
    notifyListeners();
  }

  List<LanguageModel> get filteredLanguages {
    return LanguageModel.defaultLanguages.where((l) {
      final matchesSearch = l.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          l.nativeName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' || l.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }
}

