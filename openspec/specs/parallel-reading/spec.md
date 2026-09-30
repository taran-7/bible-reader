# parallel-reading Specification

## Purpose
Two translations side by side and the KJV ↔ Synodal numbering mapping table: parallel rows, switching translation while keeping the verse, user data on the corresponding verse.

Requirements in [docs/requirements.md](../../../docs/requirements.md): FR-26, FR-27.

## Requirements

### Requirement: Parallel view
The user SHALL be able to show a second translation alongside: each row holds a verse of the main translation and the corresponding verses of the second, so scrolling is synchronized. The choice of the second translation SHALL persist between launches.

#### Scenario: A psalm with a superscription
- **WHEN** Ps 22 is open in KJV and the Synodal is chosen alongside
- **THEN** next to KJV Ps 22:1 stand Synodal Ps 21:1 (superscription) and 21:2

#### Scenario: A verse at a chapter boundary
- **WHEN** Jonah 1 is open in KJV with the Synodal alongside
- **THEN** next to Jonah 1:17 stands Synodal Jonah 2:1

### Requirement: Numbering mapping table
The system SHALL map verses of KJV (and translations with the same numbering) to Synodal verses and back: Psalms per the Septuagint with superscriptions, chapter boundaries and merged verses in other books. Verses without a counterpart (Septuagint additions) SHALL have no pair.

#### Scenario: PRD criterion
- **WHEN** KJV Ps 22:1 is mapped
- **THEN** the result is Synodal Ps 21:2, and vice versa

#### Scenario: Completeness
- **WHEN** every KJV verse is mapped
- **THEN** each has an existing Synodal verse

### Requirement: Switching translation keeps the verse
Switching translation SHALL open the chapter and verse with the same content in the new translation's numbering: the first selected verse, and without a selection, the chapter of the first verse. Notes, highlights and bookmarks SHALL show on the corresponding verse in any translation.

#### Scenario: Ps 22:1 → Synodal
- **WHEN** Ps 22:1 is selected in KJV and the Synodal is switched on
- **THEN** Ps 21 opens with verse 2 selected

#### Scenario: A note in the Synodal
- **WHEN** KJV Ps 22:1 has a note and Synodal Ps 21 is open
- **THEN** the note icon is next to verse 2
