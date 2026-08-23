# Finreels Free-Book Research Policy

## Scope

Finreels’ book collection is intended to support structured non-fiction learning pathways. A book may be added only when it is real, relevant to the target category, and legally accessible at no cost.

## Preferred source tiers

| Tier | Source type | Examples | Use rule |
|---|---|---|---|
| 1 | Openly licensed academic textbooks | Open Textbook Library, OpenStax, BCcampus, LibreTexts, university presses | Accept when the catalog record identifies a license and a $0 online/PDF/eBook format. |
| 2 | Public-domain collections | Project Gutenberg, Standard Ebooks, HathiTrust public-domain records, government publications | Accept when the item is clearly public domain and the source provides the complete text or download. |
| 3 | Official institutional or author-controlled editions | Universities, government agencies, author/publisher sites | Accept when the complete book or manual is free without a paid subscription or purchase. |
| 4 | Other legitimate repositories | Reputable non-profit or library repositories | Accept only after confirming that access is complete, legal, and not merely a preview or an unauthorized upload. |

## Exclusions

Do not add entries that are hosted on piracy or file-sharing sites, that provide only a preview or sample chapter, that require payment or a paid membership, that have an unverified or generic URL, or that are not clearly non-fiction and relevant to the category.

## Metadata requirements

Each entry should retain the existing repository fields: title, author, free source URL, source type, source note, verification date, verification method, and optional cover URL. Where the upstream catalog provides a license, publisher, ISBN, or library record, preserve that evidence in the verification method or source note.

## Deduplication

Deduplicate by normalized title plus author, and also check ISBN-13 when available. Keep the most authoritative and direct free source. Do not duplicate a general textbook into a narrow trade category unless the subject mapping is clear and useful to that pathway.

## Current repository finding

The current repository contains 81 resource JSON files: 80 named categories plus `_general.json`. It contains 840 book records, generally 10 per category and 40 in General. The initial audit found no JSON schema errors, but it found cross-category title overlap and several entries whose third-party or generic URLs require re-verification against the policy above before they can be considered compliant.

## Initial authoritative catalog

The Open Textbook Library’s published catalog was downloaded from its discovery CSV. Its own documentation states that the catalog contains openly licensed textbooks and that its records are CC0; the catalog currently contains 1,871 rows including the header, with 1,870 textbook records. The catalog exposes license, subject, publisher, library URL, and free-format URLs, making it suitable for a reproducible first import pass.

## Research status

The Open Textbook Library catalog is a source pool, not an automatic guarantee that every title belongs in every Finreels category. Titles will be mapped only when their subject metadata and description support a category assignment. Trade-specific categories with insufficient open-textbook coverage require additional targeted source research rather than artificial filling.
