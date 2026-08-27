# Progressive search interaction research — 2026-08-27

## Sources reviewed

- Meta Engineering, “The Life of a Typeahead Query”: https://engineering.fb.com/2010/05/17/web/the-life-of-a-typeahead-query/
- Algolia, “Debounce sources”: https://www.algolia.com/doc/ui-libraries/autocomplete/guides/debouncing-sources

## Findings applied to FinReels

Meta’s typeahead architecture separates query processing from result data retrieval and emphasizes strict latency budgets, relevance validation, and cacheable/global results. The web tier should render result records from a stable result identity rather than blocking the user interface on every data fetch. Superseded queries must not overwrite newer input.

Algolia’s current guidance recommends debouncing asynchronous sources rather than the input itself. Its example uses a 200 ms delay and notes that delays over 300 ms begin to degrade the experience. It also recommends a stall threshold before showing loading feedback, so short transient work does not create distracting or blocking indicators. Static and dynamic sources can be combined under the same debounced request boundary.

## Engineering direction

FinReels should keep the text field responsive on every keystroke, cancel or invalidate stale work, avoid running live blog/network retrieval for empty or very short transient input, progressively publish local/indexed results before slower dynamic sources finish, and update the displayed count from the currently published result set. A final completion state should replace the provisional count without rebuilding the entire screen unnecessarily.

## Additional primary-source findings

- YouTube Help, “Find videos faster”: https://support.google.com/youtube/answer/9872296?hl=en — YouTube describes automated search predictions as suggestions derived from entered terms and related/popular searches. It distinguishes predictions from final answers and presents tappable related topics that start a fresh, updated result page. This supports keeping the input session independent from the result stream and treating intermediate results as provisional.
- Chrome Developers, `chrome.omnibox`: https://developer.chrome.com/docs/extensions/reference/api/omnibox — Chrome’s omnibox API exposes input-change events and returns suggestions asynchronously through a callback. The input-change lifecycle is separate from accepting a suggestion, supporting an architecture where continued typing can supersede prior result work without stealing focus.

These sources reinforce the implementation: keep input synchronous and focused, debounce only expensive work, invalidate superseded generations, show a progress state that does not block typing, publish local/indexed matches before network-backed articles, and update the count from the currently published set until the final stage completes.
