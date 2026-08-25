# FinReels General Library Additions — 25 August 2026

## Scope and selection method

This batch adds **13 source-verified open textbooks** to the General library. The selection prioritizes practical business, law, technology, communication, nursing, and professional-learning material that is openly accessible online or as a PDF/eBook. Records were accepted only when the publisher or Open Textbook Library record exposed a stable source page and an explicit open license or official free-access statement. The catalog does not present title-only cover matches as exact editions.

## Verified additions

| Title | Verified source | Access/license evidence | Cover decision |
|---|---|---|---|
| Law for Entrepreneurs | [Open Textbook Library](https://open.umn.edu/opentextbooks/textbooks/law-for-entrepreneurs) | Online/PDF; CC BY-NC-SA; ISBN 9781453344170 | Open Library ISBN cover candidate |
| Business Law, Ethics, and Sustainability | [Open Textbook Library](https://open.umn.edu/opentextbooks/textbooks/business-law-ethics-and-sustainability) | Online/PDF; CC BY-NC-SA; 2023 OpenHawks OER | No independently verified ISBN cover; branded fallback |
| Introduction to Business — 2e | [Open Textbook Library](https://open.umn.edu/opentextbooks/textbooks/introduction-to-business-2e) | OpenStax; Online/PDF/Audiobook; CC BY; ISBN 9781947172555 | Open Library ISBN cover candidate |
| Exploring Business | [Open Textbook Library](https://open.umn.edu/opentextbooks/textbooks/15) | Online/PDF; CC BY-NC-SA; ISBN 9781946135094 | Open Library ISBN cover candidate |
| Project Management from Simple to Complex | [Open Textbook Library](https://open.umn.edu/opentextbooks/textbooks/project-management-from-simple-to-complex) | Online/PDF; CC BY-NC-SA; ISBN 9781946135216 | Open Library ISBN cover candidate |
| Risk Management for Enterprises and Individuals | [Open Textbook Library](https://open.umn.edu/opentextbooks/textbooks/risk-management-for-enterprises-and-individuals) | PDF/Online; CC BY-NC-SA; ISBN 9780982361801 | Open Library ISBN cover candidate |
| Sustainability, Innovation, and Entrepreneurship | [Open Textbook Library](https://open.umn.edu/opentextbooks/textbooks/sustainability-innovation-and-entrepreneurship) | PDF/Online; CC BY-NC-SA; ISBN 9781453314128 | Open Library ISBN cover candidate |
| Effective Professional Communication: A Rhetorical Approach | [Open Textbook Library](https://open.umn.edu/opentextbooks/textbooks/effective-professional-communication-a-rhetorical-approach) | eBook/Online/PDF/XML/ODF; CC BY-NC-SA; 2021 University of Saskatchewan edition | No independently verified ISBN cover; branded fallback |
| Database Design — 2nd Edition | [Open Textbook Library](https://open.umn.edu/opentextbooks/textbooks/database-design-2nd-edition) | PDF/Online/eBook; CC BY; BCcampus | No independently verified ISBN cover; branded fallback |
| Introduction to Computer Science | [OpenStax](https://openstax.org/details/books/introduction-computer-science) | Official free online/PDF; CC BY-NC-SA; digital ISBN 9781711471839; Web updated April 2026 | Open Library ISBN cover candidate |
| Nursing: Mental Health and Community Concepts | [Open Textbook Library](https://open.umn.edu/opentextbooks/textbooks/nursing-mental-health-and-community-concepts) | Online/PDF; CC BY; ISBN 9781734914160 | Open Library ISBN cover candidate |
| Transitions to Professional Nursing Practice — 2nd Edition | [Open Textbook Library](https://open.umn.edu/opentextbooks/textbooks/transitions-to-professional-nursing-practice-2nd-edition) | PDF/Online/eBook; CC BY; ISBN 9781641760904 | Open Library ISBN cover candidate |
| Nursing Assistant | [Open Textbook Library](https://open.umn.edu/opentextbooks/textbooks/nursing-assistant) | eBook/PDF/Online; CC BY; ISBN 9781734914115 | Open Library ISBN cover candidate |

## Cover policy

The generated asset `assets/books/finreels_book_cover_fallback.png` is a branded **FinReels Open Library** cover. `BookCoverImage` now uses it for missing, empty, or exhausted cover candidates, and retains the small icon-only fallback only if the bundled asset itself cannot be decoded. Exact-edition candidates remain identifier-driven: ISBN URLs are allowed when the ISBN is verified by the source record, while the three records without an independently verified ISBN cover intentionally use the branded fallback rather than an unrelated title search result.

The cover delivery chain still tries direct URLs, bounded `wsrv.nl` and legacy `images.weserv.nl` alternatives, provider size variants, Gutenberg variants, and Internet Archive variants only when the source URL or identifier identifies the same edition/work. This is a best-effort delivery chain; public image hosts can impose rate limits, origin filters, or availability changes.

## References

1. [OpenStax Subjects — openly licensed free textbooks](https://openstax.org/subjects)
2. [Open Textbook Library — Business Textbooks](https://open.umn.edu/opentextbooks/subjects/business)
3. [OpenStax — Introduction to Computer Science](https://openstax.org/details/books/introduction-computer-science)
4. [Open Textbook Library — Law for Entrepreneurs](https://open.umn.edu/opentextbooks/textbooks/law-for-entrepreneurs)
5. [Open Textbook Library — Business Law, Ethics, and Sustainability](https://open.umn.edu/opentextbooks/textbooks/business-law-ethics-and-sustainability)
6. [Open Textbook Library — Introduction to Business 2e](https://open.umn.edu/opentextbooks/textbooks/introduction-to-business-2e)
7. [Open Textbook Library — Exploring Business](https://open.umn.edu/opentextbooks/textbooks/15)
8. [Open Textbook Library — Project Management from Simple to Complex](https://open.umn.edu/opentextbooks/textbooks/project-management-from-simple-to-complex)
9. [Open Textbook Library — Risk Management for Enterprises and Individuals](https://open.umn.edu/opentextbooks/textbooks/risk-management-for-enterprises-and-individuals)
10. [Open Textbook Library — Sustainability, Innovation, and Entrepreneurship](https://open.umn.edu/opentextbooks/textbooks/sustainability-innovation-and-entrepreneurship)
11. [Open Textbook Library — Effective Professional Communication](https://open.umn.edu/opentextbooks/textbooks/effective-professional-communication-a-rhetorical-approach)
12. [Open Textbook Library — Database Design 2nd Edition](https://open.umn.edu/opentextbooks/textbooks/database-design-2nd-edition)
13. [Open Textbook Library — Nursing: Mental Health and Community Concepts](https://open.umn.edu/opentextbooks/textbooks/nursing-mental-health-and-community-concepts)
14. [Open Textbook Library — Transitions to Professional Nursing Practice 2nd Edition](https://open.umn.edu/opentextbooks/textbooks/transitions-to-professional-nursing-practice-2nd-edition)
15. [Open Textbook Library — Nursing Assistant](https://open.umn.edu/opentextbooks/textbooks/nursing-assistant)
