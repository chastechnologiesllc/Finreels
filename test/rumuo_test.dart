import 'package:rumuo/config/app_config.dart';
import 'package:rumuo/data/channel_avatar_data.dart';
import 'package:rumuo/data/channel_data.dart';
import 'package:rumuo/models/channel.dart';
import 'package:rumuo/models/resource_category.dart';
import 'package:rumuo/models/saved_bookmark.dart';
import 'package:rumuo/models/video.dart';
import 'package:rumuo/services/blog_rss_service.dart';
import 'package:rumuo/services/book_reader_content.dart';
import 'package:rumuo/services/feed_snapshot_service.dart';
import 'package:rumuo/services/media_cache_manager.dart';
import 'package:rumuo/utils/category_search.dart';
import 'package:rumuo/widgets/book_cover_image.dart';
import 'package:rumuo/widgets/blog_thumbnail_image.dart';
import 'package:rumuo/widgets/channel_avatar.dart';
import 'package:rumuo/widgets/rumuo_shimmer.dart';
import 'package:rumuo/widgets/video_thumbnail_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── Shared loading surfaces ───────────────────────────────────────────────────
  group('Shared loading surfaces', () {
    test('uses a visible animation period', () {
      expect(RumuoShimmer.animationPeriod.inMilliseconds, 950);
    });

    testWidgets('empty video IDs render a fallback without a network image',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: VideoThumbnailImage.forVideoId(
            videoId: '',
            thumbnailUrl: '',
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('missing book covers render the bundled Rumuo fallback',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 100,
            height: 140,
            child: BookCoverImage(url: ''),
          ),
        ),
      );
      await tester.pump();
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName,
          'assets/books/rumuo_book_cover_fallback.png');
    });

    testWidgets('missing blog thumbnails render the branded cover',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 320,
            height: 180,
            child: BlogThumbnailImage(url: ''),
          ),
        ),
      );
      await tester.pump();
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName,
          'assets/blog/rumuo_blog_cover.png');
    });

    testWidgets('shimmer builds in both light and dark themes', (tester) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: const RumuoShimmer(
              child: SizedBox(width: 80, height: 24),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(RumuoShimmer), findsOneWidget);
      }
    });

    test('onboarding search ranks short typed queries without showing defaults', () {
      const categories = [
        ResourceCategory(
          id: 'law',
          section: ResourceSection.profession,
          number: 1,
          name: 'Law',
          realProblem: 'Learn legal practice and business basics.',
          searchKeywords: ['legal', 'lawyer'],
        ),
        ResourceCategory(
          id: 'medicine',
          section: ResourceSection.profession,
          number: 2,
          name: 'Medicine',
          realProblem: 'Learn healthcare practice and business basics.',
          searchKeywords: ['doctor', 'health'],
        ),
        ResourceCategory(
          id: 'tailoring',
          section: ResourceSection.skill,
          number: 3,
          name: 'Tailoring',
          realProblem: 'Learn garment-making skills and business basics.',
          searchKeywords: ['sewing', 'fashion'],
        ),
      ];

      expect(CategorySearch.search(categories, ''), isEmpty);
      expect(CategorySearch.search(categories, 'l').map((c) => c.name),
          contains('Law'));
      expect(CategorySearch.search(categories, 'la').first.name, 'Law');
      expect(
        CategorySearch.search(categories, 'l', limit: 2),
        hasLength(2),
      );
    });

    test('bundled feed snapshot has public channel and blog data', () async {
      final snapshot = FeedSnapshotService.instance;
      expect((await snapshot.blogArticles()).isNotEmpty, isTrue);
      expect(
        (await snapshot.channelVideos('UCGq-a57w-aPwyi3pW7XLiHw')).isNotEmpty,
        isTrue,
      );
    });

    test('blog source keys ignore punctuation and repeated whitespace', () {
      expect(
        BlogRssService.normalizeSourceName('  Inc.   Magazine '),
        'inc magazine',
      );
      expect(
        BlogRssService.normalizeSourceName('INC-MAGAZINE'),
        BlogRssService.normalizeSourceName('Inc. Magazine'),
      );
    });

    test('blog source identity prefers verified URL over display name', () {
      final first = BlogArticle(
        title: 'First',
        url: 'https://example.com/first',
        sourceName: 'Example Magazine',
        sourceUrl: 'https://example.com/feed/',
        publishedAt: DateTime(2026, 8, 28),
      );
      final second = BlogArticle(
        title: 'Second',
        url: 'https://example.com/second',
        sourceName: 'Example-Magazine',
        sourceUrl: 'https://example.com/feed',
        publishedAt: DateTime(2026, 8, 27),
      );
      final legacy = BlogArticle(
        title: 'Legacy',
        url: 'https://example.com/legacy',
        sourceName: 'Example Magazine',
        publishedAt: DateTime(2026, 8, 26),
      );
      expect(BlogRssService.sameSource(first, second), isTrue);
      expect(BlogRssService.sameSource(first, legacy), isFalse);
      expect(
        BlogRssService.sourceIdentity(legacy.sourceName),
        'name:example magazine',
      );
    });

    test('category blog ranking prioritizes selected categories over general', () {
      BlogArticle article(String title, String source, String? categoryId, int day) =>
          BlogArticle(
            title: title,
            url: 'https://example.com/${title.toLowerCase().replaceAll(' ', '-')}',
            sourceName: source,
            publishedAt: DateTime(2026, 8, day),
            categoryId: categoryId,
          );

      final ordered = BlogRssService.prioritizeForSelection(
        [
          article('General newest', 'General', null, 28),
          article('General second', 'General 2', null, 27),
          article('Category A', 'A', 'cat_a', 26),
          article('Category B', 'B', 'cat_b', 25),
          article('Category A two', 'A', 'cat_a', 24),
          article('Category B two', 'B', 'cat_b', 23),
          article('Category A three', 'A', 'cat_a', 22),
        ],
        {'cat_a', 'cat_b'},
      );

      final firstGeneral = ordered.indexWhere((item) => item.categoryId == null);
      expect(firstGeneral, greaterThanOrEqualTo(2));
      expect(firstGeneral, lessThanOrEqualTo(3));
      expect(ordered.where((item) => item.categoryId != null), isNotEmpty);
      expect(ordered.where((item) => item.categoryId == null), isNotEmpty);
      expect(ordered.map((item) => item.categoryId).toSet(),
          containsAll(<String?>['cat_a', 'cat_b', null]));
    });

    test('blog ranking separates repeated sources across the scroll window', () {
      final articles = <BlogArticle>[];
      for (final source in ['A', 'B', 'C', 'D']) {
        for (var copy = 0; copy < 3; copy++) {
          articles.add(BlogArticle(
            title: '$source article $copy',
            url: 'https://example.com/$source-$copy',
            sourceName: source,
            publishedAt: DateTime(2026, 8, 28 - articles.length),
          ));
        }
      }

      final ordered = BlogRssService.prioritizeForSelection(
        articles,
        const <String>{},
      );
      for (var i = 0; i < ordered.length; i++) {
        final source = BlogRssService.normalizeSourceName(ordered[i].sourceName);
        final start = i > 3 ? i - 3 : 0;
        expect(
          ordered.sublist(start, i).every((item) =>
              BlogRssService.normalizeSourceName(item.sourceName) != source),
          isTrue,
          reason: 'Source $source repeated too soon at index $i',
        );
      }
    });

    test('blog source merge keeps live article and restores fallback records', () {
      final live = BlogArticle(
        title: 'Fresh title',
        url: 'https://example.com/shared',
        sourceName: 'Example',
        publishedAt: DateTime(2026, 8, 27),
      );
      final fallback = [
        BlogArticle(
          title: 'Stale title',
          url: 'https://example.com/shared',
          sourceName: 'Example',
          publishedAt: DateTime(2026, 8, 26),
        ),
        BlogArticle(
          title: 'Cached article',
          url: 'https://example.com/cached',
          sourceName: 'Example',
          publishedAt: DateTime(2026, 8, 25),
        ),
      ];
      final merged = BlogRssService.mergeArticles([live], fallback);
      expect(merged, hasLength(2));
      expect(merged.first.title, 'Fresh title');
      expect(merged.map((article) => article.url),
          contains('https://example.com/cached'));
    });

    test('School of Life snapshot uses the canonical channel feed', () async {
      final videos = await FeedSnapshotService.instance
          .channelVideos('UC7IcJI8PUf5Z3zKxnZvTBog');
      expect(videos, isNotEmpty);
      expect(videos.every((video) => video.channelId == 'UC7IcJI8PUf5Z3zKxnZvTBog'), isTrue);
      expect(
        videos.every(
          (video) => !RegExp(r' chicken|goose|swan|poultry|bird', caseSensitive: false)
              .hasMatch('${video.title} ${video.description}'),
        ),
        isTrue,
      );
    });
  });

  // ── Media cache ────────────────────────────────────────────────────────────
  group('Media cache', () {
    test('remembers successful fallback candidates', () {
      const key = 'test-media-cache-key';
      RumuoMediaCache.rememberSelection(key, 4);
      expect(RumuoMediaCache.selectedIndex(key), 4);
    });
  });

  // ── Video Model ─────────────────────────────────────────────────────────────
  group('Video model', () {
    final video = Video(
      id: 'abc123',
      title: 'Test Video',
      description: 'A test description',
      channelId: 'ch1',
      channelName: 'Test Channel',
      publishedAt: DateTime(2024, 6, 15),
      thumbnailUrl: 'https://img.youtube.com/vi/abc123/mqdefault.jpg',
      thumbnailFallbackUrls: const [
        'https://img.youtube.com/vi/abc123/default.jpg',
      ],
    );

    test('watchUrl is correct', () {
      expect(video.watchUrl, 'https://www.youtube.com/watch?v=abc123');
    });

    test('thumbnailHd is correct', () {
      expect(
        video.thumbnailHd,
        'https://img.youtube.com/vi/abc123/maxresdefault.jpg',
      );
    });

    test('thumbnailMq is correct', () {
      expect(
        video.thumbnailMq,
        'https://img.youtube.com/vi/abc123/mqdefault.jpg',
      );
    });

    test('equality by id', () {
      final duplicate = Video(
        id: 'abc123',
        title: 'Different title',
        description: '',
        channelId: 'ch2',
        channelName: 'Other',
        publishedAt: DateTime.now(),
        thumbnailUrl: '',
      );
      expect(video, equals(duplicate));
    });

    test('JSON round-trip', () {
      final json = video.toJson();
      final restored = Video.fromJson(json);
      expect(restored.id, video.id);
      expect(restored.title, video.title);
      expect(restored.channelId, video.channelId);
      expect(restored.publishedAt, video.publishedAt);
      expect(restored.thumbnailFallbackUrls, video.thumbnailFallbackUrls);
    });
  });

  // ── Saved bookmarks ─────────────────────────────────────────────────────────
  group('SavedBookmark model', () {
    test('round-trips books, blogs, videos, and Shorts', () {
      final video = Video(
        id: 'short-1',
        title: 'Short lesson',
        description: 'A short lesson',
        channelId: 'channel-1',
        channelName: 'Learning Channel',
        publishedAt: DateTime(2026, 8, 26),
        thumbnailUrl: 'https://example.com/short.jpg',
        originalLink: 'https://www.youtube.com/shorts/short-1',
      );
      final short = SavedBookmark.fromVideo(video);
      final blog = SavedBookmark(
        id: 'https://example.com/blog',
        kind: SavedBookmarkKind.blog,
        title: 'A blog',
        description: 'An excerpt',
        sourceName: 'Example',
        url: 'https://example.com/blog',
        publishedAt: DateTime(2026, 8, 26),
      );
      final book = SavedBookmark(
        id: 'https://www.gutenberg.org/ebooks/1',
        kind: SavedBookmarkKind.book,
        title: 'A book',
        description: 'A free book',
        sourceName: 'Author',
        url: 'https://www.gutenberg.org/ebooks/1',
        publishedAt: DateTime(2026, 8, 26),
      );

      expect(short.kind, SavedBookmarkKind.short);
      expect(SavedBookmark.fromJson(short.toJson()).stableKey, short.stableKey);
      expect(SavedBookmark.fromJson(blog.toJson()).isBlog, isTrue);
      expect(SavedBookmark.fromJson(book.toJson()).isBook, isTrue);
      expect(SavedBookmark.fromJson(book.toJson()).url, book.url);
    });
  });

  // ── Channel Data ────────────────────────────────────────────────────────────
  group('ChannelData', () {
    test('has exactly 12 channels', () {
      expect(ChannelData.all.length, 12);
    });

    test('official avatar manifest covers the primary channels', () {
      expect(ChannelAvatarData.byChannelId.length, greaterThanOrEqualTo(477));
      expect(
        ChannelData.all.every((channel) => channel.avatarUrl != null),
        isTrue,
      );
    });

    test('Doctorpreneur feed channel has an official profile image', () {
      const channelId = 'UCto7aLUgNulcszaErw4FS1g';
      final avatar = ChannelAvatarData.byChannelId[channelId];
      expect(avatar, isNotNull);
      expect(avatar, startsWith('https://yt3.googleusercontent.com/'));
    });

    testWidgets('channel avatar keeps a circular initials fallback',
        (tester) async {
      const channel = Channel(
        id: 'missing-avatar-channel',
        name: 'Fallback Channel',
        handle: '@fallback',
        description: '',
        accentColor: Color(0xFF2563EB),
        category: 'Test',
        focus: '',
        initials: 'FC',
      );
      await tester.pumpWidget(
        const MaterialApp(home: ChannelAvatar(channel: channel, size: 48)),
      );
      expect(find.byType(ClipOval), findsOneWidget);
      expect(find.text('FC'), findsOneWidget);
    });

    test('School of Hard Knocks is in the list', () {
      expect(
        ChannelData.all.any((ch) => ch.name == 'School of Hard Knocks'),
        isTrue,
      );
    });

    test('all channels have non-empty IDs', () {
      for (final ch in ChannelData.all) {
        expect(ch.id.isNotEmpty, isTrue, reason: '${ch.name} has empty ID');
      }
    });

    test('all channels have valid RSS URLs', () {
      for (final ch in ChannelData.all) {
        expect(ch.rssUrl, contains('channel_id=${ch.id}'));
      }
    });

    test('all channels have 2-char initials', () {
      for (final ch in ChannelData.all) {
        expect(ch.initials.length, 2, reason: '${ch.name} initials wrong');
      }
    });

    test('all accent colors are non-transparent', () {
      for (final ch in ChannelData.all) {
        expect(ch.accentColor.a, greaterThan(0));
      }
    });
  });

  // ── AppConfig ───────────────────────────────────────────────────────────────
  group('AppConfig', () {
    test('package name is correct', () {
      expect(AppConfig.packageName, 'com.chastechgroup.rumuo');
    });

    test('3 IAP product IDs defined', () {
      expect(AppConfig.iapProductIds.length, 3);
    });

    test('IAP IDs have correct format', () {
      for (final id in AppConfig.iapProductIds) {
        expect(id, startsWith('rumuo_'));
      }
    });

    test('has 4 connectivity endpoints', () {
      expect(AppConfig.connectivityEndpoints.length, 4);
    });

    test('has 4 ad-check endpoints', () {
      expect(AppConfig.adCheckEndpoints.length, 4);
    });

    test('connectivity endpoints are HTTPS', () {
      for (final url in AppConfig.connectivityEndpoints) {
        expect(url, startsWith('https://'));
      }
    });
  });

  // ── Theme Colours ────────────────────────────────────────────────────────────
  group('Theme colours', () {
    test('gold is correct hex', () {
      const gold = Color(0xFFF0AA1D);
      expect(gold.r, closeTo(240 / 255, 0.01));
      expect(gold.g, closeTo(170 / 255, 0.01));
      expect(gold.b, closeTo(29 / 255, 0.01));
    });

    test('dark background is pure black', () {
      const black = Color(0xFF000000);
      expect(black.r, 0);
      expect(black.g, 0);
      expect(black.b, 0);
    });

    test('light background is pure white', () {
      const white = Color(0xFFFFFFFF);
      expect(white.r, 1.0);
      expect(white.g, 1.0);
      expect(white.b, 1.0);
    });
  });

  // ── ResourceCategory.searchKeywords ─────────────────────────────────────────
  group('ResourceCategory searchKeywords', () {
    const baseJson = {
      'id': 'skill_01_tailoring_fashion_design',
      'section': 'skill',
      'number': 1,
      'name': 'Tailoring & Fashion Design',
    };

    test('parses searchKeywords when present', () {
      final category = ResourceCategory.fromJson({
        ...baseJson,
        'searchKeywords': ['tailor', 'sew', 'ankara'],
      });
      expect(category.searchKeywords, ['tailor', 'sew', 'ankara']);
    });

    test('defaults to an empty list when absent (older/partial data)', () {
      final category = ResourceCategory.fromJson(baseJson);
      expect(category.searchKeywords, isEmpty);
    });
  });

  // ── CategorySearch ───────────────────────────────────────────────────────────
  group('CategorySearch', () {
    const tailoring = ResourceCategory(
      id: 'skill_01_tailoring_fashion_design',
      section: ResourceSection.skill,
      number: 1,
      name: 'Tailoring & Fashion Design',
      searchKeywords: ['tailor', 'sew', 'ankara', 'seamstress'],
    );
    const medicine = ResourceCategory(
      id: 'profession_01_medicine',
      section: ResourceSection.profession,
      number: 1,
      name: 'Medicine',
      searchKeywords: ['doctor', 'physician'],
    );
    final categories = [tailoring, medicine];

    test('empty query matches nothing', () {
      expect(CategorySearch.matches(tailoring, ''), isFalse);
      expect(CategorySearch.matches(medicine, ''), isFalse);
      expect(CategorySearch.search(categories, ''), isEmpty);
    });

    test('matches on a substring of the category name', () {
      expect(CategorySearch.matches(tailoring, 'tailoring'), isTrue);
      expect(CategorySearch.matches(medicine, 'medicine'), isTrue);
    });

    test('matches on a keyword the name itself does not contain', () {
      // "sew" never appears in "Tailoring & Fashion Design" — this only
      // passes because of searchKeywords, proving the allocation feature
      // actually adds coverage beyond a plain name match.
      expect(CategorySearch.matches(tailoring, 'sew'), isTrue);
      expect(CategorySearch.matches(medicine, 'doctor'), isTrue);
    });

    test('a keyword from one category does not match another', () {
      expect(CategorySearch.matches(tailoring, 'doctor'), isFalse);
      expect(CategorySearch.matches(medicine, 'ankara'), isFalse);
    });

    test('search() filters a list down to only the matches', () {
      expect(CategorySearch.search(categories, 'sew'), [tailoring]);
      expect(CategorySearch.search(categories, 'physician'), [medicine]);
      expect(CategorySearch.search(categories, 'zzz-no-such-trade'), isEmpty);
    });

    test('exact category names rank ahead of keyword matches', () {
      final results = CategorySearch.search(
        [
          tailoring,
          medicine,
          const ResourceCategory(
            id: 'profession_02_pharmacy',
            section: ResourceSection.profession,
            number: 2,
            name: 'Pharmacy',
            searchKeywords: ['medicine'],
          ),
        ],
        'medicine',
        limit: 8,
      );
      expect(results.first, medicine);
      expect(results.map((c) => c.name), contains('Pharmacy'));
    });

    test('sectionOrder is Profession, Skill, Business, then Online Hustles', () {
      expect(CategorySearch.sectionOrder, [
        ResourceSection.profession,
        ResourceSection.skill,
        ResourceSection.business,
        ResourceSection.onlineHustle,
      ]);
    });

    test('othersId never collides with a real category id shape', () {
      // Real ids look like skill_01_... / business_07_... / profession_12_...
      // / online_hustles_01_... — 'others' must not match those patterns.
      expect(CategorySearch.othersId, 'others');
      expect(
        RegExp(r'^(skill|business|profession|online_hustles)_\d{2}_')
            .hasMatch(CategorySearch.othersId),
        isFalse,
      );
    });
  });

  // ── Book reader content handling ───────────────────────────────────────────
  group('Book reader content handling', () {
    test('book reader source fallback prioritizes readable content', () {
      const original = 'https://www.gutenberg.org/ebooks/8376';
      const readable =
          'https://www.gutenberg.org/cache/epub/8376/pg8376-images.html';
      expect(
        BookReaderContent.sourceCandidates(readable, original),
        [readable, original],
      );
      expect(BookReaderContent.sourceCandidates(readable, readable), [readable]);
    });

    test('book reader content handling maps Gutenberg landing pages to the readable HTML body', () {
      expect(
        BookReaderContent.readableUrl('https://www.gutenberg.org/ebooks/7598'),
        'https://www.gutenberg.org/cache/epub/7598/pg7598-images.html',
      );
    });

    test('maps Gutenberg EPUB URLs to the generated HTML body', () {
      expect(
        BookReaderContent.readableUrl(
          'https://www.gutenberg.org/cache/epub/7598/pg7598-images.epub',
        ),
        'https://www.gutenberg.org/cache/epub/7598/pg7598-images.html',
      );
    });

    test('strips source CSS and page chrome while preserving book text', () {
      final clean = BookReaderContent.sanitizeHtml('''
        <html><head><style>body { background: black; color: white; }</style></head>
        <body><nav>Metadata navigation</nav><h1 style="color:white">The Caxtons</h1>
        <p>This is the readable book text.</p><script>alert('x')</script></body></html>
      ''');
      expect(clean, contains('The Caxtons'));
      expect(clean, contains('This is the readable book text.'));
      expect(clean, isNot(contains('Metadata navigation')));
      expect(clean, isNot(contains('<style')));
      expect(clean, isNot(contains('background: black')));
      expect(clean, isNot(contains('<script')));
    });

    test('detects plain text book responses', () {
      expect(
        BookReaderContent.looksLikePlainText(
          'https://example.com/book.txt',
          'text/plain; charset=utf-8',
          'Chapter one\\nReadable text',
        ),
        isTrue,
      );
      expect(
        BookReaderContent.looksLikePlainText(
          'https://example.com/book',
          'text/html',
          '<html><body><p>Readable text</p></body></html>',
        ),
        isFalse,
      );
    });
  });

  // ── Video verified_book handling ────────────────────────────────────────────
  group('Video verified_book support', () {
    final verifiedBook = Video(
      id: 'vbook_skill_01_fashion_for_profit',
      title: 'Fashion for Profit',
      description: 'Frances Harder',
      channelId: 'verified_book',
      channelName: 'Frances Harder',
      publishedAt: DateTime(2000),
      thumbnailUrl: '', // no cover source — BookCoverImage shows a placeholder
      thumbnailFallbackUrls: const [
        'https://covers.openlibrary.org/b/id/123-L.jpg',
      ],
      freeSourceUrl: 'https://example.com/fashion-for-profit',
      freeSourceType: 'web',
      sourceCategoryId: 'skill_01_tailoring_fashion_design',
    );

    test('never gets treated as a real YouTube id for its thumbnail', () {
      expect(verifiedBook.thumbnailHd, ''); // falls back to thumbnailUrl, not a youtube.com URL
      expect(verifiedBook.thumbnailMq, '');
    });

    test('round-trips its extra fields through JSON', () {
      final restored = Video.fromJson(verifiedBook.toJson());
      expect(restored.freeSourceUrl, verifiedBook.freeSourceUrl);
      expect(restored.freeSourceType, verifiedBook.freeSourceType);
      expect(restored.sourceCategoryId, verifiedBook.sourceCategoryId);
      expect(restored.thumbnailFallbackUrls, verifiedBook.thumbnailFallbackUrls);
    });

    test('a plain video never carries verified_book fields', () {
      final plain = Video(
        id: 'abc123',
        title: 'Test',
        description: '',
        channelId: 'ch1',
        channelName: 'Test Channel',
        publishedAt: DateTime.now(),
        thumbnailUrl: '',
      );
      expect(plain.freeSourceUrl, isNull);
      expect(plain.freeSourceType, isNull);
      expect(plain.sourceCategoryId, isNull);
    });
  });
}
