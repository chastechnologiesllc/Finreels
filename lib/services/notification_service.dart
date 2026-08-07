import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../data/channel_data.dart';
import '../data/resource_category_data.dart';
import 'notification_store.dart';
import 'rss_service.dart';
import 'user_profile_service.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ── Init ────────────────────────────────────────────────────────────────────
  Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onTap,
    );

    // ── Cold-start deep link ────────────────────────────────────────────────
    // onDidReceiveNotificationResponse (above) only reliably fires while the
    // app process is alive — foreground, or backgrounded but not killed.
    // When the app was FULLY TERMINATED and the user taps a notification to
    // launch it fresh, that tap is instead surfaced via
    // getNotificationAppLaunchDetails(), a completely separate API. Without
    // this check, a cold-start notification tap would open the app normally
    // but never navigate to the video — this was the root cause of
    // notifications "sometimes" not going straight to the video.
    try {
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        final payload = launchDetails!.notificationResponse?.payload;
        if (payload != null) {
          final data = json.decode(payload) as Map<String, dynamic>;
          final videoId = data['videoId'] as String?;
          if (videoId != null) pendingVideoId = videoId;
        }
      }
    } on Exception catch (_) {
      // Malformed payload or platform quirk — fail silently, app still opens.
    }

    // Create Android notification channel
    const channel = AndroidNotificationChannel(
      AppConfig.notifChannelId,
      AppConfig.notifChannelName,
      description: AppConfig.notifChannelDesc,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  // ── Permission Request ──────────────────────────────────────────────────────
  Future<bool> requestPermission() async {
    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      return await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      return await androidPlugin.requestNotificationsPermission() ?? false;
    }
    return false;
  }

  // ── Core Check — called from WorkManager background task ────────────────────
  /// Fetches all channels, compares with last-seen video IDs, fires
  /// a notification for any new ones.
  static Future<void> checkAndNotifyNewVideos() async {
    final prefs = await SharedPreferences.getInstance();
    final notifEnabled =
        prefs.getBool(AppConfig.prefNotificationsEnabled) ?? true;
    if (!notifEnabled) return;

    final plugin = FlutterLocalNotificationsPlugin();
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await plugin.initialize(
        const InitializationSettings(
            android: androidSettings, iOS: iosSettings));

    var notifId = AppConfig.notifIdBase;

    // Hard caps that keep notifications polite:
    //  • 1 per channel per run — the most-recent new video only. Firing 3
    //    notifications for the same channel in one background pass is spam;
    //    the user sees the full new-video count inside the in-app inbox.
    //  • 3 total per run — prevents flooding the tray when many channels
    //    all publish on the same day. The in-app inbox shows everything.
    const maxNotifsPerRun = 3;
    var totalFired = 0;

    // This runs in WorkManager's own separate isolate (see
    // background_service.dart) — a completely fresh Dart heap, so these
    // singletons start unloaded here even though they're already loaded in
    // the main app isolate. Both reads are cheap (local JSON/SharedPreferences),
    // and eagerFor() below is what keeps this background check from
    // fetching every verified channel across all 60 categories instead of
    // just the general set + whatever this person actually selected.
    await ResourceCategoryData.load();
    await UserProfileService.instance.init();
    // Deduplicate by channel ID — eagerFor() operates on the fixed deduped
    // combined list, but this guard prevents duplicate background RSS fetches
    // even if the channel list grows or the combined dedup is bypassed.
    final seenNotifIds = <String>{};
    final channelsToCheck = ChannelData.eagerFor(
      UserProfileService.instance.selectedCategoryIds,
    ).where((c) => c.id.isNotEmpty && seenNotifIds.add(c.id)).toList();

    for (final channel in channelsToCheck) {
      // Stop once we've hit the per-run cap — remaining channels' new
      // videos are still persisted in last-seen so they won't re-trigger
      // on the next background pass.
      if (totalFired >= maxNotifsPerRun) break;

      try {
        // forceRefresh: true — this background task's entire purpose is to
        // detect NEW uploads. Serving a cached (possibly 30-min-old) list
        // here could miss a video that just went live, since the in-memory/
        // disk cache wouldn't know about it yet.
        final videos =
            await RssService.instance.fetchVideos(channel.id, forceRefresh: true);
        if (videos.isEmpty) continue;

        final lastSeenKey = '${AppConfig.prefLastSeenVideos}${channel.id}';
        final lastSeenRaw = prefs.getStringList(lastSeenKey) ?? [];
        final lastSeenIds = lastSeenRaw.toSet();

        // New videos = those not in the last-seen set, newest first.
        final newVideos =
            videos.where((v) => !lastSeenIds.contains(v.id)).toList();

        if (newVideos.isNotEmpty && lastSeenIds.isNotEmpty) {
          // One notification per channel per run — the most recent new
          // video only. The in-app inbox stores all new items regardless.
          await _showNotification(
            plugin: plugin,
            prefs: prefs,
            id: notifId++,
            channelId: channel.id,
            channelName: channel.name,
            videoTitle: newVideos.first.title,
            videoId: newVideos.first.id,
          );
          totalFired++;
        }

        // Update last-seen with current video IDs (keep latest 30).
        // Done regardless of whether a notification was fired — this
        // prevents already-seen videos from triggering again next run.
        final currentIds = videos.take(30).map((v) => v.id).toList();
        await prefs.setStringList(lastSeenKey, currentIds);
      } on Exception catch (_) {
        // Don't crash the background task on individual channel failures.
      }
    }
  }

  static Future<void> _showNotification({
    required FlutterLocalNotificationsPlugin plugin,
    required SharedPreferences prefs,
    required int id,
    required String channelId,
    required String channelName,
    required String videoTitle,
    required String videoId,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      AppConfig.notifChannelId,
      AppConfig.notifChannelName,
      channelDescription: AppConfig.notifChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(''),
    );
    const iosDetails = DarwinNotificationDetails();
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    // Fire the OS notification
    await plugin.show(
      id,
      '🎬 New from $channelName',
      videoTitle,
      details,
      payload: json.encode({'videoId': videoId}),
    );

    // Persist to the in-app notification inbox so the bell badge and inbox
    // screen stay in sync. Uses the static helper because this runs in the
    // WorkManager background isolate — no singleton state available here.
    await NotificationStore.appendToPrefsStatic(
      prefs: prefs,
      channelId: channelId,
      channelName: channelName,
      videoTitle: videoTitle,
      videoId: videoId,
    );
  }

  void _onTap(NotificationResponse response) {
    // Deep-link handling: parse payload and navigate
    // Navigation is handled in main.dart via a global key
    if (response.payload != null) {
      try {
        final data = json.decode(response.payload!) as Map<String, dynamic>;
        final videoId = data['videoId'] as String?;
        if (videoId != null) {
          // Store pending deep link; picked up by main shell on next build
          pendingVideoId = videoId;
        }
      } on Exception catch (_) {}
    }
  }

  static String? pendingVideoId;

  bool get isInitialized => _initialized;
// ── Notification preference ───────────────────────────────────────────────
  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConfig.prefNotificationsEnabled) ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConfig.prefNotificationsEnabled, enabled);
  }
}
