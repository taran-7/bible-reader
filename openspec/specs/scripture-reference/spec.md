# scripture-reference Specification

## Purpose

Recognizes scripture references typed by the user and formats quotes with a reference for copying.

Requirements in [docs/requirements.md](../../../docs/requirements.md): FR-8, FR-9, FR-10, FR-17, FR-28, FR-29.

## Requirements

### Requirement: Reference parsing
The system SHALL recognize references of the form `<book> <chapter>`, `<book> <chapter>:<verse>` and `<book> <chapter>:<verse>-<verse>`, where the book is given by its full name or abbreviation in English or Russian, case-insensitive, with or without a period after the abbreviation.

#### Scenario: A Russian abbreviation with a verse
- **WHEN** `Ин 3:16` is entered
- **THEN** the result is book 43, chapter 3, verse 16

#### Scenario: An English name, chapter only
- **WHEN** `John 3` is entered
- **THEN** the result is book 43, chapter 3, no verse

#### Scenario: Range
- **WHEN** `ин. 3:16-18` is entered
- **THEN** the result is book 43, chapter 3, verses 16–18

#### Scenario: Numbered books
- **WHEN** `1 Кор 13:4` or `1 Cor 13:4` is entered
- **THEN** the result is book 46, chapter 13, verse 4

#### Scenario: Not a reference
- **WHEN** `любовь` or `Xyz 3:16` is entered
- **THEN** parsing returns "not a reference"

### Requirement: Quote formatting
The system SHALL format a single copied verse as `«text» (<book name> <chapter>:<verse>)`, and several verses with a number before each verse, each verse on a new line and the reference on a separate line: `«<n> text⏎<n> text»⏎(<book name> <chapter>:<first>-<last>)`. The book name is full, in the active translation's language; non-consecutive numbers are written as `16-17,19`.

#### Scenario: One verse
- **WHEN** Иоанна 3:16 is copied in the Synodal
- **THEN** the clipboard holds `«Ибо так возлюбил Бог мир…» (От Иоанна 3:16)`

#### Scenario: A range in KJV
- **WHEN** John 3:16–18 is copied in KJV
- **THEN** the clipboard holds three verse lines with numbers `«16 …`, `17 …`, `18 …»` and the line `(John 3:16-18)`

#### Scenario: Full book name
- **WHEN** 2 Kings 4:16 is copied in KJV
- **THEN** the reference at the end is `(2 Kings 4:16)`, not `(2 Kgs 4:16)`

### Requirement: Copying in the app
The app SHALL copy selected verses in quote format via ⌘C and the context menu.

#### Scenario: Copying via the menu
- **WHEN** the user selects verses 16–18 and chooses «Копіювати» (Copy) in the context menu
- **THEN** the clipboard contains a quote with the reference `3:16-18`

### Requirement: Copy button on the selection
When one or more verses are selected, the app SHALL show above the first selected verse, in the top right corner, a wide semi-transparent button with an icon and the label «Копіювати» (Copy) that does not cover verse text. A click SHALL put the same quote on the clipboard as ⌘C and for ~1.5 s show «Скопійовано» (Copied) of the same width in its place (FR-17).

#### Scenario: No selection
- **WHEN** no verse is selected
- **THEN** there is no copy button

#### Scenario: Copying with the button
- **WHEN** John 3:16 is selected and the user clicks the copy button
- **THEN** the clipboard contains `«…» (John 3:16)`, as after ⌘C
- **AND** «Скопійовано» is visible in place of the button, and after ~1.5 s the button again

#### Scenario: Several verses
- **WHEN** verses 16–18 are selected and the user clicks the copy button
- **THEN** the button is above verse 16, and the clipboard contains the quote `(John 3:16-18)`

### Requirement: References in Ukrainian and Czech
Reference parsing SHALL accept Ukrainian and Czech book names and abbreviations, and the reference and quote SHALL be formatted in the on-screen translation's language (FR-28, FR-29).

#### Scenario: A Ukrainian abbreviation
- **WHEN** the user searches `Ів 3:16`
- **THEN** the Gospel of John, chapter 3, verse 16 opens

#### Scenario: A Czech abbreviation
- **WHEN** the user searches `J 3:16`
- **THEN** the Gospel of John, chapter 3, verse 16 opens

#### Scenario: A quote in Ukrainian
- **WHEN** the user copies Ів 3:16 in the Ohienko translation
- **THEN** the quote ends with `(Від Івана 3:16)`

### Requirement: Book number without a space
Reference parsing SHALL accept the book number both with and without a space before the name or abbreviation (FR-8).

#### Scenario: 1Ин
- **WHEN** `1Ин 4:8` is entered
- **THEN** the result is book 62, chapter 4, verse 8
