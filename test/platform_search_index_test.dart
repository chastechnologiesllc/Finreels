import 'package:flutter_test/flutter_test.dart';

import 'package:finreels/data/resource_category_data.dart';
import 'package:finreels/models/resource_category.dart';
import 'package:finreels/models/video.dart';
import 'package:finreels/services/blog_rss_service.dart';
import 'package:finreels/services/platform_search_index.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final index = PlatformSearchIndex.instance;

  setUpAll(() async {
    await index.rebuild();
  });

  test('indexes canonical categories and their aliases', () {
    final tailor = index.search(query: 'tailor');
    final solar = index.search(query: 'solar panel');
    final law = index.search(query: 'law');
    final medicine = index.search(query: 'medicine');

    expect(tailor.first.kind, PlatformSearchKind.category);
    expect(tailor.first.title, contains('Tailor'));
    expect(solar.any((d) => d.title.contains('Solar')), isTrue);
    expect(law.first.title, 'Law');
    expect(medicine.first.title, 'Medicine');
  });

  test('indexes channels, verified blog sources, books, and playbooks', () {
    final channelResults = index.search(query: 'Entrepreneur');
    final blogResults = index.search(query: 'psychology');
    final bookResults = index.search(query: 'Michael Gerber');

    expect(channelResults.any((d) => d.kind == PlatformSearchKind.channel), isTrue);
    expect(blogResults.any((d) => d.kind == PlatformSearchKind.blogSource), isTrue);
    expect(bookResults.any((d) => d.kind == PlatformSearchKind.book), isTrue);
    expect(
      index.search(query: 'Business of Law')
          .any((d) => d.id.startsWith('playbook:')),
      isTrue,
    );
  });

  test('matches every meaningful term and ranks exact names first', () {
    final results = index.search(query: 'solar installation');
    expect(results, isNotEmpty);
    expect(results.first.title, contains('Solar Installation'));

    final exact = index.search(query: 'Law');
    expect(exact.first.title, 'Law');
    expect(exact.first.relevance, greaterThan(exact[1].relevance));
  });

  test('supports bounded typo tolerance without returning empty results', () {
    final results = index.search(query: 'tailr');
    expect(results, isNotEmpty);
    expect(results.any((d) => d.title.contains('Tailor')), isTrue);
  });

  test('loads an open-book overlay for every profession category', () {
    final professionIds = ResourceCategoryData.all
        .where((category) => category.section == ResourceSection.profession)
        .map((category) => category.id)
        .toSet();
    final overlayIds = ResourceCategoryData.verifiedBooks
        .where(
          (book) =>
              professionIds.contains(book.categoryId) &&
              book.subject != null &&
              book.stage != null &&
              book.region != null &&
              book.license != null,
        )
        .map((book) => book.categoryId)
        .whereType<String>()
        .toSet();

    expect(professionIds, hasLength(20));
    expect(overlayIds, containsAll(professionIds));
    expect(ResourceCategoryData.verifiedBooks.length, greaterThanOrEqualTo(20000));

    final medicine = index.search(query: 'pre-clinical anatomy');
    expect(
      medicine.any(
        (document) =>
            document.kind == PlatformSearchKind.book &&
            document.title == 'Anatomy and Physiology 2e',
      ),
      isTrue,
    );
    expect(
      ResourceCategoryData.verifiedBooks.any(
        (book) =>
            book.title == 'Medicine and Dentistry CCMAS 2023' &&
            book.region == 'Nigeria' &&
            book.stage == 'Nigeria undergraduate curriculum anchor' &&
            (book.license ?? '').isNotEmpty,
      ),
      isTrue,
    );
  });

  test('ranks exact relevant titles across every content type', () {
    final video = Video(
      id: 'blue-lantern-video',
      title: 'Blue Lantern Bookkeeping Sprint',
      description: 'A focused bookkeeping lesson.',
      channelId: 'search-video-channel',
      channelName: 'Search Video Channel',
      publishedAt: DateTime(2026, 8, 1),
      thumbnailUrl: '',
    );
    final short = Video(
      id: 'blue-lantern-short',
      title: 'Blue Lantern Bookkeeping Tip',
      description: 'A short bookkeeping tip.',
      channelId: 'search-short-channel',
      channelName: 'Search Short Channel',
      publishedAt: DateTime(2026, 8, 2),
      thumbnailUrl: '',
      originalLink: 'https://www.youtube.com/shorts/blue-lantern-short',
    );
    final book = Video(
      id: 'blue-lantern-book',
      title: 'Blue Lantern Bookkeeping Handbook',
      description: 'A practical bookkeeping handbook.',
      channelId: 'books',
      channelName: 'FinReels Books',
      publishedAt: DateTime(2026, 8, 3),
      thumbnailUrl: '',
    );
    final article = BlogArticle(
      title: 'Blue Lantern Bookkeeping Notes',
      url: 'https://example.com/blue-lantern-bookkeeping',
      sourceName: 'Example Learning Journal',
      publishedAt: DateTime(2026, 8, 4),
      excerpt: 'Notes for a bookkeeping sprint.',
    );

    final results = index.search(
      query: 'blue lantern bookkeeping sprint',
      videos: [video, short],
      books: [book],
      articles: [article],
    );

    expect(results, isNotEmpty);
    expect(results.first.title, video.title);
    expect(results.any((d) => d.kind == PlatformSearchKind.short), isTrue);
    expect(results.any((d) => d.kind == PlatformSearchKind.book), isTrue);
    expect(results.any((d) => d.kind == PlatformSearchKind.blog), isTrue);
  });

  test('ranks complete natural-language intent above isolated keywords', () {
    final exact = Video(
      id: 'doctor-practice-exact',
      title: 'How to Run a Successful Doctors Practice',
      description: 'A step-by-step guide to a successful medical practice.',
      channelId: 'medical-channel',
      channelName: 'Medical Business Learning',
      publishedAt: DateTime(2026, 8, 1),
      thumbnailUrl: '',
    );
    final weak = Video(
      id: 'doctor-practice-weak',
      title: 'Doctor Stories',
      description: 'A general discussion about doctors.',
      channelId: 'general-channel',
      channelName: 'General Learning',
      publishedAt: DateTime(2026, 8, 2),
      thumbnailUrl: '',
    );

    final results = index.search(
      query: 'how to run a successful doctors practice',
      videos: [weak, exact],
    );

    expect(results.first.id, 'video:doctor-practice-exact');
    expect(results.first.relevance, greaterThan(results[1].relevance));
  });

  test('deduplicates dynamic videos and blog URLs', () {
    final video = Video(
      id: 'duplicate-video',
      title: 'Solar installation pricing',
      description: 'Pricing for solar panels',
      channelId: 'test-channel',
      channelName: 'Test channel',
      publishedAt: DateTime(2026, 8, 1),
      thumbnailUrl: '',
    );
    final article = BlogArticle(
      title: 'Solar installation guide',
      url: 'https://Example.com/article/',
      sourceName: 'Example',
      publishedAt: DateTime(2026, 8, 2),
      excerpt: 'A guide to solar installation.',
    );

    final results = index.search(
      query: 'solar installation',
      videos: [video, video],
      articles: [article, article.copyWith()],
    );
    expect(
      results.where((d) => d.id == 'video:duplicate-video').length,
      1,
    );
    expect(
      results.where((d) => d.kind == PlatformSearchKind.blog).length,
      1,
    );
  });

  test('returns every matching dynamic record beyond the old 120 cap', () {
    final videos = [
      for (var i = 0; i < 135; i++)
        Video(
          id: 'complete-match-$i',
          title: 'Complete Match Result $i',
          description: 'A complete match for comprehensive search.',
          channelId: 'complete-match-channel',
          channelName: 'Complete Match Channel',
          publishedAt: DateTime(2026, 8, 1),
          thumbnailUrl: '',
        ),
    ];

    final results = index.search(query: 'complete match', videos: videos);
    expect(
      results.where((document) => document.id.startsWith('video:complete-match-')).length,
      135,
    );
  });

  test('empty queries never return the entire catalogue', () {
    expect(index.search(query: ''), isEmpty);
    expect(index.search(query: ' '), isEmpty);
  });
}
