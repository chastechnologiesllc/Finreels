# Search and Notifications Audit

## Notification architecture

The current app uses `flutter_local_notifications` plus Workmanager. Native Android/iOS checks poll selected/general channel RSS feeds every 15 minutes; Web currently returns early and has no notification trigger path. The app has no Firebase Messaging dependency, FCM configuration, APNs entitlement setup, Web Push VAPID key, or Firebase messaging service worker.

The official Firebase Flutter documentation states that iOS, Web, and Android 13+ require notification permission; Web background delivery requires a service worker and a Web Push certificate/VAPID key; native background delivery requires a top-level background handler and platform setup. Sources: https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages and https://firebase.google.com/docs/cloud-messaging/flutter/get-started

The implementation for this repository therefore keeps the existing native local-notification path, fixes its polling/last-seen logic, adds foreground/resume checks, and adds Web Notification API delivery while the app is open. True Web push after the browser is closed requires a future server-side sender plus VAPID/FCM credentials; those credentials are not present in the repository.

## Homepage search audit

The existing homepage search route searched only currently loaded FeedProvider videos/shorts and books, plus lazily fetched blog articles. It did not index canonical resource categories, category keywords, verified channel metadata, blog source names, or the category playbook text. Its scorer used simple lowercased substrings and a small suffix stemmer.

The planned replacement indexes all loaded platform sources: videos, Shorts, books, blog articles, channels, canonical categories, category search keywords, category descriptions/questions, and resource source names. Exact title/name matches receive the highest score; token coverage, aliases, description, channel/source, and recency are secondary signals. Empty queries never return the catalogue.

## Inline banner sizing audit

The inline feed slots now use an explicit two-size contract. Video and blog content uses a standard 300×250 medium rectangle; books and utility placements use a compact 320×50 banner. The native widget reserves that exact box before the asynchronous ad finishes loading, while the Web AdSense `<ins>` element receives an explicit pixel width and height with overflow clipped. The sticky bottom banner remains separate and adaptive because it is outside scrolling content.

Google’s ad-sizing guidance recommends defining the fixed slot dimensions in the containing element because asynchronous creatives can otherwise shift surrounding content. It also warns that flexible/fluid ad content can reflow the page when it resizes. Source: https://developers.google.com/publisher-tag/guides/ad-sizes

The Web host CSS now targets only iframe-backed video platform views for a black background; it no longer paints every Flutter platform view black, which could make a white AdSense slot appear as a large black rectangle.

## Notification-toggle audit

The settings toggle now reads both the persisted preference and the actual platform authorization state. Android checks `areNotificationsEnabled()`, iOS checks `checkPermissions().isEnabled`, and Web reads `Notification.permission`. Enabling is transactional: the permission request completes first, the stored preference is written only when delivery is authorized, and a denied request rolls the switch back off with a recovery message. The settings screen refreshes on app resume so changes made in Android/iOS system settings or browser site settings are reflected when the user returns.

The existing no-backend behavior remains honest. Native Workmanager polling is OS-scheduled and best-effort, while Web notifications are foreground/browser-API behavior. The Web Notifications API requires permission from a user gesture and notes that mobile browsers may require a service worker for system-level notifications. Fully closed Web Push and reliable terminated-state mobile push still require a future push backend, service worker, and FCM/APNs/VAPID configuration. Sources: https://developer.mozilla.org/en-US/docs/Web/API/Notifications_API/Using_the_Notifications_API and https://pub.dev/packages/flutter_local_notifications
