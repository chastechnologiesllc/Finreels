import '../models/resource_category.dart';

/// Everything about "type what you do and get allocated to a category" in
/// one place, used by the onboarding/personalize picker
/// (my_business_screen.dart) for section order, matching rules, and the
/// "Others" fallback.
class CategorySearch {
  CategorySearch._();

  /// Synthetic id for "none of the above" — never appears in
  /// resource_categories.json and never matches any channel/blog/book's
  /// resourceCategoryId, so selecting it is always a safe no-op that falls
  /// through to general content only. See ChannelData.eagerFor,
  /// BlogRssService.combinedBlogFeeds and FeedProvider._allBookVideos —
  /// each already resolves an id with no matching resource to "general
  /// content", which is exactly the behaviour "Others" is meant to have.
  static const String othersId = 'others';

  static const String othersName = 'Something Else / Others';

  static const String othersDescription =
      "Don't see your exact trade, business or profession? Pick this and "
      "Rumuo will keep your feed general instead of guessing.";

  /// Section display order across the app: Profession first, then Skill,
  /// then Business — Others is handled separately by the caller (it isn't
  /// a [ResourceSection] and doesn't come from resource_categories.json).
  static const List<ResourceSection> sectionOrder = [
    ResourceSection.profession,
    ResourceSection.skill,
    ResourceSection.business,
    ResourceSection.onlineHustle,
  ];

  /// True if [category] matches [rawQuery] — checked against its canonical
  /// name and every curated search keyword. Empty input deliberately matches
  /// nothing: callers must never turn an empty search into the full catalogue.
  static bool matches(ResourceCategory category, String rawQuery) {
    final q = _normalise(rawQuery);
    if (q.isEmpty) return false;

    final name = _normalise(category.name);
    if (name.contains(q)) return true;
    for (final keyword in category.searchKeywords) {
      final k = _normalise(keyword);
      if (k.contains(q) || q.contains(k)) return true;
    }

    // A natural-language query such as "I sew clothes" should still match
    // the shorter indexed keyword "sew" when no whole-string match exists.
    final tokens = q.split(' ');
    if (tokens.length > 1) {
      final haystacks = [name, ...category.searchKeywords.map(_normalise)];
      return tokens.every((token) =>
          token.length >= 2 && haystacks.any((h) => h.contains(token)));
    }
    return false;
  }

  /// Filters [categories] down to matching categories and ranks exact/canonical
  /// name matches ahead of keyword and partial matches. [limit] is optional so
  /// a short query cannot recreate the old full catalogue screen.
  static List<ResourceCategory> search(
    List<ResourceCategory> categories,
    String query, {
    int? limit,
  }) {
    final q = _normalise(query);
    if (q.isEmpty) return const <ResourceCategory>[];

    final matchedCategories =
        categories.where((category) => matches(category, q)).toList();
    matchedCategories.sort((a, b) {
      final score = _score(b, q).compareTo(_score(a, q));
      return score != 0 ? score : a.number.compareTo(b.number);
    });
    if (limit != null && matchedCategories.length > limit) {
      return List.unmodifiable(matchedCategories.take(limit));
    }
    return List.unmodifiable(matchedCategories);
  }

  static String _normalise(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static int _score(ResourceCategory category, String q) {
    final name = _normalise(category.name);
    if (name == q) return 400;
    if (name.startsWith(q)) return 300;
    if (name.contains(q)) return 250;
    if (category.searchKeywords.any((k) => _normalise(k) == q)) return 200;
    return 100;
  }
}
