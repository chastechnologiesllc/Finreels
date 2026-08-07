import 'dart:async';

import 'package:flutter/material.dart';

import '../data/category_playbook_data.dart';
import '../data/resource_category_data.dart';
import '../models/channel.dart';
import '../models/resource_category.dart';
import '../models/video.dart';
import '../services/ad_service.dart';
import '../services/blog_rss_service.dart';
import '../services/engagement_service.dart';
import '../services/user_profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/book_cover_image.dart';
import 'blog_reader_screen.dart';
import 'book_detail_screen.dart';
import 'channel_videos_screen.dart';

/// The "hub" for one of the 60 categories — reached from Discover, never
/// from the main feed, so nothing here is fetched until someone actually
/// taps in. That's deliberate: it's what lets the data model hold all 60
/// categories' worth of channels/blogs/books without every launch getting
/// slower as more get verified (see ChannelData.eagerFor).
///
/// Always shows the playbook (instant — no network, generated from the
/// bundled JSON). Channels, blogs and free books below it are real only
/// once verified — see assets/data/resources/{categoryId}.json —
/// otherwise this is honest about "still verifying" rather than showing
/// something fake.
class CategoryDetailScreen extends StatefulWidget {
  final ResourceCategory category;
  const CategoryDetailScreen({required this.category, super.key});

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  List<Channel> _channels = [];
  List<VerifiedBook> _books = [];
  List<BlogArticle> _blogArticles = [];
  bool _loadingBlogs = false;

  @override
  void initState() {
    super.initState();
    unawaited(EngagementService.instance.recordCategoryInterest(widget.category.id));
    _channels = ResourceCategoryData.verifiedChannels
        .where((c) => c.resourceCategoryId == widget.category.id)
        .toList();
    _books = ResourceCategoryData.verifiedBooks
        .where((b) => b.categoryId == widget.category.id)
        .toList();
    final hasBlogs = (ResourceCategoryData.verifiedFor(widget.category.id)?['blogs'] as List?)
            ?.isNotEmpty ??
        false;
    if (hasBlogs) _loadCategoryBlogs();
  }

  Future<void> _loadCategoryBlogs() async {
    setState(() => _loadingBlogs = true);
    // Fetches this category's blogs directly, regardless of whether the
    // person browsing here (from Discover) has it selected as their own —
    // BlogRssService.fetchAll()/combinedBlogFeeds is scoped to general +
    // the viewer's own selection, which would otherwise hide this
    // category's real blogs whenever someone is just browsing, not
    // personalizing. See fetchForCategory's doc comment.
    final articles = await BlogRssService.instance.fetchForCategory(widget.category.id);
    if (!mounted) return;
    setState(() {
      _blogArticles = articles;
      _loadingBlogs = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.category;
    final isSelected = UserProfileService.instance.isSelected(c.id);
    return Scaffold(
      backgroundColor: AppTheme.bgColor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: AppTheme.textColor(context), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(c.section.pluralLabel.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.gold, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          const SizedBox(height: 4),
          Text(c.name,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(c.shortDescription,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.textSecondary(context))),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await UserProfileService.instance.toggle(c.id);
                if (mounted) setState(() {});
              },
              icon: Icon(isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded),
              label: Text(isSelected ? 'This is My Business' : 'Set as My Business'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isSelected ? AppTheme.gold : AppTheme.textColor(context),
                side: BorderSide(color: isSelected ? AppTheme.gold : AppTheme.dividerColor(context)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _PlaybookCard(category: c),
          const SizedBox(height: 28),
          const _SectionLabel('Channels'),
          if (_channels.isEmpty)
            const _EmptyNote(text: 'Still verifying real channels for this category.')
          else
            ..._channels.map((ch) => _ChannelTile(channel: ch)),
          const SizedBox(height: 24),
          const _SectionLabel('Blogs'),
          if (_loadingBlogs)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator(color: AppTheme.gold)),
            )
          else if (_blogArticles.isEmpty)
            const _EmptyNote(text: 'Still verifying real blogs for this category.')
          else
            ..._blogArticles.take(8).map((a) => _BlogTile(article: a)),
          const SizedBox(height: 24),
          const _SectionLabel('Free Books'),
          if (_books.isEmpty)
            const _EmptyNote(text: 'Still verifying free books for this category.')
          else
            ..._books.map((b) => _FreeBookTile(book: b)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel(this.title);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final String text;
  const _EmptyNote({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppTheme.textMuted(context), fontStyle: FontStyle.italic)),
    );
  }
}

class _PlaybookCard extends StatelessWidget {
  final ResourceCategory category;
  const _PlaybookCard({required this.category});

  @override
  Widget build(BuildContext context) {
    final video = CategoryPlaybookData.videos
        .firstWhere((v) => v.id == CategoryPlaybookData.playbookId(category.id));
    return GestureDetector(
      onTap: () {
        unawaited(AdService.instance.onVideoTapped());
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => BookDetailScreen(book: video)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.gold.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.gold),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                  width: 44, height: 60, child: BookCoverImage(url: video.thumbnailUrl)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Read the Business Playbook',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('FinReels Research — free',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.textSecondary(context))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted(context)),
          ],
        ),
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final Channel channel;
  const _ChannelTile({required this.channel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ChannelVideosScreen(channel: channel)),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.dividerColor(context), width: 0.5),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: channel.accentColor,
                child: Text(channel.initials,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(channel.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(channel.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppTheme.textSecondary(context))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FreeBookTile extends StatelessWidget {
  final VerifiedBook book;
  const _FreeBookTile({required this.book});

  /// Converts this [VerifiedBook] to a [Video] using the same slug logic as
  /// FeedProvider._videoFromVerifiedBook, so the book ID is stable and
  /// consistent whether opened from the feed or from CategoryDetailScreen.
  Video _toVideo() {
    final slug = '${book.categoryId ?? 'general'}_${book.title}'
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '_');
    return Video(
      id: 'vbook_$slug',
      title: book.title,
      description: book.freeSourceNote != null
          ? '${book.author} · ${book.freeSourceNote}'
          : book.author,
      channelId: 'verified_book',
      channelName: book.author,
      publishedAt: DateTime(2000),
      thumbnailUrl: book.coverUrl ?? '',
      freeSourceUrl: book.freeSourceUrl,
      freeSourceType: book.freeSourceType,
      sourceCategoryId: book.categoryId,
    );
  }

  void _open(BuildContext context) {
    if (book.freeSourceUrl.isEmpty) return;
    unawaited(AdService.instance.onVideoTapped());
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookDetailScreen(book: _toVideo()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _open(context),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.dividerColor(context), width: 0.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                // Cover — BookCoverImage shows a branded placeholder when
                // coverUrl is empty, so no special-casing needed here.
                BookCoverImage(
                  url: book.coverUrl ?? '',
                  width: 62,
                  height: 84,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(11),
                    bottomLeft: Radius.circular(11),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // "📚 FREE BOOK" badge — matches Books-tab card style
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.gold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            '📚 FREE BOOK',
                            style: TextStyle(
                              color: AppTheme.gold,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          book.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary(context)),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(Icons.chevron_right_rounded,
                      color: AppTheme.textMuted(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class _BlogTile extends StatelessWidget {
  final BlogArticle article;
  const _BlogTile({required this.article});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BlogReaderScreen(
              url: article.url,
              title: article.title,
              categoryId: article.categoryId,
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.dividerColor(context), width: 0.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(article.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(article.sourceName,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppTheme.textSecondary(context))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted(context)),
            ],
          ),
        ),
      ),
    );
  }
}
