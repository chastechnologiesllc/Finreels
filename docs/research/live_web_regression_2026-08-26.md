# Live Web regression findings — 2026-08-26

The repository’s configured Pages URL is `https://chastechnologiesllc.github.io/Finreels/`. The user’s screenshot domain `https://stechnologiesllc.github.io/` returns GitHub Pages 404 and is not the configured repository deployment.

On the configured live deployment, the HTML splash transitions to onboarding. The onboarding initially shows the welcome content and one visible search field. After tapping the field, the welcome content collapses and the field remains visible. Browser extraction reports two input elements after focus: one input with the general search hint and a second input with the floating-label/placeholder text. Entering `law` through the active input visibly keeps `law` in the field and returns the canonical `Law` result with its category description. Tapping the active field again did not remove the typed text in the sandbox browser reproduction.

The source wrapped the Flutter TextField in `Semantics(textField: true, label: ...)` while the TextField itself also supplied semantics. The live browser exposed two input elements, consistent with a duplicate Web semantics input/proxy. The redundant wrapper has now been removed; the field relies on TextField’s native semantics while retaining the persistent controller/focus node. The Web splash hides only on the custom `finreels-app-ready` event after the first usable app frame, with no early timeout. The remaining deployment behavior should be confirmed by the next Web CI build and live cache refresh.

## Post-fix verification

After commit `20947e5` was deployed, a cache-busted live visit to `https://chastechnologiesllc.github.io/Finreels/?v=20947e5` exposed one input element at initial onboarding, not two. Tapping it collapsed the welcome/guidance content and still exposed exactly one input with the expected search placeholder. This confirms the redundant Semantics wrapper was contributing to the duplicate-input behavior observed before the fix.

## Input report follow-up

A fresh reproduction on the configured Pages deployment (`chastechnologiesllc.github.io/Finreels`) after commit `20947e5` shows one visible input, an active browser input element, and typed `law` displayed in the field with the ranked `Law` result. The screenshot supplied by the user shows `stechnologiesllc.github.io`, which is not the configured Pages URL for `chastechnologiesllc/Finreels`; that host returns GitHub Pages 404 in the sandbox and cannot receive this repository’s deployments.

To harden the mobile path further, the onboarding source now derives query state from a persistent controller listener, keeps the welcome subtree maintained during compact-mode changes, removes focus-time auto-scrolling, and sets the scroll view to manual keyboard dismissal. These changes target the Android Chrome behavior where the keyboard can remain open while a layout rebuild loses the platform text-input connection.
