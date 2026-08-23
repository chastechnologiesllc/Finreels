# Finreels Free-Book Research Report

**Research date:** 2026-08-23

**Repository:** `chastechnologiesllc/Finreels`

**Commit:** `5d640a4`

## What was audited

The repository contains **81 resource JSON files**: 80 existing categories plus `_general.json`. Before this pass, the files contained 840 book records, generally 10 per category and 40 in General. The existing JSON schema was preserved: category metadata, channels, blogs, books, notes, and action-required fields remain intact.

## Sources used

The first research pass used two authoritative public catalogs:

| Source | Research use | Selection rule |
|---|---|---|
| [Open Textbook Library](https://open.umn.edu/opentextbooks) | Openly licensed academic and professional textbooks | Require a catalog license plus a `$0.00` Online, PDF, or eBook format; map only when subject metadata supports the Finreels category. |
| [Project Gutenberg](https://www.gutenberg.org/) | Public-domain non-fiction and supplemental practical works | Use official catalog records only; exclude fiction, poetry, drama, periodicals, and weak keyword-only matches; use conservative title/subject mapping. |

The Open Textbook Library documentation states that its books are licensed for free use and adaptation, and its discovery page exposes machine-readable catalog data [1] [2]. Project Gutenberg states that it distributes works accepted as public domain in the United States and publishes an official machine-readable catalog [3] [4].

## Changes made

The first update added 3,711 total book records across the category files after cleanup and deduplication. This follow-up first added 500 additional Project Gutenberg public-domain non-fiction records to `_general.json`, bringing the General collection to 1,078 books and the repository-wide total to 4,211 book records. A second expansion added another **500 deduplicated Project Gutenberg records**, bringing the General collection to **1,578 books** and the repository-wide total to **4,711 book records**. Across all passes, the work includes 1,609 high-confidence Open Textbook Library additions, 1,250 selected Project Gutenberg titles for General, and 1,110 selected Project Gutenberg supplemental trade and vocational titles.

The pass also removed **49 existing entries** hosted on explicitly disallowed generic or unauthorized-looking ebook domains, including `f5fp.com`, `bdebooks.com`, `bookdio.org`, and `free-ebooks.net`. These were not treated as legitimate free-book sources. Existing Internet Archive borrow records were not automatically removed because Internet Archive access is a legal library-lending model, but they remain marked as borrowable or requiring review where applicable.

## Validation results

The final quality check for this follow-up passed with no JSON parsing errors, no missing required book fields, no blank authors, no missing URLs, no remaining disallowed hosts, and no within-file title-author duplicates. Cross-category overlap remains possible where the same textbook legitimately supports multiple learning pathways; these are recorded as category-specific uses rather than silently deleted across the library.

## Cover resolution and fallbacks

The General collection now contains **7,344 books**, exceeding the requested 5,000-book target. Cover metadata was added for 7,159 records: 7,016 Project Gutenberg records use ebook-ID-matched official cover paths, and 143 other records use verified existing or title-matched page-specific cover URLs. The Flutter cover widget now accepts ordered fallback candidates and tries exact edition variants before showing the branded placeholder. Gutenberg records use the official medium cover, small cover, and embedded `images/cover.jpg` paths for the same ebook ID; Open Library and Internet Archive size/item variants remain available for records that already use those exact identifiers.

A bounded HTTP sample verified 309 working cover URLs across 263 sampled books. Some public sources rate-limit or omit cover images, so the app intentionally does not substitute a guessed title-only image. When all exact candidates fail, the branded placeholder is shown rather than displaying the wrong book.

## Important limitation

This is a **substantial first research batch, not a claim that all 80 categories are finished at 500+ books**. The two catalogs strongly cover academic, professional, historical, scientific, and some vocational subjects, but they do not provide enough current, category-specific, legally free books for every narrow trade or business category. Those categories were not artificially filled with irrelevant or questionable titles. They remain ready for additional targeted research from government agencies, universities, open publishers, author-controlled editions, FAO/ILO resources, and other legitimate sources.

Project Gutenberg works are public-domain supplements and may be historically dated. They must not replace current clinical, safety, regulatory, electrical, mechanical, agricultural, or professional standards. The category JSON notes and `actionRequired` fields identify this review need.

## Reproducibility

The repository includes scripts for auditing JSON schema and counts, fetching the Open Textbook Library catalog, analyzing subjects, selecting relevant catalog records, cleaning disallowed sources, merging additions, and running final quality checks. Raw catalogs and intermediate candidate dumps were intentionally not committed to avoid repository bloat; they can be regenerated from the official source URLs referenced in the scripts.

## References

[1]: https://open.umn.edu/opentextbooks "Open Textbook Library"
[2]: https://open.umn.edu/opentextbooks/discovery "Open Textbook Library Discovery and MARC Records"
[3]: https://www.gutenberg.org/ebooks/offline_catalogs.html "Project Gutenberg Offline Catalogs and Feeds"
[4]: https://www.gutenberg.org/help/public_domain_ebook_submission.html "Project Gutenberg Public Domain eBook Submission How-To"
