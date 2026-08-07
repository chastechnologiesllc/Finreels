import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

import '../models/video.dart';

/// Top-level function (required by compute()) — runs XML parsing on a
/// background isolate instead of the UI isolate. With 12 channels fetched
/// concurrently at app launch/refresh, parsing every feed's XML inline on
/// the main isolate is enough synchronous work to visibly jank the UI
/// thread, especially on lower-end devices. Moving it here removes that
/// entirely from the frame budget — the UI isolate is only ever handed the
/// already-parsed List<Video> result.
List<Video> _parseXmlIsolate(({String xml, String channelId}) args) {
  try {
    final entries = XmlDocument.parse(args.xml).findAllElements('entry');
    final videos  = <Video>[];

    for (final e in entries) {
      final rawId   = e.findElements('yt:videoId').firstOrNull?.innerText ?? '';
      final urnId   = _idFromUrnTopLevel(e.findElements('id').firstOrNull?.innerText ?? '');
      final videoId = rawId.isNotEmpty ? rawId : urnId;
      if (videoId.isEmpty) continue;

      final title = (e.findElements('title').firstOrNull?.innerText ?? '').trim();
      if (title.isEmpty || title == 'Private video' || title == 'Deleted video') continue;

      final channelName =
          e.findElements('author').firstOrNull
           ?.findElements('name').firstOrNull
           ?.innerText.trim() ?? '';

      final pubStr = e.findElements('published').firstOrNull?.innerText ?? '';
      final publishedAt = DateTime.tryParse(pubStr) ?? DateTime.now();

      final description =
          e.findElements('media:description').firstOrNull?.innerText.trim() ??
          e.findElements('summary').firstOrNull?.innerText.trim() ?? '';

      final thumbUrl =
          e.findElements('media:thumbnail').firstOrNull?.getAttribute('url') ??
          'https://img.youtube.com/vi/$videoId/mqdefault.jpg';

      // Shorts carry /shorts/ in the RSS link — most reliable signal.
      final originalLink = e
          .findElements('link')
          .where((n) => n.getAttribute('rel') == 'alternate')
          .firstOrNull
          ?.getAttribute('href');

      videos.add(Video(
        id:           videoId,
        title:        title,
        description:  description,
        channelId:    args.channelId,
        channelName:  channelName,
        publishedAt:  publishedAt,
        thumbnailUrl: thumbUrl,
        originalLink: originalLink,
      ));
    }
    return videos;
  } on Exception {
    return [];
  }
}

String _idFromUrnTopLevel(String urn) =>
    RegExp(r'yt:video:(.+)$').firstMatch(urn)?.group(1) ?? '';

/// YouTube RSS service — all 10 channels, no paid API.
///
/// Primary fix: channel IDs in channel_data.dart were wrong for 8 channels.
/// With correct IDs every fetch returns valid XML on the first attempt.
///
/// Additional robustness (for transient failures / rate-limit edge cases):
///  • Response is validated as XML before parsing (guards against HTML errors).
///  • Up to 3 retries with 0 / 1 500 / 5 000 ms backoff.
///  • Requests are staggered 200 ms apart (passed from FeedProvider) so
///    10 simultaneous app-launch requests never burst.
///  • SharedPreferences disk cache (30-min TTL) — app renders instantly
///    from last session on every launch after the first.
class RssService {
  RssService._();
  static final RssService instance = RssService._();

  static const Duration _cacheTtl = Duration(minutes: 30);
  static const String _kData = 'rss_v3_data_';
  static const String _kTs   = 'rss_v3_ts_';

  // In-memory session cache
  final Map<String, List<Video>> _mem   = {};
  final Map<String, DateTime>    _memTs = {};

  SharedPreferences? _prefs;
  Future<SharedPreferences> _getPrefs() async =>
      _prefs ??= await SharedPreferences.getInstance();

  // ── Public: instant read (called in init before any network) ─────────────────

  Future<List<Video>> getCached(String channelId) async {
    if (_isMemFresh(channelId)) return _mem[channelId]!;
    return _diskRead(channelId);
  }

  // ── Public: fetch with stagger ────────────────────────────────────────────────

