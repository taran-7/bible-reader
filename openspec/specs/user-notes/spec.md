# user-notes Specification

## Purpose
User bookmarks, highlights and notes in a separate local database, note search and export, opening at the last reading position.

Requirements in [docs/requirements.md](../../../docs/requirements.md): FR-22, FR-23, FR-24, FR-25.

## Requirements

### Requirement: Bookmarks
The user SHALL be able to add and remove a bookmark on a verse (context menu) and on a chapter (toolbar button, ⌘D). Bookmarks SHALL show as a «Закладки» (Bookmarks) section in the sidebar in book order, and a click SHALL open the bookmarked place.

#### Scenario: A verse bookmark
- **WHEN** «Додати закладку» (Add bookmark) is chosen on Ин 3:16
- **THEN** a bookmark icon appears next to the verse, and the sidebar gets a "John 3:16" row whose click opens John 3 with verse 16 in focus

#### Scenario: A chapter bookmark
- **WHEN** ⌘D is pressed in John 3
- **THEN** "John 3" appears in the sidebar; pressing ⌘D again removes it

### Requirement: Verse highlights
Selected verses SHALL be highlighted in one of the colors (yellow, green, blue, pink) or cleared; the highlight SHALL be visible as the row background, and VoiceOver SHALL read its color.

#### Scenario: Color
- **WHEN** Ин 3:16–17 are highlighted yellow, and then 16 green
- **THEN** 16 is green, 17 is yellow; «Прибрати підсвітку» (Remove highlight) clears the color

### Requirement: Notes
The user SHALL be able to write, edit and delete a text note on a verse; a verse with a note SHALL have an icon whose click opens the note. Search SHALL find notes by text (case-insensitive) and show them above verses.

#### Scenario: A note and search
- **WHEN** the note «Центральний вірш» is added to Ин 3:16 and `центральний` is searched
- **THEN** the results include the note on John 3:16, a click opens the verse

#### Scenario: An empty note
- **WHEN** the note text is erased and saved
- **THEN** the note is deleted, the icon is gone

### Requirement: Separate storage and export
Bookmarks, highlights and notes SHALL be stored in a separate local user database, tied to book, chapter and verse, and SHALL survive an app restart and a rebuild of `bible.sqlite`. They SHALL be exportable to JSON and Markdown.

#### Scenario: Restart
- **WHEN** the app is restarted after adding a bookmark, a highlight and a note
- **THEN** all of them are in place

#### Scenario: Export
- **WHEN** «Експортувати нотатки в Markdown…» (Export notes to Markdown…) is chosen
- **THEN** the file contains the sections «Закладки», «Підсвітки», «Нотатки» with references in the on-screen translation's language

### Requirement: Last reading position
The app SHALL open at the translation, book and chapter where the user stopped; a corrupted or invalid record SHALL give Genesis 1 in KJV, and a chapter outside the book gives the book's last chapter.

#### Scenario: Continue reading
- **WHEN** the user opened the Synodal, Ин 3 and restarted the app
- **THEN** the Synodal, Ин 3 is open
