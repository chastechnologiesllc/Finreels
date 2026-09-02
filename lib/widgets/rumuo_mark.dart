import 'package:flutter/material.dart';

/// The single in-app Rumuo brand mark.
///
/// The supplied yellow-background artwork is intentionally clipped with rounded
/// corners for app UI surfaces. The Android notification status-bar resource is
/// separate and remains transparent/monochrome.
class RumuoMark extends StatelessWidget {
  final double size;
  final double borderRadius;

  const RumuoMark({
    required this.size,
    this.borderRadius = 9,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        'assets/icons/app_icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        semanticLabel: 'Rumuo',
      ),
    );
  }
}
