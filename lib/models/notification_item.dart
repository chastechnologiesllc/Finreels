import 'dart:convert';

/// A single in-app notification record persisted to SharedPreferences.
///
/// Created whenever the WorkManager background task fires an OS notification
/// for a new video. Survives process death — the background isolate writes
/// straight to SharedPreferences; the main isolate reads it back on the
/// next [NotificationStore.reload] call.
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.channelId,
    required this.channelName,
    required this.videoTitle,
    required this.videoId,
    required this.timestamp,
    required this.isRead,
  });

  /// Unique key: videoId + timestamp millis.  Prevents duplicates even when
  /// the same video triggers a notification across multiple background runs.
  final String id;
  final String channelId;
  final String channelName;
  final String videoTitle;
  final String videoId;
  final DateTime timestamp;
  final bool isRead;

  NotificationItem copyWith({bool? isRead}) => NotificationItem(
        id: id,
        channelId: channelId,
        channelName: channelName,
        videoTitle: videoTitle,
        videoId: videoId,
        timestamp: timestamp,
        isRead: isRead ?? this.isRead,
      );

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'channelId': channelId,
        'channelName': channelName,
        'videoTitle': videoTitle,
        'videoId': videoId,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'isRead': isRead,
      };

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        id: json['id'] as String,
        channelId: json['channelId'] as String,
        channelName: json['channelName'] as String,
        videoTitle: json['videoTitle'] as String,
        videoId: json['videoId'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          json['timestamp'] as int,
        ),
        isRead: (json['isRead'] as bool?) ?? false,
      );

  /// Deserialise a JSON array string — returns empty list on malformed input.
  static List<NotificationItem> listFromJson(String raw) {
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on Object {
      return [];
    }
  }

  static String listToJson(List<NotificationItem> items) =>
      json.encode(items.map((e) => e.toJson()).toList());
}
