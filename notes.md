# Splash restore + Online Hustles in onboarding

## Diagnosed
1. `resource_categories.json` already contains **20** `online_hustle` categories and matching
   `assets/data/resources/online_hustles_*.json` files.
2. `ResourceSection` enum only had `skill | business | profession`. Parsing
   `section: "online_hustle"` threw `ArgumentError`, which aborted the **entire**
   categories load (`ResourceCategoryData.load`), so onboarding could not list
   Online Hustles (and risked empty/partial category UI).
3. `CategorySearch.sectionOrder` omitted Online Hustles, so even a successful
   parse would not show them on My Business / Discover onboarding.

## Fixes
| File | Change |
|------|--------|
| `lib/models/resource_category.dart` | Add `onlineHustle`; JSON `online_hustle`; labels; `assetKey` |
| `lib/utils/category_search.dart` | Append `ResourceSection.onlineHustle` to `sectionOrder` |
| `lib/data/category_playbook_data.dart` | Exhaustive switches + playbook asset key |
| `lib/screens/splash_screen.dart` | Restored first-package splash (gold play mark, **by chAs**, 2.8s timer) |

## Onboarding order now
1. Professions  
2. Skills & Trades  
3. Businesses  
4. **Online Hustles** (20 categories)  
5. Others  

## Copy into repo
```
lib/models/resource_category.dart
lib/utils/category_search.dart
lib/data/category_playbook_data.dart
lib/screens/splash_screen.dart
```

No JSON changes required — the 20 online hustle entries are already present.
