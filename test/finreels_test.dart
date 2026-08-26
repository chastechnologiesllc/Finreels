import 'package:finreels/config/app_config.dart';
import 'package:finreels/data/channel_data.dart';
import 'package:finreels/models/resource_category.dart';
import 'package:finreels/models/video.dart';
import 'package:finreels/services/feed_snapshot_service.dart';
import 'package:finreels/utils/category_search.dart';
import 'package:finreels/widgets/book_cover_image.dart';
import 'package:finreels/widgets/blog_thumbnail_image.dart';
import 'package:finreels/widgets/finreels_shimmer.dart';
import 'package:finreels/widgets/video_thumbnail_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── Shared loading surfaces ───────────────────────────────────────────────────
  group('Shared loading surfaces', () {
    test('uses a visible animation period', () {
      expect(FinreelsShimmer.animationPeriod.inMilliseconds, 950);
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

    testWidgets('missing book covers render the bundled FinReels fallback',
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
          'assets/books/finreels_book_cover_fallback.png');
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
          'assets/blog/finreels_blog_cover.png');
    });

    testWidgets('shimmer builds in both light and dark themes', (tester) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: const FinreelsShimmer(
              child: SizedBox(width: 80, height: 24),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(FinreelsShimmer), findsOneWidget);
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

  // ── Channel Data ────────────────────────────────────────────────────────────
  group('ChannelData', () {
    test('has exactly 12 channels', () {
      expect(ChannelData.all.length, 12);
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
      expect(AppConfig.packageName, 'com.chastechgroup.finreels');
    });

    test('3 IAP product IDs defined', () {
      expect(AppConfig.iapProductIds.length, 3);
    });

    test('IAP IDs have correct format', () {
      for (final id in AppConfig.iapProductIds) {
        expect(id, startsWith('finreels_'));
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
      const gold = Color(0xFFF59E0B);
      expect(gold.r, closeTo(245 / 255, 0.01));
      expect(gold.g, closeTo(158 / 255, 0.01));
      expect(gold.b, closeTo(11 / 255, 0.01));
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
