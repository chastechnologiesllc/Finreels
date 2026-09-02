# Rumuo 
**Financial Literacy Content Aggregator** — by chAs Technologies LLC
`com.chastechgroup.rumuo` · Android (Play Store) · Production

Rumuo curates videos, shorts, blogs, and books from 40+ verified channels and
700+ free resources into one clean, ad-supported mobile app — organised across a
60-category taxonomy of skills, businesses, and professions, built for entrepreneurs
and professionals across Africa.

--------

## Content

| Type | Count | Source |
|---|---|---|
| Channels | 40+ general + category-specific | YouTube RSS (no API key) |
| Books | 690+ with cover images | Open Library, OpenStax, free sources |
| Blogs | 690+ | RSS feeds |
| Categories | 60 (20 Skills · 20 Businesses · 20 Professions) | Curated taxonomy |

### Category Taxonomy

**Skills (20)** — Tailoring & Fashion Design, Hairdressing & Hairstyling, Barbing,
Makeup Artistry, Welding & Metal Fabrication, Carpentry & Furniture Making,
Electrical Installation, Plumbing & Pipefitting, Painting & Decorating, Tiling &
Flooring, AC & Refrigeration Repair, Phone & Electronics Repair, Graphic Design,
Photography & Videography, Catering & Event Decoration, Baking & Confectionery,
Laundry & Dry Cleaning, Auto Mechanic & Panel Beating, Solar & Renewable Energy,
Web & Software Development.

**Businesses (20)** — POS/Agent Banking, Provision Store/Mini-Mart, Fashion Retail/
Boutique, Poultry Farming, Catfish Farming, Restaurant & Food Service, Logistics &
Dispatch Riding, Real Estate & Property, Printing & Branding, Waste Management &
Recycling, Gym & Fitness Centre, Cinema & Entertainment, ICT Services, Cleaning
Services, Event Planning & Management, Supermarket & FMCG Distribution, Exportation
& Non-Oil Trade, Agriculture & Agro-Processing, Fuel Station/Petrol Retail,
Healthcare Retail & Pharmacy.

**Professions (20)** — Medicine, Law, Pharmacy, Nursing, Accounting, Engineering,
Architecture, Estate Management & Surveying, Banking & Finance, Dentistry, Optometry,
Physiotherapy, Radiography, Medical Laboratory Science, Environmental Health, Nutrition
& Dietetics, Human Resources, Information Technology, Education & Teaching, Insurance.

---

## Cross-Cutting Channels (40 — from `_general.json`)

| Channel | Focus |
|---|---|
| Dayo Adetiloye Business Hub | Entrepreneurship |
| JP Iwuoha — Smallstarter Africa | Strategy |
| Insightpreneur | Mindset |
| Naijapreneur | Mindset |
| Valu.ng | Finance |
| SMEDAN Nigeria | Government |
| BusinessDay Nigeria | News |
| Nairametrics TV | Finance |
| Techpoint Africa | Tech |
| Disrupt Africa | Startup |
| Africa's Young Entrepreneurs | Entrepreneurship |
| Gary Vaynerchuk | Marketing |
| Neil Patel | Marketing |
| Seth Godin | Marketing |
| HubSpot | Marketing |
| Tim Ferriss | Productivity |
| Ali Abdaal | Productivity |
| Tony Robbins | Mindset |
| Grant Cardone | Sales |
| Valuetainment | Strategy |
| How I Built This | Stories |
| Shopify | E-commerce |
| Ramit Sethi | Finance |
| The Futur | Pricing |
| Michael Kitces | Practice Mgmt |
| Business of Architecture | Practice |
| Mike Michalowicz | Finance |
| Entrepreneurs.ng | Entrepreneurship |
| Connect Nigeria | Directory |
| SME Digest Nigeria | SME Focus |
| Kippa Africa | Tools |
| Bumpa | Tools |
| Wale Marketer | Pricing |
| Bintus Art and Everything | Multi-Trade |
| ServiceTitan | Trades |
| Markup & Profit | Pricing |
| ITF Nigeria | Government |
| Nic Haralambous | Mindset |
| Built in Africa | Startup |
| Radio 702 — The Money Show | Finance |

