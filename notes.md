# Category-scoped Online Hustle PDFs + covers + open path

## Behaviour
- Each `online_hustles_XX_*` category gets **one** FinReels bundled PDF.
- That PDF appears **only when that category is selected**, and is listed
  **first** in the Books tab (before other verified books for that category).
- Not a global dump of all 20 at the top of Books for every user.

## Cover
- Uses `assets/books/five_buckets_playbook_cover.jpg` (real asset) so the
  Books grid shows a real cover instead of the empty-state icon.

## Open
- Video id is `book_<categoryId>` (e.g. `book_online_hustles_01_surveys_microtasks`).
- `book_detail_screen.dart` `_sources` maps that id → `pdfAsset` path under
  `assets/books/online_hustles/…pdf` (mobile `PDFView` + web blob iframe).

## Files
```
lib/providers/feed_provider.dart
lib/screens/book_detail_screen.dart   # pdf source maps + web reader
lib/widgets/web_pdf_blob*.dart
lib/screens/video_player_screen.dart
lib/widgets/inline_video_card.dart
```
