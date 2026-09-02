# Profession Resource Catalog Audit

This report is generated from the supplied MBBS CSV and the checked-in Rumuo resource assets. It is an audit only; it does not treat copyrighted textbook titles as free resources and does not add any unverified links.

## Input coverage

- Supplied MBBS rows: **36**.
- Profession JSON files found: **20**.
- All resource JSON files scanned: **81**.
- Existing book records scanned: **10477**.
- Duplicate title/author/source groups: **790**.

## Profession coverage

| Profession asset | Category | Books | Channels | Blogs | Last updated |
|---|---|---:|---:|---:|---|
| `profession_01_medicine` | Medicine | 93 | 20 | 20 | 2026-08-23 |
| `profession_02_law` | Law | 119 | 20 | 20 | 2026-08-23 |
| `profession_03_pharmacy` | Pharmacy | 14 | 20 | 20 | 2026-08-23 |
| `profession_04_nursing` | Nursing | 40 | 20 | 20 | 2026-08-23 |
| `profession_05_accounting` | Accounting | 27 | 20 | 20 | 2026-08-23 |
| `profession_06_engineering` | Engineering | 139 | 20 | 20 | 2026-08-23 |
| `profession_07_architecture` | Architecture | 68 | 20 | 20 | 2026-08-23 |
| `profession_08_estate_management_surveying` | Estate Management/Surveying | 19 | 20 | 20 | 2026-08-23 |
| `profession_09_banking_finance` | Banking & Finance | 70 | 20 | 20 | 2026-08-23 |
| `profession_10_mass_communication_media_pr` | Mass Communication/Media & PR | 72 | 20 | 20 | 2026-08-23 |
| `profession_11_computer_science_software_engineering` | Computer Science/Software Engineering | 156 | 20 | 20 | 2026-08-23 |
| `profession_12_agriculture` | Agriculture | 88 | 20 | 20 | 2026-08-23 |
| `profession_13_education` | Education | 172 | 20 | 20 | 2026-08-23 |
| `profession_14_dentistry` | Dentistry | 28 | 20 | 20 | 2026-08-23 |
| `profession_15_psychology_counselling` | Psychology/Counselling | 56 | 20 | 20 | 2026-08-23 |
| `profession_16_fashion_design_tailoring` | Fashion Design & Tailoring (Trade) | 58 | 20 | 20 | 2026-08-23 |
| `profession_17_hairdressing_cosmetology` | Hairdressing/Cosmetology (Trade) | 8 | 20 | 20 | 2026-08-23 |
| `profession_18_catering_event_planning` | Catering & Event Planning (Trade) | 48 | 20 | 20 | 2026-08-23 |
| `profession_19_automobile_technology` | Automobile Technology (Trade) | 61 | 20 | 20 | 2026-08-23 |
| `profession_20_photography_videography` | Photography & Videography (Trade) | 116 | 20 | 20 | 2026-08-23 |

## Existing book-data quality signals

| Signal | Count |
|---|---:|
| With license signal | 1652 |
| Without license signal | 8825 |

### Source types

| Type | Count |
|---|---:|
| `course` | 16 |
| `download` | 132 |
| `ebook` | 120 |
| `online` | 8768 |
| `pdf` | 856 |
| `video` | 1 |
| `web` | 584 |

### Regions explicitly recorded on book records

| Region | Count |
|---|---:|
| Global | 35 |
| unspecified | 10442 |

## Supplied MBBS CSV subjects

| Stage | Subject | Approximate years | Rows |
|---|---|---|---:|
| Clinical | Clinical Skills / Handbook | Year 4-6 | 2 |
| Clinical | Internal Medicine | Year 4-6 | 4 |
| Clinical | Obstetrics & Gynaecology | Year 4-6 | 3 |
| Clinical | Paediatrics | Year 4-6 | 2 |
| Clinical | Psychiatry | Year 4-6 | 1 |
| Clinical | Surgery | Year 4-6 | 2 |
| Para-clinical | Community Medicine / Public Health | Year 2-4 | 1 |
| Para-clinical | Microbiology | Year 2-4 | 2 |
| Para-clinical | Pathology | Year 2-4 | 2 |
| Para-clinical | Pharmacology | Year 2-4 | 2 |
| Pre-clinical | Anatomy (Atlas) | Year 1-2 | 2 |
| Pre-clinical | Anatomy (Gross) | Year 1-2 | 3 |
| Pre-clinical | Biochemistry | Year 1-2 | 2 |
| Pre-clinical | Embryology | Year 1-2 | 2 |
| Pre-clinical | Histology | Year 1-2 | 1 |
| Pre-clinical | Neuroanatomy | Year 1-3 | 2 |
| Pre-clinical | Physiology | Year 1-2 | 3 |

## Research and integration policy

The next catalog pass should add only resources with a directly verifiable free access path and an explicit legal basis such as an open textbook license, public-domain status, an official government or institutional open publication, or a publisher-authorized free edition. Commercial textbook titles in the supplied MBBS list are useful as curriculum references, but they must not be linked as free books unless an authorized open copy is verified.

Resources should be tagged by profession, subject, progression level, geography, source type, license evidence, verification date, and canonical URL. A single global textbook may be linked to multiple profession categories only when the subject overlap is explicit; duplicate records should be canonicalized rather than copied blindly.
