import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/channel_data.dart';
import '../models/video.dart';
import '../providers/feed_provider.dart';
import '../screens/video_player_screen.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/no_flash_page_route.dart';
import 'channels_screen.dart';
import 'home_screen.dart';
import 'saved_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _screens = [
    HomeScreen(),
    ChannelsScreen(),
    SavedScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Handles cold-launch deep link (app was not running when notif was tapped).
    WidgetsBinding.instance.addPostFrameCallback((_) => _handlePendingDeepLink());
  }

  /// Full deep-link handler. Works for both cold and warm launches.
  ///
  /// Four guarantees:
  /// 1. Waits for [NotificationService.pendingVideoId] to be set, since
  ///    NotificationService.init() now runs in the background (fire-and-
  ///    forget, for fast startup) and may not have resolved the cold-start
  ///    launch details the instant this widget first builds.
  /// 2. Waits for the feed to be populated before searching (cold-launch safe).
  /// 3. Looks up the [Channel] for the video before pushing (avoids compile crash).
  /// 4. Consumes [pendingVideoId] immediately so it never fires twice.
  Future<void> _handlePendingDeepLink() async {
    if (!mounted) return;

    // ── Wait for the deep link itself ───────────────────────────────────────
    // NotificationService.init() (which performs the cold-start launch-
    // detail lookup) is fire-and-forget from app startup for speed — it may
    // genuinely still be running when MainShell first builds. Poll briefly
    // rather than checking once and giving up.
    const dlMaxWaitMs = 5000;
    const dlPollMs    = 100;
    var   dlWaited    = 0;
    while (NotificationService.pendingVideoId == null && dlWaited < dlMaxWaitMs) {
      await Future<void>.delayed(const Duration(milliseconds: dlPollMs));
      dlWaited += dlPollMs;
      if (!mounted) return;
    }

    final videoId = NotificationService.pendingVideoId;
    if (videoId == null || !mounted) return;
    NotificationService.pendingVideoId = null; // consume immediately

    final provider = context.read<FeedProvider>();

    // ── Wait for feed data ─────────────────────────────────────────────────
    // On a cold launch the provider may not have data yet (disk cache + network
    // fetch are still in progress). Poll every 200 ms for up to 8 seconds.
    const maxWaitMs  = 8000;
    const pollMs     = 200;
    var   waited     = 0;
    while (provider.allVideos.every((tab) => tab.isEmpty) && waited < maxWaitMs) {
      await Future<void>.delayed(const Duration(milliseconds: pollMs));
      waited += pollMs;
      if (!mounted) return;
    }

    // ── Search every tab for the video ────────────────────────────────────
    Video? video;
    for (final tab in provider.allVideos) {
      try {
        video = tab.firstWhere((v) => v.id == videoId);
        break;
      } on StateError {
        continue;
      }
    }

    if (video == null || !mounted) return;

    // ── Look up the channel (required by VideoPlayerScreen) ───────────────
    final channel = ChannelData.byId[video.channelId] ?? ChannelData.fallback;

    // Switch to Feed tab then push the video player
    setState(() => _index = 0);
    await Navigator.of(context).push(
      NoFlashPageRoute(
        builder: (_) => VideoPlayerScreen(video: video!, channel: channel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Warm-launch: app was already running when notification was tapped.
    if (NotificationService.pendingVideoId != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _handlePendingDeepLink());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Full screen content — visible behind the floating nav
          IndexedStack(index: _index, children: _screens),

          // Floating bottom nav
          Positioned(
            bottom: 16,
            left: 20,
            right: 20,
            child: _FloatingNavBar(
              currentIndex: _index,
              isDark: isDark,
              onTap: (i) => setState(() => _index = i),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Floating Nav Bar ──────────────────────────────────────────────────────────
class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final bool isDark;
  final ValueChanged<int> onTap;

  const _FloatingNavBar({
    required this.currentIndex,
    required this.isDark,
    required this.onTap,
  });

  static const _items = [
    (Icons.home_outlined,    Icons.home_rounded,              'Feed'),
    (Icons.play_circle_outline_rounded, Icons.play_circle_rounded, 'Shorts'),
    (Icons.bookmark_outline_rounded,    Icons.bookmark_rounded,    'Saved'),
    (Icons.settings_outlined,           Icons.settings_rounded,    'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A1A1A).withValues(alpha: 0.96)
            : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_items.length, (i) {
          final item = _items[i];
          final isActive = i == currentIndex;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isActive ? item.$2 : item.$1,
                      key: ValueKey(isActive),
                      color: isActive
                          ? AppTheme.gold
                          : (isDark
                              ? AppTheme.darkTextMuted
                              : AppTheme.lightTextMuted),
                      size: isActive ? 26 : 24,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.$3,
                    style: TextStyle(
                      color: isActive
                          ? AppTheme.gold
                          : (isDark
                              ? AppTheme.darkTextMuted
                              : AppTheme.lightTextMuted),
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
