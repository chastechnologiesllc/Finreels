import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// Tracks which of the 60 "Business of Your Skill/Business/Profession"
/// categories the person has told FinReels they do — their trade, their
/// side hustle, their profession. This is what turns the app from a
/// generic content feed into one that answers *their* specific pain point
/// instead of everyone's in general (see FeedProvider and
/// CategoryPlaybookData for how the selection is actually used).
///
/// Deliberately a *set*, not a single value — plenty of people are, e.g.,
/// a nurse by profession who also does makeup artistry on the side. Every
/// selected category gets equal priority; there's no forced "primary".
///
/// Singleton + ChangeNotifier, matching AdService/IapService so it can be
/// registered in main.dart's MultiProvider the same way.
class UserProfileService extends ChangeNotifier {
  UserProfileService._();
  static final UserProfileService instance = UserProfileService._();

  Set<String> _selectedCategoryIds = {};
  bool _loaded = false;
  bool _onboardingComplete = false;

  /// True once the persisted selection has been read from disk. Screens
  /// that render differently for "no selection yet" vs. "genuinely chose
  /// nothing" can check this rather than treating empty as unknown.
  bool get isLoaded => _loaded;

  /// Separate from [hasSelection] on purpose: someone can deliberately
  /// skip picking a category during onboarding, and that must not make
  /// onboarding reappear every time they open the app.
  bool get onboardingComplete => _onboardingComplete;

  /// All categories the person has selected. Returns an unmodifiable view.
  Set<String> get selectedCategoryIds => Set.unmodifiable(_selectedCategoryIds);

  bool get hasSelection => _selectedCategoryIds.isNotEmpty;

  bool isSelected(String categoryId) => _selectedCategoryIds.contains(categoryId);

  Future<void> init() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _selectedCategoryIds =
        (prefs.getStringList(AppConfig.prefSelectedCategoryIds) ?? []).toSet();
    _onboardingComplete = prefs.getBool(AppConfig.prefOnboardingComplete) ?? false;
    _loaded = true;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _onboardingComplete = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConfig.prefOnboardingComplete, true);
    notifyListeners();
  }

  Future<void> toggle(String categoryId) async {
    if (_selectedCategoryIds.contains(categoryId)) {
      _selectedCategoryIds.remove(categoryId);
    } else {
      _selectedCategoryIds.add(categoryId);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> setSelection(Set<String> categoryIds) async {
    _selectedCategoryIds = {...categoryIds};
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    _selectedCategoryIds = {};
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      AppConfig.prefSelectedCategoryIds,
      _selectedCategoryIds.toList(),
    );
  }
}
