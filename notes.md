# OH category PDFs + dedicated cover + PDF open fix + no white video flash

## PDF stuck loading
- FutureBuilder recreated the asset Future every rebuild → endless spinner.
- Fixed with cached `_pdfAssetFutures` + error UI + 1.2s safety clear of overlay.
- `onRender` / `onError` / `onPageError` clear `_isLoading`.

## Cover
- New asset: `assets/books/online_hustles_playbook_cover.jpg`
  (FinReels Online Hustles branded cover for all 20 OH playbooks).
- Feed uses that path (not Five Buckets cover).

## White flash on video
- Shimmer placeholder was pure white → dark `#121212`.
- Black base layer under thumbnail/player stack (inline + full player).

## Copy
```
lib/providers/feed_provider.dart
lib/screens/book_detail_screen.dart
lib/screens/video_player_screen.dart
lib/widgets/inline_video_card.dart
lib/widgets/web_pdf_blob.dart
lib/widgets/web_pdf_blob_stub.dart
lib/widgets/web_pdf_blob_web.dart
assets/books/online_hustles_playbook_cover.jpg
```
