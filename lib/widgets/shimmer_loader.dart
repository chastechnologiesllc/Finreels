import 'package:flutter/material.dart';

import 'rumuo_shimmer.dart';

/// Fix 2 — Shimmer skeletons with correct 16:9 aspect ratio and blog variant.
/// All skeletons match the exact dimensions of the real cards so there is
/// zero layout shift when content arrives.

enum ShimmerVariant { videoFeed, blogFeed, grid }

class ShimmerLoader extends StatelessWidget {
  final int count;
  final ShimmerVariant variant;

  const ShimmerLoader({
    super.key,
    this.count = 4,
    this.variant = ShimmerVariant.videoFeed,
  });

  @override
  Widget build(BuildContext context) {
    final skeleton = RumuoShimmer.fillColor(context);

    Widget child;
    switch (variant) {
      case ShimmerVariant.videoFeed:
        child = ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: count,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (_, __) => _VideoShimmerCard(placeholderColor: skeleton),
        );
      case ShimmerVariant.blogFeed:
        child = ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: count,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, __) => _BlogShimmerCard(placeholderColor: skeleton),
        );
      case ShimmerVariant.grid:
        child = GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 9 / 16,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: count,
          itemBuilder: (_, __) => Container(
            decoration: BoxDecoration(
              color: skeleton,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
    }

    return RumuoShimmer(child: child);
  }
}

/// 16:9 video card skeleton — matches InlineVideoCard exactly.
class _VideoShimmerCard extends StatelessWidget {
  final Color placeholderColor;

  const _VideoShimmerCard({required this.placeholderColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thumbnail — exact 16:9 aspect ratio.
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color: placeholderColor,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 3), // accent strip height
        const SizedBox(height: 12),
        Container(
          height: 16,
          width: double.infinity,
          decoration: BoxDecoration(
            color: placeholderColor,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 16,
          width: MediaQuery.of(context).size.width * 0.65,
          decoration: BoxDecoration(
            color: placeholderColor,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: placeholderColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 12,
              width: 120,
              decoration: BoxDecoration(
                color: placeholderColor,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Blog card skeleton — matches the 16:9 blog card layout.
class _BlogShimmerCard extends StatelessWidget {
  final Color placeholderColor;

  const _BlogShimmerCard({required this.placeholderColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cover image — 16:9
        AspectRatio(
          aspectRatio: 16 / 9,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: placeholderColor,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          decoration: BoxDecoration(
              color: placeholderColor.withValues(alpha: 0.15),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  height: 14,
                  width: 80,
                  decoration: BoxDecoration(
                    color: placeholderColor,
                    borderRadius: BorderRadius.circular(6),
                  )),
              const SizedBox(height: 8),
              Container(
                  height: 16,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: placeholderColor,
                    borderRadius: BorderRadius.circular(8),
                  )),
              const SizedBox(height: 6),
              Container(
                  height: 16,
                  width: MediaQuery.of(context).size.width * 0.6,
                  decoration: BoxDecoration(
                    color: placeholderColor,
                    borderRadius: BorderRadius.circular(8),
                  )),
            ],
          ),
        ),
      ],
    );
  }
}
