import '../services/blog_rss_service.dart';
import 'video.dart';

/// Content kinds that can be saved to the shared Bookmarks screen.
enum SavedBookmarkKind { video, short, blog, book }

/// A persistence-safe snapshot of any content item a person bookmarks.
///
/// Keeping the display metadata with the bookmark means saved blogs and
/// verified books remain visible after a restart even when their live feed is
/// unavailable. Videos retain their full Video payload for existing player
/// routes and Shorts retain their original link for correct navigation.
class SavedBookmark {
  final String id;
  final SavedBookmarkKind kind;
  final String title;
  final String description;
  final String sourceName;
  final String? url;
  final String? thumbnailUrl;
  final List<String> thumbnailFallbackUrls;
  final DateTime publishedAt;
  final String? channelId;
  final String? sourceCategoryId;
  final String? freeSourceType;
  final String? originalLink;

  const SavedBookmark({
    required this.id,
    required this.kind,
    required this.title,
    required this.description,
    required this.sourceName,
    required this.publishedAt,
    this.url,
    this.thumbnailUrl,
    this.thumbnailFallbackUrls = const [],
    this.channelId,
    this.sourceCategoryId,
    this.freeSourceType,
    this.originalLink,
  });

  bool get isShort => kind == SavedBookmarkKind.short;
  bool get isBook => kind == SavedBookmarkKind.book;
  bool get isBlog => kind == SavedBookmarkKind.blog;
  bool get isVideo => kind == SavedBookmarkKind.video || isShort;

  String get stableKey => '${kind.name}:$id';

  Video get videoItem => Video(
      id: id,
      title: title,
      description: description,
      channelId: channelId ?? (isBook ? 'verified_book' : 'saved'),
      channelName: sourceName,
      publishedAt: publishedAt,
      thumbnailUrl: thumbnailUrl ?? '',
      thumbnailFallbackUrls: thumbnailFallbackUrls,
      originalLink: originalLink,
      freeSourceUrl: url,
      freeSourceType: freeSourceType,
      sourceCategoryId: sourceCategoryId,
    );

  Video? get video => isVideo ? videoItem : null;

  factory SavedBookmark.fromVideo(Video video) => SavedBookmark(
        id: video.id,
        kind: video.isShort ? SavedBookmarkKind.short :
            (video.channelId == 'books' || video.channelId == 'verified_book'
                ? SavedBookmarkKind.book
                : SavedBookmarkKind.video),
        title: video.title,
        description: video.description,
        sourceName: video.channelName,
        url: video.freeSourceUrl ?? video.watchUrl,
        thumbnailUrl: video.thumbnailUrl,
        thumbnailFallbackUrls: video.thumbnailFallbackUrls,
        publishedAt: video.publishedAt,
        channelId: video.channelId,
        sourceCategoryId: video.sourceCategoryId,
        freeSourceType: video.freeSourceType,
        originalLink: video.originalLink,
      );

  factory SavedBookmark.fromBlog(BlogArticle article) => SavedBookmark(
        id: article.url,
        kind: SavedBookmarkKind.blog,
        title: article.title,
        description: article.excerpt,
        sourceName: article.sourceName,
        url: article.url,
        thumbnailUrl: article.thumbnailUrl,
        thumbnailFallbackUrls: article.thumbnailFallbackUrls,
        publishedAt: article.publishedAt,
        sourceCategoryId: article.categoryId,
      );

  factory SavedBookmark.fromJson(Map<String, dynamic> json) {
    final kindName = json['kind'] as String? ?? 'video';
    final kind = SavedBookmarkKind.values.firstWhere(
      (candidate) => candidate.name == kindName,
      orElse: () => SavedBookmarkKind.video,
    );
    return SavedBookmark(
      id: json['id'] as String? ?? '',
      kind: kind,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      sourceName: json['sourceName'] as String? ?? '',
      url: json['url'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      thumbnailFallbackUrls: (json['thumbnailFallbackUrls'] as List?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const [],
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      channelId: json['channelId'] as String?,
      sourceCategoryId: json['sourceCategoryId'] as String?,
      freeSourceType: json['freeSourceType'] as String?,
      originalLink: json['originalLink'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'description': description,
        'sourceName': sourceName,
        if (url != null) 'url': url,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (thumbnailFallbackUrls.isNotEmpty)
          'thumbnailFallbackUrls': thumbnailFallbackUrls,
        'publishedAt': publishedAt.toIso8601String(),
        if (channelId != null) 'channelId': channelId,
        if (sourceCategoryId != null) 'sourceCategoryId': sourceCategoryId,
        if (freeSourceType != null) 'freeSourceType': freeSourceType,
        if (originalLink != null) 'originalLink': originalLink,
      };
}
