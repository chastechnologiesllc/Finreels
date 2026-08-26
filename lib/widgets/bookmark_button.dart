import 'package:flutter/material.dart';

/// Bookmark action used on media thumbnails and full-screen media surfaces.
///
/// The circular backdrop keeps the control visible over both light and dark
/// thumbnails while preserving a sufficiently large touch target on mobile.
class BookmarkButton extends StatelessWidget {
  final bool saved;
  final VoidCallback onPressed;
  final String? tooltip;

  const BookmarkButton({
    required this.saved,
    required this.onPressed,
    this.tooltip,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.black54,
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tooltip ?? (saved ? 'Remove bookmark' : 'Bookmark'),
          onPressed: onPressed,
          icon: Icon(
            saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            color: Colors.white,
            size: 20,
          ),
          padding: const EdgeInsets.all(7),
          constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
          visualDensity: VisualDensity.standard,
        ),
      );
}

class BookmarkButtonOverlay extends StatelessWidget {
  final bool saved;
  final VoidCallback onPressed;
  final double top;
  final double right;

  const BookmarkButtonOverlay({
    required this.saved,
    required this.onPressed,
    this.top = 6,
    this.right = 6,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Positioned(
        top: top,
        right: right,
        child: BookmarkButton(
          saved: saved,
          onPressed: onPressed,
        ),
      );
}
