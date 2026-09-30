# Bible Reader MVP

## The user can
- choose a translation: KJV, Synodal, Ohienko (Ukrainian) or Kralická (Czech), one on screen, via a toolbar menu or ⌘⌥1…4 (v2.1, `add-translations`);
- go book → chapter and page through chapters with ◀ ▶;
- search for a word or phrase in the active translation and open the found verse;
- type a reference (`Ин 3:16`, `John 3`) and jump to it;
- copy verses with a reference: `«текст» (От Иоанна 3:16)`, range `От Иоанна 3:16-18`;
- change verse text size (⌘+ / ⌘− / ⌘0, Settings), book list size and interface scale (Settings); the choice persists (v1.1, `add-reading-comfort`);
- copy selected verses with a button above the selection, confirmed by "Copied" (v1.1, `add-copy-button`);
- choose a theme: System, Light, Dark, Glass, Pastel, Manuscript (v1.1, `add-themes`).

## Non-goals of the MVP
- parallel view of translations;
- verse numbering map;
- bookmarks, notes, Strong's dictionaries, other modules.

## Acceptance criteria
- `swift test` is green: import (66 books, control verses), `Reference`, search (case, Cyrillic, special characters).
- Manual check of the scenarios above in the built app.
