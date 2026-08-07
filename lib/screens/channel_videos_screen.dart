import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/channel.dart';
import '../models/video.dart';
import '../services/ad_service.dart';
import '../services/rss_service.dart';
import '../theme/app_theme.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/no_flash_page_route.dart';
import 'shorts_player_screen.dart';
import 'video_player_screen.dart';

/// YouTube-style channel page — two tabs: Videos and Shorts for one channel.
class ChannelVideosScreen extends StatefulWidget {
  final Channel channel;
  const ChannelVideosScreen({required this.channel, super.key});

  @override
  State<ChannelVideosScreen> createState() => _ChannelVideosScreenState();
}

class _ChannelVideosScreenState extends State<ChannelVideosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Video> _all = [];
  bool _loading = true;

  List<Video> get _videos => _all.where((v) => !v.isShort).toList();
  List<Video> get _shorts => _all.where((v) => v.isShort).toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _loading = true);
    final videos = await RssService.instance
        .fetchVideos(widget.channel.id, forceRefresh: force);
    if (mounted) setState(() { _all = videos; _loading = false; });
  }

  void _openVideo(Video video) {
    unawaited(AdService.instance.onContentTapped());
    Navigator.push(context, NoFlashPageRoute(
      builder: (_) => VideoPlayerScreen(video: video, channel: widget.channel),
    ));
  }

  void _openShort(int index) {
    unawaited(AdService.instance.onContentTapped());
    Navigator.push(context, NoFlashPageRoute(
      builder: (_) => ShortsPlayerScreen(shorts: _shorts, initialIndex: index),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor(context),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            // Enough room for avatar + name + focus line above the tab bar.
            expandedHeight: 188,
            pinned: true,
            backgroundColor: AppTheme.bgColor(context),
            flexibleSpace: FlexibleSpaceBar(
              background: _ChannelHeader(channel: widget.channel),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.gold,
                labelColor: AppTheme.gold,
                unselectedLabelColor: AppTheme.textMuted(context),
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: [
                  Tab(text: 'Videos (${_loading ? "…" : _videos.length})'),
                  Tab(text: 'Shorts (${_loading ? "…" : _shorts.length})'),
                ],
              ),
            ),
          ),
        ],
        body: _loading
            ? _buildShimmer(context)
            : TabBarView(
                controller: _tabController,
                children: [
                  _VideosList(videos: _videos, channel: widget.channel,
                      onTap: _openVideo, onRefresh: () => _load(force: true)),
                  _ShortsGrid(shorts: _shorts, channel: widget.channel,
                      onTap: _openShort, onRefresh: () => _load(force: true)),
                ],
              ),
      ),
      bottomNavigationBar:
          ListenableBuilder(
            listenable: AdService.instance,
            builder: (_, __) => AdService.instance.adsRemoved
                ? const SizedBox.shrink()
                : const LabelledBannerAd(),
          ),
    );
  }

  Widget _buildShimmer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE8E8E8),
      highlightColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(height: 90,
            decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(12))),
      ),
    );
  }
}

class _ChannelHeader extends StatelessWidget {
  final Channel channel;
  const _ChannelHeader({required this.channel});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            channel.accentColor.withValues(alpha: 0.3),
            AppTheme.bgColor(context),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          // Bottom inset clears the pinned TabBar (~48px) so the focus/
          // description line never paints under "Videos" / "Shorts".
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 56),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: channel.accentColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: channel.accentColor.withValues(alpha: 0.5),
                      width: 2),
                ),
                child: Center(
                  child: Text(channel.initials,
                      style: TextStyle(
                          color: channel.accentColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 18)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      channel.focus,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMuted(context),
                            height: 1.25,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideosList extends StatelessWidget {
  final List<Video> videos;
  final Channel channel;
  final void Function(Video) onTap;
  final Future<void> Function() onRefresh;

  const _VideosList({required this.videos, required this.channel,
      required this.onTap, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) {
      return Center(child: Text('No videos yet',
          style: Theme.of(context).textTheme.bodyMedium));
    }
    return RefreshIndicator(
      color: AppTheme.gold,
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        itemCount: videos.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final v = videos[i];
          return GestureDetector(
            key: ValueKey(v.id),
            onTap: () => onTap(v),
            child: RepaintBoundary(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.dividerColor(context), width: 0.5),
                ),
                clipBehavior: Clip.hardEdge,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(fit: StackFit.expand, children: [
                        CachedNetworkImage(imageUrl: v.thumbnailHd,
                            fit: BoxFit.cover,
                            memCacheWidth: 720,
                            memCacheHeight: 405,
                            placeholder: (_, __) => Shimmer.fromColors(
                              baseColor: const Color(0xFF1E1E1E),
                              highlightColor: const Color(0xFF2C2C2C),
                              child: const ColoredBox(color: Colors.white),
                            ),
                            errorWidget: (_, __, ___) => CachedNetworkImage(
                                imageUrl: v.thumbnailMq, fit: BoxFit.cover,
                                memCacheWidth: 720,
                                memCacheHeight: 405,
                                errorWidget: (_, __, ___) =>
                                    const ColoredBox(color: Color(0xFF1E1E1E)))),
                        Center(child: Container(width: 48, height: 48,
                            decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.play_arrow_rounded,
                                color: Colors.white, size: 30))),
                        Positioned(bottom: 0, left: 0, right: 0,
                            child: Container(height: 3, color: channel.accentColor)),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600, height: 1.35)),
                          const SizedBox(height: 6),
                          Text(timeago.format(v.publishedAt),
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ShortsGrid extends StatelessWidget {
  final List<Video> shorts;
  final Channel channel;
  final void Function(int) onTap;
  final Future<void> Function() onRefresh;

  const _ShortsGrid({required this.shorts, required this.channel,
      required this.onTap, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (shorts.isEmpty) {
      return Center(child: Text('No shorts yet',
          style: Theme.of(context).textTheme.bodyMedium));
    }
    return RefreshIndicator(
      color: AppTheme.gold,
      onRefresh: onRefresh,
      child: GridView.builder(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, childAspectRatio: 9 / 16,
          crossAxisSpacing: 8, mainAxisSpacing: 8,
        ),
        itemCount: shorts.length,
        itemBuilder: (context, i) {
          final v = shorts[i];
          return RepaintBoundary(
            key: ValueKey(v.id),
            child: GestureDetector(
              onTap: () => onTap(i),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(fit: StackFit.expand, children: [
                  CachedNetworkImage(imageUrl: v.thumbnailMq, fit: BoxFit.cover,
                      memCacheWidth: 360,
                      memCacheHeight: 640,
                      placeholder: (_, __) => Shimmer.fromColors(
                        baseColor: const Color(0xFF1E1E1E),
                        highlightColor: const Color(0xFF2C2C2C),
                        child: const ColoredBox(color: Colors.white),
                      ),
                      errorWidget: (_, __, ___) =>
                          const ColoredBox(color: Color(0xFF1E1E1E))),
                  const DecoratedBox(decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                          stops: [0.45, 1.0]))),
                  Positioned(top: 0, left: 0, right: 0,
                      child: Container(height: 3, color: channel.accentColor)),
                  const Center(child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: Colors.black45, shape: BoxShape.circle),
                      child: Padding(padding: EdgeInsets.all(8),
                          child: Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 26)))),
                  Positioned(bottom: 8, left: 8, right: 8,
                      child: Text(v.title, maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white,
                              fontSize: 10, fontWeight: FontWeight.w600,
                              height: 1.3, shadows: [
                                Shadow(color: Colors.black87, blurRadius: 4)]))),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}