  Future<List<Video>> fetchVideos(
    String channelId, {
    bool forceRefresh = false,
    int staggerMs = 0,
  }) async {
    if (!forceRefresh && _isMemFresh(channelId)) return _mem[channelId]!;

    if (!forceRefresh && await _isDiskFresh(channelId)) {
      final disk = await _diskRead(channelId);
      if (disk.isNotEmpty) {
        _setMem(channelId, disk);
        return disk;
      }
    }

    if (staggerMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: staggerMs));
    }

    final videos = await _fetchWithRetry(channelId);
    if (videos.isNotEmpty) {
      _setMem(channelId, videos);
      await _diskWrite(channelId, videos);
      return videos;
    }

    final stale = await _diskRead(channelId);
    return stale.isNotEmpty ? stale : (_mem[channelId] ?? []);
  }

  // ── Retry ─────────────────────────────────────────────────────────────────────

  Future<List<Video>> _fetchWithRetry(String channelId) async {
    // Three attempts: immediate, 600ms, 2000ms.
    // Faster than the old [0, 1500, 5000] schedule — YouTube's RSS is rarely
    // slow enough to need more than a 600ms pause before the second try.
    const delays = [0, 600, 2000];
    for (var i = 0; i < delays.length; i++) {
      if (delays[i] > 0) {
        await Future<void>.delayed(Duration(milliseconds: delays[i]));
      }
      final result = await _tryFetch(channelId);
      if (result != null) return result;
      debugPrint('[RssService] attempt ${i + 1} failed for $channelId');
    }
    return [];
  }

  // ── Single HTTP attempt ───────────────────────────────────────────────────────

  Future<List<Video>?> _tryFetch(String channelId) async {
    // Primary URL: channel_id param (works for all standard channels).
    // Fallback URL: playlist_id param using uploads playlist (UU prefix).
    final urls = [
      'https://www.youtube.com/feeds/videos.xml?channel_id=$channelId',
      'https://www.youtube.com/feeds/videos.xml?playlist_id=UU${channelId.substring(2)}',
    ];

    for (final url in urls) {
      try {
        final res = await http.get(Uri.parse(url), headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
          'Accept':
              'application/atom+xml,application/xml,text/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
        }).timeout(const Duration(seconds: 10));

        if (res.statusCode == 429) return null; // rate-limited — retry
        if (res.statusCode != 200) {
          debugPrint('[RssService] HTTP ${res.statusCode} for $channelId');
          continue;
        }

        final body = res.body.trim();
        if (!_looksLikeXml(body)) {
          debugPrint('[RssService] non-XML response for $channelId');
          continue;
        }

        return compute(_parseXmlIsolate, (xml: body, channelId: channelId));
      } on Exception catch (e) {
        debugPrint('[RssService] exception for $channelId: $e');
      }
    }
    return null;
  }

  bool _looksLikeXml(String body) =>
      body.startsWith('<?xml') ||
      body.startsWith('<feed') ||
      body.startsWith('<rss');

  // ── Memory cache ──────────────────────────────────────────────────────────────

  bool _isMemFresh(String id) =>
      _mem.containsKey(id) &&
      DateTime.now().difference(_memTs[id]!) < _cacheTtl;

  void _setMem(String id, List<Video> v) {
    _mem[id]   = v;
    _memTs[id] = DateTime.now();
  }

  // ── Disk cache ────────────────────────────────────────────────────────────────

  Future<bool> _isDiskFresh(String id) async {
    try {
      final prefs = await _getPrefs();
      final ts    = DateTime.tryParse(prefs.getString('$_kTs$id') ?? '');
      return ts != null && DateTime.now().difference(ts) < _cacheTtl;
    } on Exception catch (_) { return false; }
  }

  Future<List<Video>> _diskRead(String id) async {
    try {
      final prefs = await _getPrefs();
      final raw   = prefs.getString('$_kData$id');
      if (raw == null) return [];
      return (json.decode(raw) as List)
          .map((m) => Video.fromJson(m as Map<String, dynamic>))
          .toList();
    } on Exception catch (_) { return []; }
  }

  Future<void> _diskWrite(String id, List<Video> videos) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(
          '$_kData$id', json.encode(videos.map((v) => v.toJson()).toList()));
      await prefs.setString('$_kTs$id', DateTime.now().toIso8601String());
    } on Exception catch (e) {
      debugPrint('[RssService] disk write error: $e');
    }
  }

  Future<void> clearCache([String? channelId]) async {
    final prefs = await _getPrefs();
    if (channelId != null) {
      _mem.remove(channelId); _memTs.remove(channelId);
      await prefs.remove('$_kData$channelId');
      await prefs.remove('$_kTs$channelId');
    } else {
      _mem.clear(); _memTs.clear();
      for (final k in prefs.getKeys()
          .where((k) => k.startsWith(_kData) || k.startsWith(_kTs))) {
        await prefs.remove(k);
      }
    }
  }
}
