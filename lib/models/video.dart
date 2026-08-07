class Video {
  final String id;
  final String title;
  final String description;
  final String channelId;
  final String channelName;
  final DateTime publishedAt;
  final String thumbnailUrl;
  /// Original RSS link — YouTube Shorts have /shorts/ in this URL.
  final String? originalLink;

  /// The following three fields are only set when channelId ==
  /// 'verified_book' — a real, named book pulled from a category's
  /// assets/data/resources/{categoryId}.json (see VerifiedBook in
  /// resource_category.dart), as opposed to 'books' (the original 10
  /// hand-picked classics/playbooks with their own EPUB/PDF/insights
  /// reader). These entries never open BookDetailScreen — home_screen.dart
  /// routes them to an external launch ('download') or the same in-app web
  /// reader a blog article uses ('web'). Always null for every other kind
  /// of Video.
  final String? freeSourceUrl;
  final String? freeSourceType; // 'web' or 'download'
  final String? sourceCategoryId;

  const Video({
    required this.id,
    required this.title,
    required this.description,
    required this.channelId,
    required this.channelName,
    required this.publishedAt,
    required this.thumbnailUrl,
    this.originalLink,
    this.freeSourceUrl,
    this.freeSourceType,
    this.sourceCategoryId,
  });

  /// True if this video is a YouTube Short.
  /// Primary signal: original RSS link contains /shorts/ path.
  /// Fallback: explicit #shorts hashtag in title or description.
  bool get isShort {
    if (originalLink != null && originalLink!.contains('/shorts/')) return true;
    final t = title.toLowerCase();
    final d = description.toLowerCase();
    return t.contains('#shorts') ||
        t.contains('#short') ||
        d.contains('#shorts') ||
        d.contains('#short') ||
        d.contains('/shorts/') ||
        d.contains('youtube.com/shorts');
  }

  String get watchUrl =>
      isShort ? 'https://www.youtube.com/shorts/$id'
               : 'https://www.youtube.com/watch?v=$id';

  /// Books (channelId == 'books' or 'verified_book') are not real YouTube
  /// videos — their `id` is a synthetic key like 'book_richest_man' or
  /// 'vbook_...', so constructing an img.youtube.com URL from it would
  /// always 404. Both kinds of book must use their own [thumbnailUrl]
  /// (which may be a network cover, a bundled asset path, or — for a
  /// verified_book with no cover source — empty, which BookCoverImage
  /// already renders as a graceful placeholder) everywhere a thumbnail is
  /// requested.
  bool get _isBookLike => channelId == 'books' || channelId == 'verified_book';

  String get thumbnailHd =>
      _isBookLike ? thumbnailUrl
                  : 'https://img.youtube.com/vi/$id/maxresdefault.jpg';
  String get thumbnailMq =>
      _isBookLike ? thumbnailUrl
                  : 'https://img.youtube.com/vi/$id/mqdefault.jpg';

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'channelId': channelId,
        'channelName': channelName,
        'publishedAt': publishedAt.toIso8601String(),
        'thumbnailUrl': thumbnailUrl,
        if (originalLink != null) 'originalLink': originalLink,
        if (freeSourceUrl != null) 'freeSourceUrl': freeSourceUrl,
        if (freeSourceType != null) 'freeSourceType': freeSourceType,
        if (sourceCategoryId != null) 'sourceCategoryId': sourceCategoryId,
      };

  factory Video.fromJson(Map<String, dynamic> json) => Video(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        channelId: json['channelId'] as String,
        channelName: json['channelName'] as String,
        publishedAt: DateTime.parse(json['publishedAt'] as String),
        thumbnailUrl: json['thumbnailUrl'] as String,
        originalLink: json['originalLink'] as String?,
        freeSourceUrl: json['freeSourceUrl'] as String?,
        freeSourceType: json['freeSourceType'] as String?,
        sourceCategoryId: json['sourceCategoryId'] as String?,
      );

  @override
  bool operator ==(Object other) => other is Video && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
