# FinReels platform-lock + white-wash fixes

Applies on **Android, iOS, and Web**.

## What was wrong

1. **White wash over video**
   - `youtube_player_flutter` v9 paints a light loading surface if `thumbnail` is unset.
   - `AnimatedOpacity(0)` does **not** hide Android platform views (WebView still shows).
   - Light-theme FinReels chip used near-white `0xF2FFFFFF`.

2. **"Watch on YouTube"**
   - Native YT chrome / logo / end cards can push users off-app.
   - Web already used `pointer-events:none` + `controls=0`; kept and documented.

## What this package changes

### White wash (all platforms)
- `thumbnail: ColoredBox(color: Color(0xFF000000))` on every `YoutubePlayer`
- Full-size player only after real frames (`_revealPlayer`); pre-warm is 1×1 off-screen
- Watermark always dark + gold (never white plate)
- Shimmer under video is black

### Locked in FinReels (playback stays in-app)
- Mobile: `hideControls: true`, `enableCaption: false` (Android + iOS)
- Web: `controls=0`, `fs=0`, `disablekb=1`, `modestbranding=1`, `rel=0`
- Web: iframe `pointer-events: none`, sandbox **without** top-navigation/popups
- Web: `youtube-nocookie` + `origin` = this host
- Custom end overlay instead of YT end-screen recommendations
- FinReels chip over native YT logo region (bottom-right)

### Not changed on purpose
- **Share** still can include a YouTube link so users can share a video link.
  That is share, not in-player "Watch on YouTube".
- Blog/book external free sources still open in browser when that is the source type.

## Files
```
lib/widgets/inline_video_card.dart
lib/widgets/web_youtube_player.dart
lib/widgets/web_youtube_player_stub.dart
lib/widgets/web_youtube_player_web.dart
lib/screens/video_player_screen.dart
lib/screens/shorts_player_screen.dart
lib/screens/video_landscape_screen.dart
```

Full rebuild after applying (asset/player changes need more than hot reload).
