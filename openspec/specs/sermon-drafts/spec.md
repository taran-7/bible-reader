# sermon-drafts Specification

## Purpose
Drafts of sermons and thoughts next to the Bible text: a Markdown editor, verses and illustrations in one click, live references, markers next to verses, a "Sermon" mode and export.

Requirements in [docs/requirements.md](../../../docs/requirements.md): FR-38, FR-39, FR-40.

## Requirements

### Requirement: Drafts
The app SHALL have «Чорнетки» (Drafts): a panel to the right of the chapter text (opening it closes the illustrations panel) with a list of drafts (title, modification date, start of the text; search by title and text; newest first) and a Markdown editor with formatting buttons. Changes SHALL be saved automatically in the user database and survive a restart. An empty title SHALL show as «Без назви» (Untitled). Deleting SHALL ask for confirmation (FR-38).

#### Scenario: A new draft survives a restart
- **WHEN** the user created a draft, wrote «Про любов» and restarted the app
- **THEN** the draft with this text is first in the list

#### Scenario: Search
- **WHEN** «любов» is typed into the draft search
- **THEN** the list shows only drafts with this word in the title or text

### Requirement: A verse into a draft
On a verse selection there SHALL be «В чорнетку» (To draft): a button on the selection when the drafts panel is open, and a context menu item always. It SHALL append to the end of the active draft the same quote with a reference as copying does; if there is no active draft, it creates a new one (FR-38).

#### Scenario: Insert a verse
- **WHEN** John 3:16 is selected in KJV and «В чорнетку» is pressed
- **THEN** "For God so loved…" (John 3:16) appears at the end of the active draft

### Requirement: Live references
References to passages in the draft text (a book name or abbreviation in any app language, chapter:verse, an optional range) SHALL be recognized. In the draft preview they SHALL be links that open the passage in the text on the left; in the editor they SHALL be a list under the text with the verse text in a tooltip. Numbers are interpreted in KJV numbering (FR-38).

#### Scenario: Recognition
- **WHEN** the text says «див. Ин 3:16 і 1 Кор 13:4-7, а також John 3:16–18»
- **THEN** three references are recognized: Ин 3:16, 1 Кор 13:4–7, John 3:16–18

#### Scenario: No false matches
- **WHEN** the text says «о 10:30 зустріч, 3:1 — рахунок матчу»
- **THEN** no references are recognized

### Requirement: Sermon template and illustrations
«Нова проповідь» (New sermon) SHALL create a draft with a structure: theme, main text, introduction, points 1–3, illustration, application, call. An illustration card SHALL have «В чорнетку», which appends the title, text (as shown on the card) and source (FR-39).

#### Scenario: Template
- **WHEN** «Нова проповідь» is pressed
- **THEN** the draft contains the sections «Тема», «Основний текст», «Вступ», «1.», «2.», «3.», «Ілюстрація», «Застосування», «Заклик»

### Requirement: Marking verses used in drafts
A verse referenced in at least one draft SHALL have a marker next to its number; a click on it SHALL open the drafts panel with a list of those drafts. A range marks all verses of the range (FR-39).

#### Scenario: Range
- **WHEN** a draft has «1 Кор 13:4-7»
- **THEN** verses 1 Cor 13:4, 5, 6, 7 have a marker, and 13:8 does not

### Requirement: "Sermon" mode and export
«Проповідь» (Sermon) mode SHALL show only the active draft's text (formatted) in a large font across the whole window; ⌘+ / ⌘− change the size, Esc goes back. A draft SHALL be copyable in full, savable as a Markdown file (`# title` + text) and printable (PDF from the print dialog) (FR-40).

#### Scenario: Sermon
- **WHEN** «Проповідь» is pressed in a draft, and then Esc
- **THEN** first only the draft text in a large font is visible, after Esc the chapter and panel again

#### Scenario: Markdown
- **WHEN** the draft «Про любов» with the text «Бог є любов» is saved as Markdown
- **THEN** the file contains `# Про любов`, an empty line and `Бог є любов`
