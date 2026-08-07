import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/notification_item.dart';

/// In-app notification inbox — persists notification history and exposes a
/// reactive unread count for badge widgets.
///
/// ## Cross-isolate design
/// The WorkManager background isolate has its own Dart heap — it cannot
/// call [instance] and mutate in-memory state. Instead it uses the static
/// helper [appendToPrefsStatic], writing directly to SharedPreferences.
/// The main isolate picks up those writes on the next [reload] call
/// (triggered when the app resumes or the Notifications screen opens).
///
/// ## Reactive badge
/// Subscribe to [unreadCount] with a [ValueListenableBuilder] — the badge
/// rebuilds only its own subtree, leaving the rest of the screen untouched.
class NotificationStore {
  NotificationStore._();
  static final NotificationStore instance = NotificationStore._();

  // ── Public state ──────────────────────────────────────────────────────────

  /// Drives the badge on the bell icon. 0 = no badge shown.
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  List<NotificationItem> _items = [];

  /// Newest-first snapshot of all persisted notifications.
  List<NotificationItem> get items => List.unmodifiable(_items);

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Load persisted state from disk.  Call once during app startup.
  Future<void> init() => reload();

  /// Re-read both the item list and the unread count from SharedPreferences.
  ///
  /// Must be called whenever the app resumes from background (the WorkManager
  /// isolate may have written new items while the app was suspended) and
  /// when [NotificationsScreen] opens (so the list is always fresh).
  Future<void> reload() async {
    final prefs = await SharedPreferences.getInstance();
    // Flush the in-memory cache so we see writes from other isolates.
    await prefs.reload();
    _loadFrom(prefs);
  }

  void _loadFrom(SharedPreferences prefs) {
    unreadCount.value = prefs.getInt(AppConfig.prefNotifUnreadCount) ?? 0;

    final raw = prefs.getString(AppConfig.prefInAppNotifications);
    if (raw == null) {
      _items = [];
      return;
    }
    _items = NotificationItem.listFromJson(raw)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  // ── Mutations (main isolate) ───────────────────────────────────────────────

  /// Mark every notification as read and reset the badge to zero.
  Future<void> markAllRead() async {
    if (unreadCount.value == 0 && _items.every((n) => n.isRead)) return;
    _items = _items.map((n) => n.copyWith(isRead: true)).toList();
    unreadCount.value = 0;
    await _persist();
  }

  /// Remove all notifications (user-initiated).
  Future<void> clearAll() async {
    _items = [];
    unreadCount.value = 0;
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(AppConfig.prefInAppNotifications),
      prefs.setInt(AppConfig.prefNotifUnreadCount, 0),
    ]);
  }

  Future<void> _persist() async {
    final toSave = _items.take(AppConfig.notifInboxMaxItems).toList();
    _items = toSave;
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(
        AppConfig.prefInAppNotifications,
        NotificationItem.listToJson(toSave),
      ),
      prefs.setInt(AppConfig.prefNotifUnreadCount, unreadCount.value),
    ]);
  }

  // ── Background-isolate write (static, no singleton state) ─────────────────

  /// Called by [NotificationService._showNotification] which runs in the
  /// WorkManager background isolate where the singleton cannot be reached.
  ///
  /// Appends one [NotificationItem] and increments the persisted unread count.
  /// The main isolate picks these up on the next [reload].
  static Future<void> appendToPrefsStatic({
    required SharedPreferences prefs,
    required String channelId,
    required String channelName,
    required String videoTitle,
    required String videoId,
  }) async {
    final now = DateTime.now();
    final item = NotificationItem(
      id: '${videoId}_${now.millisecondsSinceEpoch}',
      channelId: channelId,
      channelName: channelName,
      videoTitle: videoTitle,
      videoId: videoId,
      timestamp: now,
      isRead: false,
    );

    // Read existing list, prepend, cap at max
    final raw = prefs.getString(AppConfig.prefInAppNotifications);
    final existing = raw != null ? NotificationItem.listFromJson(raw) : <NotificationItem>[];
    final updated = [item, ...existing].take(AppConfig.notifInboxMaxItems).toList();

    // Increment persisted unread count
    final currentUnread = prefs.getInt(AppConfig.prefNotifUnreadCount) ?? 0;

    await Future.wait([
      prefs.setString(
        AppConfig.prefInAppNotifications,
        NotificationItem.listToJson(updated),
      ),
      prefs.setInt(AppConfig.prefNotifUnreadCount, currentUnread + 1),
    ]);
  }
}
