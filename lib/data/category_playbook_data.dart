import '../models/resource_category.dart';
import '../models/video.dart';
import 'book_insights_data.dart';
import 'resource_category_data.dart';

/// Turns each of the 60 [ResourceCategory] entries into a readable in-app
/// "Business Playbook" — reusing the existing Books-tab + insights-reader
/// architecture verbatim (a [Video] with channelId 'books' + a matching
/// [BookInsightData] with chapters). No new screens, no new widgets: this
/// is the same pattern `book_detail_screen.dart` already uses for "Think
/// and Grow Rich", applied to FinReels' own research instead of a
/// third-party book.
///
/// Unlike the hand-written entries in book_insights_data.dart (const,
/// compiled in), these are built at runtime from
/// [ResourceCategoryData.all] once that JSON asset has loaded — see
/// [BookInsightData.findInsight] for how the two sources are merged.
///
/// Every word in every chapter traces directly back to the founder's own
/// three source documents (skills questions, business framework Q&A,
/// profession curriculum) — nothing here is invented. Where a source only
/// has open questions with no answers behind them (skills, and part of
/// professions), those questions are deliberately left OUT of the book —
/// see _skillChapters/_professionChapters — rather than manufactured into
/// a chapter that reads as filler. Only real, answered content becomes a
/// chapter.
class CategoryPlaybookData {
  CategoryPlaybookData._();

  static List<Video>? _videos;
  static List<BookInsightData>? _insights;

  /// The synthetic id used for a category's playbook everywhere it shows
  /// up as a "book" — feed entries, saved items, insight lookup.
  static String playbookId(String categoryId) => 'playbook_$categoryId';

  /// True if [videoId] is a category playbook (as opposed to one of the
  /// original 10 hand-picked books in feed_provider.dart).
  static bool isPlaybookId(String videoId) => videoId.startsWith('playbook_');

  static List<Video> get videos {
    _ensureBuilt();
    return _videos!;
  }

  static List<BookInsightData> get insights {
    _ensureBuilt();
    return _insights!;
  }

  static void _ensureBuilt() {
    if (_videos != null) return;
    final categories = ResourceCategoryData.all;
    _videos = categories.map(_buildVideo).toList(growable: false);
    _insights = categories.map(_buildInsight).toList(growable: false);
  }

  /// Call after ResourceCategoryData reloads (defensive — in practice it
  /// only ever loads once per app run) to force regeneration.
  static void reset() {
    _videos = null;
    _insights = null;
  }

  /// Looks up insight data across BOTH sources: the original hand-written
  /// [kBookInsights] (book_insights_data.dart) and these generated
  /// category playbooks. book_detail_screen.dart calls this instead of
  /// the bare `findInsight()` so a single lookup covers every book id the
  /// app can produce, without book_insights_data.dart having to import
  /// this file back (which would create a circular dependency between the
  /// two data files for no real benefit).
  static BookInsightData? findAnyInsight(String bookId) {
    final own = findInsight(bookId);
    if (own != null) return own;
    if (!isPlaybookId(bookId)) return null;
    _ensureBuilt();
    for (final insight in _insights!) {
      if (insight.id == bookId) return insight;
    }
    return null;
  }

  static final DateTime _epoch = DateTime(2026);

  static Video _buildVideo(ResourceCategory c) => Video(
        id: playbookId(c.id),
        title: 'The Business of ${c.name}',
        description: c.shortDescription,
        channelId: 'books',
        channelName: 'FinReels Business Playbooks',
        publishedAt: _epoch,
        thumbnailUrl: 'assets/books/playbook_${c.section.name}_cover.jpg',
      );

  static BookInsightData _buildInsight(ResourceCategory c) {
    final chapters = <BookChapter>[
      ...switch (c.section) {
        ResourceSection.skill => _skillChapters(c),
        ResourceSection.business => _businessChapters(c),
        ResourceSection.profession => _professionChapters(c),
      },
    ];

    // Skills & businesses (trades) are exactly who the 2026 tax reform
    // favours — see curriculum Part 2 — and that fact isn't otherwise
    // captured anywhere in their source data, unlike professions (whose
    // "don't know" fact usually already *is* the tax angle). Adding it
    // here means every trade/business playbook carries FinReels' single
    // sharpest, most differentiated hook, not just the 20 professions.
    final tax = ResourceCategoryData.taxReform;
    if (tax != null && c.section != ResourceSection.profession) {
      chapters.add(BookChapter(
        title: 'The 2026 Tax Break Most People in This Trade Miss',
        body: tax.whyItMatters ?? tax.headline,
        keyPoints: tax.facts.take(3).toList(),
      ));
    }

    return BookInsightData(
      id: playbookId(c.id),
      title: 'The Business of ${c.name}',
      author: 'FinReels Research',
      tagline: c.shortDescription,
      intro: _intro(c),
      chapters: chapters,
      // Original FinReels research, not a summary of a purchasable book —
      // no purchase link. book_detail_screen.dart hides the "Get Full
      // Book" CTA whenever this is empty.
      purchaseUrl: '',
    );
  }

  static String _intro(ResourceCategory c) {
    final label = switch (c.section) {
      ResourceSection.skill => 'a skill practised by apprenticeship and hands-on trade',
      ResourceSection.business => 'a business run day to day, not just a job',
      ResourceSection.profession => 'a licensed profession with its own money rules',
    };
    return '${c.name} is $label. This playbook is FinReels\' own research into '
        'the money side of it — not how to do the craft, but how the craft '
        'turns into income, and where the money actually leaks.';
  }

  /// Skills-doc data is 5 open questions per skill with no answers behind
  /// them — genuinely useful as a research brief, but not something that
  /// belongs presented as a "book chapter" (a chapter titled "here are
  /// some unanswered questions" reads as filler, not content). So skill
  /// playbooks intentionally don't manufacture a chapter from these; the
  /// tax chapter below is real content, and that's what carries the
  /// skill/trade playbooks until real answers exist to show.
  static List<BookChapter> _skillChapters(ResourceCategory c) => const [];

  static List<BookChapter> _businessChapters(ResourceCategory c) {
    final qa = c.businessQA ?? const [];
    return [
      for (final pair in qa) BookChapter(title: pair.question, body: pair.answer),
    ];
  }

  static List<BookChapter> _professionChapters(ResourceCategory c) {
    final chapters = <BookChapter>[];
    if (c.realProblem != null) {
      chapters.add(BookChapter(
        title: 'The Real Problem',
        body: c.realProblem!,
      ));
    }
    // Note: businessQuestions (4 open questions per profession) are
    // intentionally not turned into a chapter here, same reasoning as
    // skills above — unanswered questions aren't book content.
    if (c.dontKnowFact != null) {
      final modules = c.dontKnowModules ?? [if (c.dontKnowModule != null) c.dontKnowModule!];
      final moduleNames = modules
          .map((code) => ResourceCategoryData.moduleByCode(code)?.name)
          .whereType<String>()
          .toList();
      chapters.add(BookChapter(
        title: 'What Most People Don\'t Know',
        body: c.dontKnowFact!,
        keyPoints: moduleNames,
      ));
    }
    return chapters;
  }
}
