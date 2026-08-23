# General Expansion and Cover Research Notes

## Authoritative free-book sources

- Open Textbook Library: https://open.umn.edu/opentextbooks
  - Open textbooks are licensed by authors and publishers to be freely used and adapted.
  - Discovery/API page: https://open.umn.edu/opentextbooks/discovery
  - The discovery page provides a downloadable CSV and JSON API; records include licenses, subjects, publishers, ISBNs, and zero-cost format URLs.
- Project Gutenberg offline catalogs: https://www.gutenberg.org/ebooks/offline_catalogs.html
  - Official machine-readable metadata is available as CSV/XML/RDF.
  - Project Gutenberg states that its collection is focused on works in the public domain in the United States.
- Project Gutenberg public-domain submission policy: https://www.gutenberg.org/help/public_domain_ebook_submission.html
  - Project Gutenberg only accepts works that are in the U.S. public domain.
- Open Book Publishers: https://www.openbookpublishers.com/
  - Scholar-led, non-profit open-access publisher; books are available to read online or download for free.
- DOAB/OAPEN: https://openbookcollective.org/initiatives/initiative/11/
  - DOAB indexes scholarly peer-reviewed open-access books; OAPEN provides free access and openly available metadata.

## Current General baseline

- `_general.json` currently has 1,578 book records.
- The repository currently has 4,711 total book records across 81 resource JSON files.
- The current quality script reports valid JSON, no missing required book fields, no blank authors, no missing URLs, no disallowed ebook hosts, and no within-file duplicates.

## Cover implementation findings

- `lib/models/resource_category.dart` defines `VerifiedBook.coverUrl` as an optional single direct cover-image URL.
- `lib/widgets/book_cover_image.dart` currently accepts only one `url` field and generates limited fallbacks:
  - Open Library ISBN `L/M/S` variants and compact ISBN variants.
  - Open Library ID variants.
  - Internet Archive `services/img` and `__ia_thumb.jpg` variants.
- Most General entries added from Project Gutenberg do not currently have `coverUrl` because the Gutenberg catalog supplies ebook metadata but not stable cover-image URLs in the imported schema.
- Exact matching should prefer an edition-specific identifier (ISBN-13, Gutenberg ebook ID, or OAPEN handle) and should not use a generic title-only cover when an edition-specific cover is unavailable.
- A resilient implementation should support an ordered list of cover candidates while preserving backwards compatibility with existing `coverUrl` records. Candidate order should prefer an exact edition cover, then a verified catalog-specific cover, then a provider fallback, then the branded placeholder.

## Cover source candidates to evaluate

- Open Library Covers API: https://covers.openlibrary.org/
  - Best for ISBN-specific edition covers where the ISBN is known.
- Project Gutenberg ebook pages: https://www.gutenberg.org/
  - Stable ebook IDs can be used to reference the exact Gutenberg edition; cover extraction should be tested against the actual ebook page or assets rather than guessed from title.
- Internet Archive item covers: https://archive.org/services/img/
  - Use only when the item identifier is known and the cover corresponds to the specific edition.
- OAPEN Library handles: https://library.oapen.org/
  - Use item-specific handles when the exact open-access edition is known.

## Legal and quality cautions

- Do not treat a title-only cover lookup as exact edition matching.
- Do not add fabricated covers, guessed ISBNs, or generic stock covers as exact covers.
- If no exact cover can be verified, store the record without an exact cover and let the app show a branded placeholder after exhausting verified fallbacks.
- Historical public-domain books may be outdated for clinical, safety, regulatory, electrical, mechanical, and agricultural practice; they are supplemental, not current standards.
