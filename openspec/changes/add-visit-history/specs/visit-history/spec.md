## ADDED Requirements

### Requirement: Visit history
The app SHALL keep a flat list of visited verses, newest first, and show it in a panel to the right of the reading area (FR-42). A visit is a jump to a verse (reference search, search result, link from a draft, Compare, bookmark) or a click or selection of a verse; a plain chapter open (◀ ▶, book list) records the chapter without a verse. A row SHALL be only the book name and chapter:verse in the translation's language. The list SHALL survive a restart and SHALL have a "Clear history" action.

#### Scenario: A row after a jump
- **WHEN** the user searches for `Ин 3:16` in the Synodal
- **THEN** the top row reads `От Иоанна 3:16`

#### Scenario: A chapter only
- **WHEN** the user opens a chapter with ▶
- **THEN** the top row is the chapter without a verse, e.g. `От Иоанна 4`

#### Scenario: Survives a restart
- **WHEN** the app is restarted
- **THEN** the same rows are in the same order

### Requirement: Deduplicated and limited
The same translation and verse SHALL move to the top instead of duplicating; the same verse in another translation is a separate entry. The list SHALL hold at most 50 entries: a new entry goes to the top, everything shifts down, and the entry that would become the 51st is deleted (FR-42).

#### Scenario: Revisit
- **WHEN** John 3:16 in KJV is visited, then Genesis 1:1, then John 3:16 in KJV again
- **THEN** the list has two entries and John 3:16 is on top

#### Scenario: The 51st visit
- **WHEN** 51 different verses are visited
- **THEN** the list has 50 entries and the first visit is gone

### Requirement: Opening an entry
A click on a row SHALL open the verse in the translation it was visited in, scroll to it and highlight it. In Compare or the parallel view the mode SHALL be kept and navigated to the verse, with the entry's translation as the main one (FR-42).

#### Scenario: Another translation
- **WHEN** Ohienko John 3:16 was visited, KJV is open, and the row `Івана 3:16` is clicked
- **THEN** Ohienko opens at John 3:16 with the verse highlighted

#### Scenario: Compare stays
- **WHEN** Compare is open and a row is clicked
- **THEN** Compare shows the row's chapter with the verse highlighted

### Requirement: Panel layout
The panel SHALL be a separate column next to the reading area, so the selection highlight and the selection buttons never overlap it. The selection buttons SHALL stand right after the ~75-character text column, inside the column when the gap is too narrow, and at the reading area's right edge in the parallel view. With Drafts or Illustrations open the panel SHALL hide unless a toolbar toggle shows it; then the text column narrows (FR-42).

#### Scenario: Selection next to the text
- **WHEN** verse 2 is selected in a wide window
- **THEN** the selection buttons stand next to the text column, left of the panel, and the history row at the same height stays clickable
