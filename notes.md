# Splash + Online Hustles onboarding + test fix

## CI failure
```
CategorySearch sectionOrder is Profession, then Skill, then Business (failed)
```
The production `sectionOrder` correctly includes `ResourceSection.onlineHustle`.
The unit test still expected the old 3-section list.

## Files to copy
```
lib/models/resource_category.dart
lib/utils/category_search.dart
lib/data/category_playbook_data.dart
lib/screens/splash_screen.dart
lib/screens/discover_screen.dart          # comment only
lib/screens/my_business_screen.dart       # comment only
test/finreels_test.dart                   # sectionOrder + othersId regex
```

Expected order after fix:
Profession → Skill → Business → Online Hustle
