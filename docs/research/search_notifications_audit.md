# Search and Notifications Audit

## Notification architecture

The current app uses `flutter_local_notifications` plus Workmanager. Native Android/iOS checks poll selected/general channel RSS feeds every 15 minutes; Web currently returns early and has no notification trigger path. The app has no Firebase Messaging dependency, FCM configuration, APNs entitlement setup, Web Push VAPID key, or Firebase messaging service worker.

The official Firebase Flutter documentation states that iOS, Web, and Android 13+ require notification permission; Web background delivery requires a service worker and a Web Push certificate/VAPID key; native background delivery requires a top-level background handler and platform setup. Sources: https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages and https://firebase.google.com/docs/cloud-messaging/flutter/get-started

The implementation for this repository therefore keeps the existing native local-notification path, fixes its polling/last-seen logic, adds foreground/resume checks, and adds Web Notification API delivery while the app is open. True Web push after the browser is closed requires a future server-side sender plus VAPID/FCM credentials; those credentials are not present in the repository.

## Homepage search audit

The existing homepage search route searched only currently loaded FeedProvider videos/shorts and books, plus lazily fetched blog articles. It did not index canonical resource categories, category keywords, verified channel metadata, blog source names, or the category playbook text. Its scorer used simple lowercased substrings and a small suffix stemmer.

The planned replacement indexes all loaded platform sources: videos, Shorts, books, blog articles, channels, canonical categories, category search keywords, category descriptions/questions, and resource source names. Exact title/name matches receive the highest score; token coverage, aliases, description, channel/source, and recency are secondary signals. Empty queries never return the catalogue.