All channel IDs are verified directly from YouTube channel pages and pull live
RSS feeds — no API key required.

---

## Architecture

| Layer | Detail |
|---|---|
| **Feed** | YouTube RSS via `dart:http` — no API key, no backend |
| **Codebase** | Pure Flutter (Dart) — single codebase for Android + iOS |
| **Theme** | System-adaptive — pure white light / pure black dark |
| **AdMob** | Banner + Interstitial + App Open + Rewarded + Native (AdMob direct, no mediation) |
| **IAP** | 3 ad-free tiers (one-time, non-recurring purchases) |
| **Payment fallback** | Paystack via local WebView + Inline.js (sideloaded installs) |
| **Background** | WorkManager RSS polling + local push notifications |
| **Connectivity** | Multi-endpoint probing — no false positives |
| **Ad-block detect** | 4 ad-server probes; gates interstitials if 2+ fail |
| **Category data** | 60 JSON files under `assets/data/resources/` — one per category |
| **Books** | 690+ entries with cover images (Open Library CDN) across all JSON files |
| **Personalisation** | `UserProfileService` + `EngagementService` (21-day decay) |
| **Startup** | Parallel service init (6 s ceiling); instant first frame |

---

## Monetization

| Tier | Product ID | Price |
|---|---|---|
| Ads (default) | — | Free; AdMob Finance CPM ~$8–25 |
| 1-day ad-free | `rumuo_no_ads_1day` | $0.99 |
| 7-day ad-free | `rumuo_no_ads_weekly` | $2.99 |
| 30-day ad-free | `rumuo_no_ads_monthly` | $7.99 |

Purchases are **one-time payments** — they do not auto-renew.
Play Store installs → Google Play billing.
Sideloaded installs → Paystack (local HTML + WebView checkout).

---

## Project Structure

```
rumuo/
├── lib/
│   ├── config/         ← app_config.dart (AdMob IDs, IAP IDs, Paystack key)
│   ├── data/           ← resource_category_data.dart (loads all 60 JSON files)
│   │                      book_insights_data.dart
│   │                      category_playbook_data.dart
│   ├── models/         ← channel.dart, video.dart, resource_category.dart,
│   │                      feed_tab.dart
│   ├── providers/      ← feed_provider.dart (3-layer channel ordering)
│   ├── screens/        ← splash, home, discover, category_detail,
│   │                      video_player, shorts_player,
│   │                      blog_feed, blog_reader,
│   │                      book_detail, book_detail_screen,
│   │                      channel_videos, my_business,
│   │                      settings, privacy_policy,
│   │                      paystack_checkout
│   ├── services/       ← ad_service, ad_block_service, rss_service,
│   │                      blog_rss_service, iap_service,
│   │                      install_source_service, paystack_service,
│   │                      notification_service, background_service,
│   │                      connectivity_service, consent_service,
│   │                      engagement_service, user_profile_service
│   ├── theme/          ← app_theme.dart (adaptive light/dark)
│   ├── widgets/        ← connectivity_overlay, ad_block_overlay,
│   │                      banner_ad_widget, sticky_banner_bar,
│   │                      inline_video_card, video_card,
│   │                      book_cover_image, shimmer_loader
│   └── main.dart
├── android/
│   ├── app/build.gradle        ← AGP 8.6.0, minSdk 23, targetSdk 36
│   ├── settings.gradle         ← Kotlin 2.4.0
│   └── app/src/main/
│       ├── AndroidManifest.xml ← permissions, AdMob app ID, WorkManager
│       └── kotlin/             ← MainActivity.kt, MainApplication.kt
├── ios/
│   └── Runner/Info.plist       ← AdMob ID, ATT usage string, BGTask identifiers
├── assets/
│   ├── data/
│   │   ├── resource_categories.json   ← 60-category taxonomy manifest
│   │   └── resources/                 ← 66 JSON files (60 categories + _general
│   │                                      + 5 auxiliary)
│   ├── icons/          ← app_icon.png + adaptive variants
│   ├── sounds/         ← notification.wav, ding.wav
│   └── books/          ← bundled PDF masterclass playbooks + covers
├── scripts/
│   └── ExportOptions.plist
└── .github/workflows/
    ├── build_android.yml
    └── build_ios.yml
```

