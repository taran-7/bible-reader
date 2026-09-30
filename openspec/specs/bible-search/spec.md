# bible-search Specification

## Purpose

Lets the user find verses by a word or phrase in the active translation, or jump to a typed reference.

Requirements in [docs/requirements.md](../../../docs/requirements.md): FR-11, FR-12, FR-13, FR-14, FR-18, FR-19, FR-20, FR-21.

## Requirements

### Requirement: Text search
The system SHALL search for verses containing all query words in any of their forms (by word stem), only in the active translation, case-insensitive; results SHALL contain a reference and the verse text with matches highlighted and SHALL be ordered by book order.

#### Scenario: Latin
- **WHEN** `love` is searched in KJV
- **THEN** the results are non-empty and every verse contains a word with the stem "lov" in any case

#### Scenario: Cyrillic and case
- **WHEN** `ЛЮБОВЬ` is searched in the Synodal
- **THEN** the results are the same as for `любовь`

#### Scenario: Active translation only
- **WHEN** `любовь` is searched in KJV
- **THEN** «Нічого не знайдено» (Nothing found) is shown

### Requirement: Safe query
Special characters of the search syntax (`"`, `*`, `(`, `)`, `:`, `-` etc.) MUST be treated as plain text and MUST NOT cause an error.

#### Scenario: Special characters
- **WHEN** `"love*` or `(` is searched
- **THEN** search returns a result or an empty list without an error

#### Scenario: Empty query
- **WHEN** the query is empty or only spaces
- **THEN** there are no results and no error

### Requirement: Jump to a reference
If the query in the search field parses as a reference, the app SHALL open that passage instead of a text search and scroll to the verse if one is given.

#### Scenario: Jump to a verse
- **WHEN** `Ин 3:16` is typed in the search field
- **THEN** the chapter Иоанна 3 opens with verse 16 in focus

### Requirement: Opening a result
Clicking a search result SHALL open the chapter with that verse in focus.

#### Scenario: Clicking a result
- **WHEN** the user clicks the result 1 John 4:8
- **THEN** 1 John 4 opens with verse 8 in focus

### Requirement: Morphological search
Unquoted query words SHALL find other forms of the same word: in English (including KJV forms in -eth, -est), Russian, Ukrainian and Czech. All found forms are highlighted.

#### Scenario: Russian cases
- **WHEN** `любовь` is searched in the Synodal
- **THEN** the results include verses with the words «любви» and «любовью»

#### Scenario: KJV forms
- **WHEN** `love` is searched in KJV
- **THEN** the results include verses with "loved", "loveth", "loving", and in John 3:16 "loved" is highlighted

#### Scenario: Ukrainian and Czech
- **WHEN** `любов` is searched in Ohienko and `láska` in Kralická
- **THEN** verses with «любові» and with «lásky» are found

### Requirement: Search scope
Above the results there SHALL be a scope bar: the whole Bible, the Old Testament (books 1–39), the New Testament (40–66), the current book. Changing the scope SHALL rerun the search with the same query.

#### Scenario: Testaments
- **WHEN** `love` is searched in KJV in the OT and in the NT
- **THEN** OT results come only from books 1–39, NT from 40–66, and the sum of the counts equals the count over the whole Bible

#### Scenario: Current book
- **WHEN** John is open and «Іоан»/"John" is chosen in the bar
- **THEN** all results come from book 43

### Requirement: All results with a counter
Results SHALL show the label «Знайдено: N» (Found: N) with the full count in the scope and SHALL load more in pages of 100 when the list is scrolled to the end; there is no result limit.

#### Scenario: Loading more
- **WHEN** a query has 250 matches
- **THEN** first 100 and «Знайдено: 250» are shown, after scrolling 200, then all 250 without repeats

### Requirement: Quoted phrase search
Query text in quotes (`"…"`, `«…»`, `„…“`, `“…”`) SHALL be searched as an exact phrase: these words in a row and in exact forms. Words outside the quotes are searched as usual; an unpaired quote SHALL be treated as a plain character.

#### Scenario: Exact phrase
- **WHEN** `"only begotten Son"` is searched in KJV
- **THEN** every result contains "only begotten Son" in a row, John 3:16 among them

#### Scenario: Exact form
- **WHEN** `"loved"` is searched in KJV
- **THEN** every result contains exactly "loved"

### Requirement: Search speed
Search SHALL return the count and the first page of results in less than 200 ms over the whole Bible for the most frequent words of each translation.

#### Scenario: Worst case
- **WHEN** `the` is searched in KJV, `и` in the Synodal, `і` in Ohienko, `a` in Kralická
- **THEN** each search takes < 200 ms
