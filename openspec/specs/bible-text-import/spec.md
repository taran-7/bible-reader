# bible-text-import Specification

## Purpose

Turns the KJV and Synodal source texts into the database from which the app reads verses and runs text search.

Requirements in [docs/requirements.md](../../../docs/requirements.md): FR-1, FR-2, FR-3, FR-28, FR-29.

## Requirements

### Requirement: Import of both translations
The import tool SHALL read the KJV and Synodal source JSON files and write all verses into one database with the translation tag, book number (1–66), chapter and verse.

#### Scenario: Full import
- **WHEN** the import runs on `data/raw` with both files
- **THEN** the database contains 66 books for each translation
- **AND** the KJV verse count matches the count in the source file (≈31,102)

#### Scenario: Control verses
- **WHEN** the import is finished
- **THEN** KJV Genesis 1:1 starts with "In the beginning God created"
- **AND** Synodal Бытие 1:1 starts with «В начале сотворил Бог»
- **AND** KJV John 3:16 and Synodal Иоанна 3:16 are present and non-empty

### Requirement: Full-text index
The import SHALL build a full-text index over verse text that is case- and diacritic-insensitive, for Latin and Cyrillic.

#### Scenario: Index is filled
- **WHEN** the import is finished
- **THEN** the number of index entries equals the number of verses

### Requirement: Input data error
The import MUST exit with a non-zero code and a clear message if a source file is missing or has an unexpected format, and MUST NOT leave a partially written database.

#### Scenario: Missing file
- **WHEN** the input folder lacks the file of one of the translations
- **THEN** the import exits with an error naming the missing file
- **AND** the output database is not created

### Requirement: Ukrainian and Czech texts
The import SHALL write four translations into the database (KJV, Synodal, Ohienko and Bible kralická), 66 books each; an empty verse in the input file SHALL be skipped without shifting the numbers of the following verses (FR-28, FR-29).

#### Scenario: Control verses
- **WHEN** the import has finished
- **THEN** Ohienko Буття 1:1 starts with «На початку Бог створив», and BKR Gn 1:1 with «Na počátku stvořil Bůh»

#### Scenario: Skipped verse
- **WHEN** in a chapter of the input file verse 1 is empty and verse 2 is filled
- **THEN** the database has no verse 1, and verse 2 has number 2

### Requirement: Incomplete input file
The import SHALL reject a translation file with fewer than 66 books: the CLI SHALL exit with code 1 and a stderr message naming the file, and the database SHALL NOT be created. A call without two arguments SHALL exit with code 64 and a usage hint (FR-3).

#### Scenario: Truncated JSON
- **WHEN** `en_kjv.json` contains 2 books
- **THEN** `bible-import` exits with code 1, stderr contains `en_kjv.json`, there is no output file

#### Scenario: No arguments
- **WHEN** `bible-import` is run without arguments
- **THEN** the exit code is 64, stderr starts with «Використання:» (Usage:)
