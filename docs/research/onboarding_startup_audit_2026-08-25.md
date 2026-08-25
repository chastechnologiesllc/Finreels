# FinReels Onboarding and Startup Audit

**Date:** 25 August 2026  
**Scope:** Shared Flutter code for Web, Android, and iOS  
**Author:** Manus AI

## Executive summary

FinReels’ first-run route is controlled by `UserProfileService.onboardingComplete` in `lib/main.dart`. The onboarding screen is `MyBusinessScreen(isOnboarding: true)`. The previous experience asked users to search a category but did not explain the wider value of the platform early enough, and it could keep the first useful screen behind an unnecessarily long splash and a full verified-resource load.

The implementation now leads with a short purpose statement, three concrete platform capabilities, one clearly labelled search task, and a single primary action. Category tiles remain hidden when the search is empty, including when the field receives focus; matching categories appear only after typed input. The category index is loaded separately from the larger channel, blog, and book catalog. The latter hydrates in the background and triggers a quiet feed refresh after it is ready.

The Web document now paints a dependency-free branded boot state before Flutter JavaScript finishes loading. The Flutter splash hold has been reduced from 2.8 seconds to 0.9 seconds. These changes reduce artificial waiting and make slow cold starts feel intentional, but they cannot eliminate browser network transfer, Flutter engine initialization, device scheduling, or a user’s connection latency.

## Findings and decisions

| Area | Verified finding | Decision |
| --- | --- | --- |
| Onboarding gate | `_AppRoot` uses `UserProfileService.instance.onboardingComplete`; onboarding is `MyBusinessScreen(isOnboarding: true)`. | Preserve the existing persistence contract and add clarity within the existing single-screen flow. |
| Search behavior | The picker previously risked coupling first render to the full resource catalog. | Use `ResourceCategoryData.loadCategories()` for the taxonomy/search index; never render default category results for an empty query. |
| First-run explanation | Users need to understand what FinReels offers before choosing a category. | Show “Watch lessons”, “Read free books”, and “Follow useful blogs” with short descriptions. |
| Primary action | Skipping is valid because category selection is optional and can be changed later. | Use “Start exploring” with no selection and “Continue (N selected)” after selection; retain “Skip for now” and “Save” wording in Profile personalization. |
| Startup catalog work | `ResourceCategoryData.load()` previously loaded the category JSON and then every available resource file before the first feed provider was constructed. | Split category-index readiness from verified-resource hydration, with in-flight future coalescing to avoid duplicate loads. |
| Feed correctness | `FeedProvider.init()` loads disk cache and performs its network refresh; verified resources affect channel scope and category-prioritized content. | Construct the provider after lightweight prerequisites, start it immediately, then refresh quietly after verified resources finish. |
| Flutter splash | `SplashScreen` held the transition for 2.8 seconds even when initialization had already completed. | Reduce the intentional brand hold to 0.9 seconds while retaining the existing gate that waits for both splash completion and initialization. |
| Web first paint | `web/index.html` previously supplied only a background before Flutter took over. AdSense remains asynchronous, but the page had no visible boot marker. | Add a small inline branded boot state removed on `flutter-first-frame`, with a timeout fallback so it cannot permanently cover recovery UI. |
| Cross-platform safety | The changed application behavior is in shared Dart code; Android and iOS native launch screens remain lightweight and theme-aligned. | Avoid adding platform-specific splash assets or platform branches. |

## Onboarding research findings

Material Design guidance recommends focusing onboarding on the action most closely connected to early engagement and introducing core functionality contextually rather than teaching everything at once [1]. Apple’s Human Interface Guidelines likewise recommend that prerequisite onboarding be brief and enjoyable and not require people to memorize a lot of information [2]. FinReels therefore uses one purpose statement, three concrete capability explanations, plain-language examples, and one obvious next action instead of a long tutorial.

The W3C clear-content guidance supports short sentences, familiar words, clear purpose, useful headings, and supporting instructions for people with cognitive and learning disabilities [3]. W3C cognitive accessibility guidance also emphasizes predictable structure and support that helps users understand what to do [4]. The redesign applies these principles through visible section headings, concrete verbs, explicit search labels, semantic headers, a keyboard-friendly text field, and large Material controls.

“Child-friendly” is treated as a clarity requirement for people of all ages, not as a reason to collect age information or design a separate child profile. The implementation avoids a carousel, avoids unnecessary memorization, and keeps the category choice optional.

## Startup research and platform limits

The app can reduce work it controls: unnecessary fixed delays, sequential local asset reads, duplicate initialization, and blocking nonessential catalog hydration. It cannot guarantee zero-time Web interactivity. A cold browser visit may still need to download the Flutter bootstrap and compiled application, initialize the Flutter engine, create the first rendering surface, and wait for the network or browser cache. The static Web boot state addresses the blank interval before Flutter paints; it does not replace the Flutter application or claim that the network is instantaneous.

The Android and iOS launch surfaces were intentionally left minimal. Shared Dart startup now avoids waiting for the full verified catalog, while native launch-screen behavior remains unchanged to reduce the risk of platform-specific regressions. Linux-based CI can validate shared Dart and Web/Android outputs, but it does not produce an iOS archive unless a macOS/iOS workflow is configured.

## Validation status

Local whitespace, JSON, and HTML parsing checks passed. The local environment does not contain the Flutter SDK, so `flutter analyze` and `flutter test` must be confirmed by the repository’s GitHub Actions workflows. The new widget regression test checks that the onboarding purpose, three awareness items, and “Start exploring” action are present. Existing feed snapshot, media fallback, shimmer, model, and channel-data tests remain in place.

## References

[1]: https://m2.material.io/design/communication/onboarding.html "Material Design: Onboarding"

[2]: https://developer.apple.com/design/human-interface-guidelines/onboarding "Apple Human Interface Guidelines: Onboarding"

[3]: https://www.w3.org/WAI/WCAG2/supplemental/objectives/o3-clear-content/ "W3C WAI: Clear Content"

[4]: https://www.w3.org/TR/coga-usable/ "W3C: Making Content Usable for People with Cognitive and Learning Disabilities"

## Changed files

The focused implementation touches `lib/screens/my_business_screen.dart`, `lib/data/resource_category_data.dart`, `lib/main.dart`, `lib/screens/splash_screen.dart`, `web/index.html`, and `test/finreels_test.dart`.

The implementation deliberately preserves the existing feed snapshot recovery, media fallbacks, book/blog assets, notification and ad containment work, and the rule that empty onboarding or Profile searches show no default category list.

## Remaining risks to monitor in CI and production

The main risks are behavioral rather than syntax-related: a feed refresh may complete before the background verified-resource hydration and then be refreshed again; the first-time Web boot state depends on the standard Flutter first-frame event; and very slow devices may still display the Flutter splash while local prerequisites complete. These are bounded, recoverable states rather than permanent gates, and the workflows should verify that the resulting Web and Android builds remain healthy.

The relevant acceptance checks are: onboarding has no category tiles before typing; typed input returns canonical matches; selected categories persist; returning users bypass onboarding; Web shows an immediate boot state before Flutter; no fixed 2.8-second splash remains; and the complete resource catalog eventually refreshes feeds without requiring an app restart.

