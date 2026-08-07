import 'package:flutter/material.dart';

/// A page route with no animated transition — used for every screen that
/// hosts a YouTube WebView player (VideoPlayerScreen, ShortsPlayerScreen).
///
/// ── Why this exists ─────────────────────────────────────────────────────
/// youtube_player_flutter renders through a native WebView platform view,
/// not a normal Flutter-painted widget. A standard MaterialPageRoute
/// animates the incoming route's transform/opacity for ~300ms. Native
/// platform views on Android are composited outside Flutter's own Skia
/// layer tree, so while that transform animation is running, the OS can
/// briefly fail to correctly position/clip the WebView's surface — the
/// visible result is a full-screen black frame that self-corrects once
/// the transition finishes and the platform view settles into place. This
/// is a well-documented class of bug for any WebView-based player pushed
/// with an animated route on Android.
///
/// Removing the transition entirely (zero duration) removes the window in
/// which that mispositioned-surface artifact can appear, without touching
/// the player widget itself. Navigation still reads as fast and immediate
/// — most short-form video apps intentionally cut instantly into playback
/// for exactly this reason.
class NoFlashPageRoute<T> extends PageRouteBuilder<T> {
  NoFlashPageRoute({required WidgetBuilder builder, super.settings})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          opaque: true,
        );
}
