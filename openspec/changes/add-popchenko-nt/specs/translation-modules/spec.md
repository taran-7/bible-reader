## ADDED Requirements

### Requirement: Optional New Testament-only module
A manifest module SHALL be able to declare `coverage: nt` (27 books, 40…66, with 27 book names) and `optional: true`. The import SHALL skip an optional module whose file is absent and SHALL place a 27-book file on books 40…66. The app SHALL offer only translations whose text is in the database (FR-43).

#### Scenario: Build without the local text
- **WHEN** `data/raw/uk_popchenko.json` does not exist and the database is built
- **THEN** the build succeeds, the database has no `popchenko` verses and the translation is absent from every translation list

#### Scenario: A 27-book module
- **WHEN** the file has 27 books and `coverage: nt`
- **THEN** the verses land on books 40…66 and the book list has only the New Testament

#### Scenario: A wrong book count
- **WHEN** a `coverage: nt` module lists 66 book names
- **THEN** the manifest is rejected with an explanation

### Requirement: Reading a New Testament-only module
Switching to a New Testament-only module from an Old Testament book SHALL open Matthew 1; a reference or link to a book the module lacks SHALL NOT open an empty chapter; Compare and the parallel view SHALL show a "not in this translation" cell for such books; an Old Testament search scope SHALL return no results without an error (FR-43).

#### Scenario: Switch from Genesis
- **WHEN** the user reads Genesis 1 and selects «Попченко Ю.»
- **THEN** Matthew 1 opens

#### Scenario: Compare an Old Testament verse
- **WHEN** Genesis 1:1 is compared with «Попченко Ю.»
- **THEN** that column shows "Немає в цьому перекладі"

### Requirement: Local-only text with print fixes
`scripts/fetch_ppch.sh` SHALL download the source, convert it with `--nt` into the git-ignored `data/raw/uk_popchenko.json` and apply `scripts/ppch_print_fixes.json`; the converter SHALL fail if a `^` or an empty verse remains (FR-43).

#### Scenario: A source typo without a fix
- **WHEN** a verse contains `^` and has no entry in the fixes file
- **THEN** the conversion fails naming the verse

### Requirement: Module names in other features
The module's own short book names SHALL be used wherever a reference is shown for it, including the visit history rows of FR-42 (`Одкровення 22:21`). The coverage field SHALL allow a later extension to New Testament plus Psalms (FR-44) without a manifest format change.

#### Scenario: A history row
- **WHEN** Revelation 22:21 is visited in «Попченко Ю.»
- **THEN** its visit history row reads `Одкровення 22:21` (FR-42)
