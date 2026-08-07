import '../models/resource_category.dart';

/// Everything about "type what you do and get allocated to a category" in
/// one place, so the onboarding picker (my_business_screen.dart) and the
/// Discover browse/search screen (discover_screen.dart) can't quietly drift
/// out of sync on section order, matching rules, or the "Others" fallback.
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
      "FinReels will keep your feed general instead of guessing.";

  /// Onboarding shows this many categories per section before the person
  /// types anything — the rest are still reachable by search. Keeps the
  /// first screen short; search (with [searchKeywords] behind it) is the
  /// primary way most people will actually find their category.
  static const int defaultVisiblePerSection = 6;

  /// Section display order across the app: Profession first, then Skill,
  /// then Business — Others is handled separately by the caller (it isn't
  /// a [ResourceSection] and doesn't come from resource_categories.json).
  static const List<ResourceSection> sectionOrder = [
    ResourceSection.profession,
    ResourceSection.skill,
    ResourceSection.business,
  ];

  /// True if [category] matches [rawQuery] — checked against its name and
  /// every one of its searchKeywords. Substring match both ways (query
  /// inside a keyword, or a keyword inside a longer typed phrase) so both
  /// "sew" -> "sewing" and "I sew clothes for people" -> "sew" resolve.
  static bool matches(ResourceCategory category, String rawQuery) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (category.name.toLowerCase().contains(q)) return true;
    for (final keyword in category.searchKeywords) {
      final k = keyword.toLowerCase();
      if (k.contains(q) || q.contains(k)) return true;
    }
    return false;
  }

  /// Filters [categories] down to the ones matching [query]. Order is
  /// preserved (callers already get categories pre-sorted by [number] from
  /// ResourceCategoryData.bySection).
  static List<ResourceCategory> search(List<ResourceCategory> categories, String query) =>
      categories.where((c) => matches(c, query)).toList(growable: false);
}
