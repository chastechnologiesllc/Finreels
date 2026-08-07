import 'dart:async';

import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../data/channel_data.dart';
import '../models/notification_item.dart';
import '../services/notification_service.dart';
import '../services/notification_store.dart';
import '../theme/app_theme.dart';
import 'notification_settings_screen.dart';

/// Facebook-style notification inbox.
///
/// Shows a reverse-chronological list of every in-app notification fired
/// by the background RSS checker.  Opening this screen marks all items as
/// read and resets the bell badge to zero.  Tapping an item deep-links to
/// the video by setting [NotificationService.pendingVideoId] and popping
/// back to [MainShell], which picks it up on the next build.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAndMarkRead();
  }

  Future<void> _loadAndMarkRead() async {
    // Always reload from disk — the background isolate may have written new
    // items since the last in-memory snapshot.
    await NotificationStore.instance.reload();
    final items = List<NotificationItem>.from(NotificationStore.instance.items);
    // Mark everything read & clear the badge AFTER we grab the list so the
    // UI still shows which items were unread during this session.
    await NotificationStore.instance.markAllRead();
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  Future<void> _clearAll() async {
    await NotificationStore.instance.clearAll();
    if (mounted) setState(() => _items = []);
  }

  void _onItemTap(NotificationItem item) {
    // Hand the video ID to the deep-link handler in MainShell and step back.
    NotificationService.pendingVideoId = item.videoId;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor(context),
      appBar: _buildAppBar(context),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.gold))
          : _items.isEmpty
              ? _EmptyState()
              : _NotificationList(
                  items: _items,
                  onTap: _onItemTap,
                ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.bgColor(context),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_rounded,
            size: 20, color: AppTheme.textColor(context)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Notifications',
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      actions: [
        // Clear-all button — only visible when there's something to clear
        if (_items.isNotEmpty)
          TextButton(
            onPressed: _clearAll,
            child: Text(
              'Clear all',
              style: TextStyle(
                color: AppTheme.textMuted(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        // Settings gear → notification toggle + OS permission
        IconButton(
          icon: Icon(Icons.settings_outlined,
              color: AppTheme.textMuted(context), size: 22),
          tooltip: 'Notification settings',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const NotificationSettingsScreen(),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Notification list ──────────────────────────────────────────────────────────

class _NotificationList extends StatelessWidget {
  final List<NotificationItem> items;
  final void Function(NotificationItem) onTap;

  const _NotificationList({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 100),
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(
        height: 0,
        thickness: 0.5,
        color: AppTheme.dividerColor(context),
        indent: 72,
      ),
      itemBuilder: (context, i) =>
          _NotificationTile(item: items[i], onTap: onTap),
    );
  }
}

// ── Single notification tile ───────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final void Function(NotificationItem) onTap;

  const _NotificationTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final channel   = ChannelData.byId[item.channelId];
    final accentColor = channel?.accentColor ?? AppTheme.gold;

    // Unread items get a subtle tinted background — identical to Facebook/Gmail
    final tileBg = item.isRead
        ? Colors.transparent
        : (isDark
            ? AppTheme.gold.withValues(alpha: 0.06)
            : AppTheme.gold.withValues(alpha: 0.05));

    return InkWell(
      onTap: () => onTap(item),
      child: Container(
        color: tileBg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Channel icon ──────────────────────────────────────────────
            _ChannelAvatar(accentColor: accentColor),
            const SizedBox(width: 14),

            // ── Text block ────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // "ChannelName posted a new video"
                  RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textColor(context),
                            height: 1.4,
                          ),
                      children: [
                        TextSpan(
                          text: item.channelName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(text: ' posted a new video'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Video title
                  Text(
                    item.videoTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary(context),
                          height: 1.35,
                        ),
                  ),
                  const SizedBox(height: 5),
                  // Relative timestamp
                  Text(
                    timeago.format(item.timestamp),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: item.isRead
                              ? AppTheme.textMuted(context)
                              : AppTheme.gold,
                          fontWeight: item.isRead
                              ? FontWeight.w400
                              : FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),

            // ── Unread dot (right side, like Facebook) ────────────────────
            if (!item.isRead) ...[
              const SizedBox(width: 10),
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 5),
                decoration: const BoxDecoration(
                  color: AppTheme.gold,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Channel avatar ─────────────────────────────────────────────────────────────

class _ChannelAvatar extends StatelessWidget {
  final Color accentColor;
  const _ChannelAvatar({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.play_circle_fill_rounded,
          color: accentColor,
          size: 24,
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor(context),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.dividerColor(context)),
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 38,
                color: AppTheme.textMuted(context),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'All caught up!',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'New video alerts will appear here when your followed channels post.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary(context),
                    height: 1.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
