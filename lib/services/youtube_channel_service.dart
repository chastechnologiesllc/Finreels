import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/video.dart';

/// Augments YouTube's official Atom feed, which is intentionally limited to
/// the newest 15 uploads, with the channel's public Videos page and—on native
/// builds—the public web client's continuation endpoint.
///
/// The service never invents video IDs or searches by title. Every returned
/// record must come from a YouTube video renderer tied to the requested
/// channel, and records are deduplicated by video ID.
class YoutubeChannelService {
  YoutubeChannelService._();
  static final YoutubeChannelService instance = YoutubeChannelService._();

  static const _webClientVersion = '2.20260819.01.00';
  static const _historyPageLimit = 12;
  static const _historyItemLimit = 300;

  Future<List<Video>> fetchHistory(
    String channelId, {
    required List<Video> seed,
  }) async {
    if (channelId.isEmpty) return seed;

    final result = <String, Video>{
      for (final video in seed) video.id: video,
    };

    final pageUrl = 'https://www.youtube.com/channel/$channelId/videos';
    final page = await _getText(pageUrl);
    if (page == null || page.isEmpty) return result.values.toList();

    final apiKey = RegExp('"INNERTUBE_API_KEY":"([^"]+)"')
        .firstMatch(page)
        ?.group(1);
    final clientVersion = RegExp('"INNERTUBE_CLIENT_VERSION":"([^"]+)"')
            .firstMatch(page)
            ?.group(1) ??
        _webClientVersion;

    _extractVideoRenderers(page, channelId, result);
    if (result.length >= _historyItemLimit || kIsWeb || apiKey == null) {
      return result.values.toList();
    }

    var continuation = _extractContinuation(page);
    var pages = 0;
    while (continuation != null && pages < _historyPageLimit && result.length < _historyItemLimit) {
      final response = await _postContinuation(
        apiKey: apiKey,
        clientVersion: clientVersion,
        continuation: continuation,
      );
      if (response == null) break;
      _extractVideoRenderers(response, channelId, result);
      continuation = _extractContinuation(response);
      pages++;
    }
    return result.values.toList();
  }

  Future<String?> _getText(String url) async {
    if (kIsWeb) {
      final encoded = Uri.encodeComponent(url);
      final proxyUrls = [
        'https://corsproxy.io/?url=$encoded',
        'https://api.allorigins.win/raw?url=$encoded',
      ];
      for (final proxy in proxyUrls) {
        try {
          final response = await http.get(Uri.parse(proxy)).timeout(
                const Duration(seconds: 14),
              );
          if (response.statusCode == 200 && response.body.length > 100) {
            return response.body;
          }
        } on Object catch (_) {}
      }
      return null;
    }

    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Rumuo/1.0 (+com.chastechgroup.rumuo)',
        'Accept': 'text/html,application/xhtml+xml',
      }).timeout(const Duration(seconds: 12));
      return response.statusCode == 200 ? response.body : null;
    } on Object catch (_) {
      return null;
    }
  }

  Future<String?> _postContinuation({
    required String apiKey,
    required String clientVersion,
    required String continuation,
  }) async {
    final url = Uri.parse('https://www.youtube.com/youtubei/v1/browse?key=$apiKey');
    final payload = jsonEncode({
      'context': {
        'client': {
          'clientName': 'WEB',
          'clientVersion': clientVersion,
          'hl': 'en',
          'gl': 'US',
        },
      },
      'continuation': continuation,
    });
    try {
      final response = await http.post(url, headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Rumuo/1.0 (+com.chastechgroup.rumuo)',
      }, body: payload).timeout(const Duration(seconds: 14));
      return response.statusCode == 200 ? response.body : null;
    } on Object catch (_) {
      return null;
    }
  }

  void _extractVideoRenderers(
      String body, String channelId, Map<String, Video> output) {
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on Object catch (_) {
      // The initial HTML embeds ytInitialData as JavaScript rather than raw
      // JSON. Extract renderer objects directly from that text instead.
      _extractVideoObjectsFromText(body, channelId, output);
      return;
    }
    _walk(decoded, channelId, output);
  }

  void _extractVideoObjectsFromText(
      String body, String channelId, Map<String, Video> output) {
    final pattern = RegExp(
      r'"videoId":"([\w-]{11})"[^{}]{0,2500}?"title":\{"runs":\[\{"text":"((?:\\.|[^"\\])*)"',
    );
    for (final match in pattern.allMatches(body)) {
      final id = match.group(1)!;
      final title = _decodeJsonString(match.group(2)!);
      if (title.isEmpty) continue;
      output.putIfAbsent(
        id,
        () => Video(
          id: id,
          title: title,
          description: '',
          channelId: channelId,
          channelName: '',
          publishedAt: DateTime.fromMillisecondsSinceEpoch(0),
          thumbnailUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
          originalLink: 'https://www.youtube.com/watch?v=$id',
        ),
      );
    }
  }

  void _walk(dynamic node, String channelId, Map<String, Video> output) {
    if (node is Map) {
      final videoId = node['videoId'];
      final title = _textValue(node['title']);
      if (videoId is String && videoId.length == 11 && title.isNotEmpty) {
        final thumbnailNode = node['thumbnail'];
        final thumbs = thumbnailNode is Map ? thumbnailNode['thumbnails'] : null;
        final thumbUrl = thumbs is List && thumbs.isNotEmpty && thumbs.last is Map
            ? (thumbs.last as Map)['url']?.toString()
            : null;
        final navigation = node['navigationEndpoint'];
        final commandMetadata = navigation is Map ? navigation['commandMetadata'] : null;
        final webMetadata = commandMetadata is Map ? commandMetadata['webCommandMetadata'] : null;
        final webUrl = webMetadata is Map ? webMetadata['url']?.toString() ?? '' : '';
        final isShort = node.containsKey('reelItemRenderer') || webUrl.contains('/shorts/');
        output.putIfAbsent(
          videoId,
          () => Video(
            id: videoId,
            title: title,
            description: _textValue(node['descriptionSnippet']),
            channelId: channelId,
            channelName: '',
            publishedAt: DateTime.fromMillisecondsSinceEpoch(0),
            thumbnailUrl: thumbUrl ?? 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
            originalLink: isShort
                ? 'https://www.youtube.com/shorts/$videoId'
                : 'https://www.youtube.com/watch?v=$videoId',
          ),
        );
      }
      for (final value in node.values) {
        _walk(value, channelId, output);
      }
    } else if (node is List) {
      for (final value in node) {
        _walk(value, channelId, output);
      }
    }
  }

  String _textValue(dynamic value) {
    if (value is Map) {
      final simple = value['simpleText'];
      if (simple is String) return simple.trim();
      final runs = value['runs'];
      if (runs is List) {
        return runs
            .map((run) => run is Map ? run['text']?.toString() ?? '' : '')
            .join()
            .trim();
      }
    }
    return '';
  }

  String? _extractContinuation(String body) {
    final match = RegExp(r'"continuationCommand":\{"token":"([^"]+)"')
        .firstMatch(body);
    return match?.group(1);
  }

  String _decodeJsonString(String value) {
    try {
      return jsonDecode('"$value"').toString().trim();
    } on Object catch (_) {
      return value.replaceAll(r'\"', '"').trim();
    }
  }
}
