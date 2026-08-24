import 'package:flutter_test/flutter_test.dart';

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

  test('empty queries never return the entire catalogue', () {
    expect(index.search(query: ''), isEmpty);
    expect(index.search(query: ' '), isEmpty);
  });
}
