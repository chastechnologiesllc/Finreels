# OH PDF assets + no white video + YT-logo FinReels watermark

## PDF "Unable to load asset"
Flutter **does not** include files in subdirectories of a declared folder.
`assets/books/` only ships files *directly* in that folder (why Five Buckets
PDFs work — they sit at `assets/books/five_buckets_*.pdf`).

`online_hustles/*.pdf` lived under a subfolder and were never in the asset
bundle. Fix: declare the subfolder explicitly in `pubspec.yaml`:

```yaml
- assets/books/
- assets/books/online_hustles/
```

Same pattern as `assets/data/resources/`.

## White wash on playing feed videos
YouTube WebView paints white during init. Fix: keep an **opaque thumbnail
cover** on top until `_revealPlayer` (real frames). Dark shimmer only.

## Watermark
FinReels chip bottom-right with **relative insets** (scales on all phones),
shown while the native YT logo is expected (first ~4s of play, or paused).
Applied on inline cards, full player, and Shorts.

## Copy
```
pubspec.yaml
lib/providers/feed_provider.dart
lib/screens/book_detail_screen.dart
lib/screens/video_player_screen.dart
lib/screens/shorts_player_screen.dart
lib/widgets/inline_video_card.dart
lib/widgets/web_pdf_blob.dart
lib/widgets/web_pdf_blob_stub.dart
lib/widgets/web_pdf_blob_web.dart
assets/books/online_hustles_playbook_cover.jpg
```

After merge: `flutter pub get` then full rebuild (asset manifest changes require
clean rebuild, not hot reload).
