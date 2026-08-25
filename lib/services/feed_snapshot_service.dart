import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/video.dart';

/// Loads the last source-verified public-feed snapshot bundled with the app.
///
/// Live feeds remain the primary source. The snapshot is a deterministic,
/// same-origin Web fallback for static deployments where browser CORS or a
/// third-party proxy is unavailable, and is also useful for a fast first paint
/// on native devices while live requests are retried.
class FeedSnapshotService {
  FeedSnapshotService._();
  static final FeedSnapshotService instance = FeedSnapshotService._();

  static const _assetPath = 'assets/data/feed_snapshot.json';
  Map<String, dynamic>? _snapshot;
  Future<Map<String, dynamic>>? _loadInFlight;

  Future<Map<String, dynamic>> _load() {
    final cached = _snapshot;
    if (cached != null) return Future.value(cached);
    final existing = _loadInFlight;
    if (existing != null) return existing;

    final future = rootBundle.loadString(_assetPath).then((raw) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _snapshot = decoded;
        return decoded;
      }
      return <String, dynamic>{};
    }).catchError((_) => <String, dynamic>{});
    _loadInFlight = future;
    return future;
  }

  Future<List<Video>> channelVideos(String channelId) async {
    final snapshot = await _load();
    final channels = snapshot['channels'];
    if (channels is! Map) return const [];
    final rawVideos = channels[channelId];
    if (rawVideos is! List) return const [];
    return rawVideos
        .whereType<Map>()
        .map((raw) => _videoFromSnapshot(raw, channelId))
        .whereType<Video>()
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> blogArticles() async {
    final snapshot = await _load();
    final blogs = snapshot['blogs'];
    if (blogs is! List) return const [];
    return blogs
        .whereType<Map>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .toList(growable: false);
  }

  void clearMemory() {
    _snapshot = null;
    _loadInFlight = null;
  }

  static Video? _videoFromSnapshot(Map raw, String channelId) {
    try {
      final map = Map<String, dynamic>.from(raw);
      map['channelId'] = (map['channelId'] as String?)?.trim().isNotEmpty == true
          ? map['channelId']
          : channelId;
      map['channelName'] = (map['channelName'] as String?)?.trim().isNotEmpty == true
          ? map['channelName']
          : channelId;
      map['description'] = map['description'] as String? ?? '';
      map['thumbnailUrl'] = map['thumbnailUrl'] as String? ?? '';
      return Video.fromJson(map);
    } on Object catch (_) {
      return null;
    }
  }
}
