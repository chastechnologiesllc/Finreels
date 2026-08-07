import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../data/channel_data.dart';
import '../models/video.dart';
import '../providers/feed_provider.dart';
import '../services/ad_service.dart';
import '../theme/app_theme.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/no_flash_page_route.dart';
import '../widgets/shimmer_loader.dart';
import 'shorts_player_screen.dart';

/// Shorts tab — full-screen vertical PageView player on tap.
class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  int _tapCount = 0;

  void _openShorts(List<Video> shorts, int index) {
    _tapCount++;
    if (_tapCount % AppConfig.interstitialEveryNChannelsPage == 0) {
      unawaited(AdService.instance.showInterstitial());
    }
    Navigator.push(
      context,
      NoFlashPageRoute(
        builder: (_) => ShortsPlayerScreen(
          shorts: shorts,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FeedProvider>();

    // Use the canonical Video.isShort getter (checks /shorts/ URL path and
    // #shorts hashtag) — the same logic used by FeedProvider's shorts tab and
    // channel_videos_screen. Previously this screen had its own heuristic
    // (title.length < 28 + keyword matching) which produced a different set.
    final shorts = provider.channels
        .expand((ch) => provider.getVideosFor(ch.id))
        .where((v) => v.isShort)
        .toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shorts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => provider.refresh(force: true),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildGrid(context, shorts, provider.state)),
          ListenableBuilder(
            listenable: AdService.instance,
            builder: (_, __) => AdService.instance.adsRemoved
                ? const SizedBox.shrink()
                : LabelledBannerAd(fixedSize: AdSize.mediumRectangle),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(
      BuildContext context, List<Video> shorts, FeedState state) {
    if (state == FeedState.loading && shorts.isEmpty) {
      return const ShimmerLoader(count: 6);
    }
    if (shorts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.video_library_outlined,
                size: 56, color: AppTheme.textMuted(context)),
            const SizedBox(height: 16),
            Text('No shorts yet — pull to refresh',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.gold,
      onRefresh: () => context.read<FeedProvider>().refresh(force: true),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 110),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 9 / 16,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: shorts.length,
        itemBuilder: (context, i) {
          final video = shorts[i];
          final channel =
              ChannelData.byId[video.channelId] ?? ChannelData.fallback;
          return RepaintBoundary(
            child: _ShortCard(
              video: video,
              channelColor: channel.accentColor,
              onTap: () => _openShorts(shorts, i),
            ),
          );
        },
      ),
    );
  }
}

class _ShortCard extends StatelessWidget {
  final Video video;
  final Color channelColor;
  final VoidCallback onTap;

  const _ShortCard({
    required this.video,
    required this.channelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: video.thumbnailMq,
              fit: BoxFit.cover,
              memCacheWidth: 360,
              memCacheHeight: 640,
              errorWidget: (_, __, ___) => ColoredBox(
                color: AppTheme.surfaceElevated(context),
                child: Center(
                  child: Icon(Icons.play_circle_outline_rounded,
                      color: AppTheme.textMuted(context), size: 36),
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                  stops: [0.45, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(height: 3, color: channelColor),
            ),
            const Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 28),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