---

## GitHub Actions — Required Secrets

### Android

| Secret | Value |
|---|---|
| `KEYSTORE_BASE64` | base64-encoded `rumuo.jks` (single line, no line breaks) |
| `KEYSTORE_STORE_PASSWORD` | keystore store password |
| `KEYSTORE_KEY_ALIAS` | `rumuo` |
| `KEYSTORE_KEY_PASSWORD` | key password — **must match** `KEYSTORE_STORE_PASSWORD` |

> `KEYSTORE_KEY_PASSWORD` and `KEYSTORE_STORE_PASSWORD` are always the same value.
> This is the correct standard for Android/PKCS12 keystores.

```bash
# Generate keystore (run once — never commit the .jks)
keytool -genkeypair -v \
  -keystore rumuo.jks \
  -storetype JKS \
  -alias rumuo \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass YOUR_PASS -keypass YOUR_PASS \
  -dname "CN=chAs Technologies LLC, OU=Mobile Development, O=chAs Technologies LLC, L=Nigeria, S=Lagos, C=NG"

# Encode for GitHub secret (single line — no wrapping)
base64 -w 0 rumuo.jks   # Linux
base64 rumuo.jks         # macOS (outputs single line by default)
```

### iOS

| Secret | Value |
|---|---|
| `IOS_CERTIFICATE_BASE64` | `base64 Certificates.p12` |
| `IOS_CERTIFICATE_PASSWORD` | p12 export password |
| `IOS_PROVISION_PROFILE_BASE64` | `base64 Rumuo.mobileprovision` |
| `IOS_KEYCHAIN_PASSWORD` | any random string |
| `IOS_CODE_SIGN_IDENTITY` | e.g. `iPhone Distribution: chAs Technologies LLC` |
| `IOS_PROVISIONING_PROFILE_NAME` | e.g. `Rumuo App Store` |

---

## Release Workflow

```bash
# Tag triggers the full signed CI build + GitHub Release
git tag v1.x.x -m "Release notes here"
git push origin v1.x.x
```

- **Android** outputs: `app-release.apk` (universal — all phones), `app-release.aab`
- **iOS** outputs: `Rumuo.ipa`

> The APK is a **universal** build (armeabi-v7a + arm64-v8a in one file) — not
> split-per-abi. This gives sideloaded users a single file that works on any
> real Android phone. Play Store distribution uses the AAB, which Play delivers
> per-device automatically.

---

## CI/CD — Action Versions

| Action | Version |
|---|---|
| `actions/checkout` | `v6` |
| `actions/setup-java` | `v4` |
| `subosito/flutter-action` | `v2` · Flutter `3.44.0` stable |
| `actions/upload-artifact` | `v7` |
| `softprops/action-gh-release` | `v3` |

---

## Quick Start (Development)

```bash
git clone https://github.com/YOUR_ORG/rumuo.git
cd rumuo
flutter pub get
flutter run
```

> **Note:** AdMob test mode is controlled by `kDebugAds` in `lib/config/app_config.dart`.
> All production ad unit IDs and IAP product IDs are live on Android.
> For iOS, create a separate AdMob app and update `app_config.dart` + `Info.plist`.

---

## License
Copyright © 2025–2026 chAs Technologies LLC. All rights reserved.
