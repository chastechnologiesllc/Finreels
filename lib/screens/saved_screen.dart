import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/channel_data.dart';
import '../models/video.dart';
import '../providers/feed_provider.dart';
import '../services/ad_service.dart';
import '../theme/app_theme.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/no_flash_page_route.dart';
import '../widgets/video_card.dart';
import 'blog_reader_screen.dart';
import 'book_detail_screen.dart';
import 'video_player_screen.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  void _openVideo(Video video) {
    if (video.channelId == 'verified_book') {
      if ((video.freeSourceUrl ?? '').isEmpty) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BlogReaderScreen(
            url: video.freeSourceUrl!,
            title: video.title,
            categoryId: video.sourceCategoryId,
          ),
        ),
      );
      return;
    }
    if (video.channelId == 'books') {
      unawaited(AdService.instance.onVideoTapped());
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => BookDetailScreen(book: video)));
      return;
    }
    final channel = ChannelData.byId[video.channelId] ?? ChannelData.fallback;
    unawaited(AdService.instance.onVideoTapped());
    Navigator.push(
      context,
      NoFlashPageRoute(
          builder: (_) => VideoPlayerScreen(video: video, channel: channel)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FeedProvider>();
    final saved = provider.savedVideos;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
        actions: [
          if (saved.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClearAll(context, provider),
              child: const Text('Clear all',
                  style: TextStyle(color: AppTheme.error)),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: saved.isEmpty
                ? const _EmptySaved()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    itemCount: saved.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final video = saved[i];
                      final channel = ChannelData.byId[video.channelId] ??
                          ChannelData.fallback;
                      return VideoCard(
                        video: video,
                        channel: channel,
                        compact: true,
                        saved: true,
                        onTap: () => _openVideo(video),
                        onSave: () => provider.toggleSaved(video),
                        onShare: () => Share.share(
                            '${video.title}\n${video.watchUrl}'),
                      );
                    },
                  ),
          ),
          ListenableBuilder(
            listenable: AdService.instance,
            builder: (_, __) => AdService.instance.adsRemoved
                ? const SizedBox.shrink()
                : const LabelledBannerAd(),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearAll(
      BuildContext context, FeedProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all bookmarks?'),
        content: const Text(
            'This will remove all your saved videos permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear all',
                style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      for (final v in provider.savedVideos.toList()) {
        await provider.toggleSaved(v);
      }
    }
  }
}

class _EmptySaved extends StatelessWidget {
  const _EmptySaved();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_add_outlined,
                size: 64, color: AppTheme.textMuted(context)),
            const SizedBox(height: 20),
            Text('No bookmarks yet',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Tap the ⋮ menu on any video to bookmark it.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
