# verse-compare Specification

## Purpose
"Compare" (Порівняти): a mode in the main window: the chapter in columns for the chosen translations, rows aligned by verse, selected verses highlighted.

Requirements in [docs/requirements.md](../../../docs/requirements.md): FR-36.

## Requirements

### Requirement: Chapter comparison in the main window
On a selection of one or more verses there SHALL be a "Compare" button next to copy, and a context menu item. They SHALL open a translation picker with checkboxes (the on-screen translation is not offered, it is always the first column), and after "Compare" a comparison mode in the same window: the whole chapter in columns by translation, rows aligned by the on-screen translation's verses via the mapping table (FR-26), selected verses highlighted and scrolled into view. The header of each column SHALL be the book name in its translation's language. ✕ or Esc SHALL return to reading; moving to another chapter or translation SHALL close the comparison.

#### Scenario: Columns in the main window
- **WHEN** John 3:16 is selected in KJV, "Compare" is pressed, Kralická is unchecked and "Compare" is pressed
- **THEN** the same window shows columns KJV, Ohienko, Synodal with the whole chapter 3, verse 16 highlighted, verse 15 also visible

#### Scenario: Synodal numbering
- **WHEN** Ps 22 in KJV is compared with the Synodal
- **THEN** next to KJV Ps 22:1 stand Synodal Ps 21:1–2, and the column header is «Псалтирь 22»

#### Scenario: Back to reading
- **WHEN** Esc is pressed in comparison mode
- **THEN** the chapter text is visible again

### Requirement: Choosing translations to compare
Translations checked in the picker SHALL persist between launches; at least one translation stays selected.

#### Scenario: The choice survives a restart
- **WHEN** Kralická was unchecked and the app restarted
- **THEN** in the picker Kralická is unchecked, the rest are checked
