# translation-modules Specification

## Purpose
Translations as modules: a file in `data/raw` and a manifest line, no code changes; manifest validation.

Requirements in [docs/requirements.md](../../../docs/requirements.md): FR-30.

## Requirements

### Requirement: A translation as a module
A translation SHALL be added with a file in `data/raw` and a line in the translation manifest without code changes: the manifest sets the code, title, language, numbering and file; manifest order is menu order.

#### Scenario: A new translation in an existing language
- **WHEN** `web` in English with the file `en_web.json` is added to the manifest and the database is rebuilt
- **THEN** the translation has books and verses from the file, search works in it, references are in English (`John 3:16`)

#### Scenario: A new language
- **WHEN** a module in the `pl` language brings 66 book names
- **THEN** names and references come from the module, and search matches exact word forms

### Requirement: Manifest validation
The manifest SHALL be rejected if a code repeats, the numbering is unknown, a language without built-in names lacks 66 book names, or the JSON is corrupted.

#### Scenario: A language without book names
- **WHEN** a module in the `pl` language has no `books` list
- **THEN** loading the manifest fails with an explanation

### Requirement: A new numbering system
A manifest module SHALL be able to declare its own numbering system (`numbering`) with a mapping table to KJV (`versification.segments`); verses outside the segments have the same number as in KJV, and between two non-KJV systems a verse SHALL be mapped through KJV. A manifest with an unknown system without a table SHALL be rejected (FR-30).

#### Scenario: Vulgate
- **WHEN** the `vulgate` module declares that KJV Ps 10:1 is its Ps 9:22
- **THEN** Vulgate Ps 9:22 corresponds to KJV Ps 10:1 and Synodal Ps 9:22

#### Scenario: A system without a table
- **WHEN** a module declares `numbering: lxx` without a `versification` field
- **THEN** the manifest is rejected with an explanation

### Requirement: Translation shortcuts on any layout
⌘⌥1…9 SHALL switch the translation by the physical digit-row key regardless of the keyboard layout (FR-30).

#### Scenario: Czech layout
- **WHEN** the Czech layout is active and the user presses ⌘⌥ with the digit-row key "1"
- **THEN** the first translation from the manifest opens
