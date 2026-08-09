# Online Hustle PDFs in Books + web PDF + watermark cleanup

## Diagnosed
1. **Online Hustle PDFs** lived under `assets/books/online_hustles/*.pdf` but were
   never registered in `FeedProvider._bookVideos` or `book_detail_screen` `_sources`,
   so the Books tab never listed them.
2. **Web PDF** used `Uri.base.resolve(assetPath)` which often 404s under GitHub Pages
   base-href. Fix: load via `rootBundle` → **blob: URL** → iframe (browser PDF viewer).
3. **“White blur overlay”** was the light-theme FinReels chip (`0xF2FFFFFF`) over the
   player, timed to cover the YouTube logo. Replaced with a **dark translucent + gold**
   FinReels chip, shown whenever playback has started (no full-frame blur plate).

## Files
```
lib/providers/feed_provider.dart          # 20 OH playbooks first in Books
lib/screens/book_detail_screen.dart       # pdfAsset maps + web blob reader
lib/widgets/web_pdf_blob.dart
lib/widgets/web_pdf_blob_stub.dart
lib/widgets/web_pdf_blob_web.dart
lib/screens/video_player_screen.dart      # watermark style + always-on chip
lib/widgets/inline_video_card.dart        # same watermark treatment
```

## Books tab order
1. Online Hustle playbooks (20 bundled PDFs)
2. Five Buckets + classics (rest of `_bookVideos`)
3. Selected-category verified books
4. General verified books
