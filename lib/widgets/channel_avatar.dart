import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/channel.dart';
import 'finreels_shimmer.dart';

/// Displays a channel's official YouTube profile image with an initials
/// fallback for unavailable, removed, or not-yet-published channel avatars.
class ChannelAvatar extends StatelessWidget {
  final Channel channel;
  final double size;
  final double borderWidth;

  const ChannelAvatar({
    required this.channel,
    this.size = 46,
    this.borderWidth = 1.5,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = channel.avatarUrl;
    final fallback = _InitialsAvatar(channel: channel, size: size);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: channel.accentColor.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(
          color: channel.accentColor.withValues(alpha: 0.35),
          width: borderWidth,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl == null || imageUrl.isEmpty
          ? fallback
          : CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              memCacheWidth: (size * 3).round(),
              memCacheHeight: (size * 3).round(),
              placeholder: (_, __) => _AvatarShimmer(size: size),
              errorWidget: (_, __, ___) => fallback,
            ),
    );
  }
}

class _AvatarShimmer extends StatelessWidget {
  final double size;

  const _AvatarShimmer({required this.size});

  @override
  Widget build(BuildContext context) => FinreelsShimmer(
        child: ColoredBox(
          color: FinreelsShimmer.fillColor(context),
          child: SizedBox(width: size, height: size),
        ),
      );
}

class _InitialsAvatar extends StatelessWidget {
  final Channel channel;
  final double size;

  const _InitialsAvatar({required this.channel, required this.size});

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          channel.initials,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: TextStyle(
            color: channel.accentColor,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.30,
          ),
        ),
      );
}
