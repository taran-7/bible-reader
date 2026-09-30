# bible-reading Specification

## Purpose

Lets the user read the Bible text in one of the translations, moving between books and chapters.

Requirements in [docs/requirements.md](../../../docs/requirements.md): FR-4, FR-5, FR-6, FR-7, FR-15, FR-16, FR-31, FR-32, FR-28, FR-29, FR-37.

## Requirements

### Requirement: Choosing a translation
The app SHALL show one translation on screen and allow switching KJV ↔ Synodal; switching SHALL stay on the same book and chapter.

#### Scenario: Switching translation
- **WHEN** John 3 is open in KJV and the user chooses the Synodal
- **THEN** Synodal Иоанна 3 is shown

### Requirement: Book list
The app SHALL show 66 books grouped into the Old and New Testaments, with names in the active translation's language.

#### Scenario: Book names in the translation's language
- **WHEN** the Synodal translation is active
- **THEN** the first book is called «Бытие», the fortieth «От Матфея»

### Requirement: Chapter navigation
The app SHALL show all verses of the chosen chapter with numbers, allow choosing a chapter and paging to the previous/next chapter; at book boundaries paging SHALL move to the neighboring book, and at the ends of the Bible the button SHALL be disabled. A chapter SHALL be chosen in a window of chapter numbers that opens by clicking a book in the sidebar (beside it) or clicking the chapter title in the toolbar (below it), without hiding the current chapter's text; the toolbar SHALL NOT contain a separate chapter picker (FR-37).

#### Scenario: Next chapter at the end of a book
- **WHEN** Genesis 50 is open and the user presses ▶
- **THEN** Exodus 1 opens

#### Scenario: Start of the Bible
- **WHEN** Genesis 1 is open
- **THEN** the ◀ button is disabled

#### Scenario: Choosing a chapter from the sidebar
- **WHEN** Genesis 1 is open and the user clicks the book Ruth
- **THEN** a window with numbers 1–4 appears over the Genesis 1 text, and Genesis 1 stays open
- **WHEN** the user clicks the number 4
- **THEN** Ruth 4 opens, the window closes

#### Scenario: Closing without navigating
- **WHEN** a book's chapter window is open and the user presses Esc or clicks outside it
- **THEN** the window closes, the open chapter does not change

### Requirement: Database error
If the database cannot be opened, the app MUST show an error screen with an explanation instead of an empty reader.

#### Scenario: Database missing
- **WHEN** the database file is missing or corrupted
- **THEN** an error screen is shown, the app does not crash

### Requirement: Database path for tests
The app SHALL open the database at the path from the `BIBLE_READER_DB` environment variable if it is set and non-empty; otherwise it SHALL open `bible.sqlite` from the bundle.

#### Scenario: The variable points to a missing file
- **WHEN** the app is launched with `BIBLE_READER_DB=/nonexistent/bible.sqlite`
- **THEN** the database error screen is shown

#### Scenario: The variable is not set
- **WHEN** `BIBLE_READER_DB` is not set
- **THEN** the database from the bundle opens

### Requirement: Font scale
The app SHALL let ⌘+, ⌘− and ⌘0 change the font size of verse text and the book list together, and Settings SHALL set each of them separately. Sizes SHALL persist between launches (FR-15).

#### Scenario: Increasing the verse font
- **WHEN** the user presses ⌘+
- **THEN** verse text and book names become 1 pt larger, but not larger than 32 pt

#### Scenario: Default size
- **WHEN** the user presses ⌘0
- **THEN** verse text returns to 15 pt and the book list to 13 pt

#### Scenario: Persisting between launches
- **WHEN** the user changed the size and restarted the app
- **THEN** the size is the same as before the restart

#### Scenario: Corrupted settings
- **WHEN** the saved settings cannot be read
- **THEN** default sizes are used

### Requirement: Interface scale
The app SHALL offer in Settings an interface scale «Малий», «Стандарт», «Великий», «Дуже великий» (Small, Standard, Large, Extra large), which changes the text size of search results, message screens and controls relative to the macOS system font size, and SHALL persist the choice between launches (FR-16).

#### Scenario: Large scale
- **WHEN** the user chooses «Великий» (Large)
- **THEN** search result text is 1.2 times the system size

### Requirement: Themes
The app SHALL offer the themes «Як у системі», «Світла», «Темна», «Скло», «Пастельна», «Манускрипт» (System, Light, Dark, Glass, Pastel, Manuscript) in Settings and in the «Вигляд» (View) menu; the chosen theme SHALL change the background, text, panels, search highlight, selection and verse font without a restart and SHALL persist between launches (FR-31).

#### Scenario: Switching theme
- **WHEN** the user chooses «Манускрипт»
- **THEN** the background under verses becomes parchment `#EFE4CC` with a faint texture, verse text becomes EB Garamond in `#3B2A1A`, verse numbers `#8B2E1F`

#### Scenario: System
- **WHEN** «Як у системі» is chosen and macOS is in dark mode
- **THEN** the «Темна» theme is applied

#### Scenario: Persistence
- **WHEN** the user chose «Пастельна» and restarted the app
- **THEN** «Пастельна» is applied

#### Scenario: Reduce transparency
- **WHEN** "Reduce transparency" is on in macOS and «Скло» is chosen
- **THEN** panels and the backing under verses are opaque

### Requirement: Theme contrast
Each theme SHALL be a set of tokens in `BibleCore`, and for each theme with "Reduce transparency" and "Increase contrast" on and off, body text SHALL have a contrast against its background of at least 7:1, and secondary text, accent, search highlight and the copy button at least 4.5:1 (FR-32, NFR-4).

#### Scenario: Checking all pairs
- **WHEN** the contrast test runs
- **THEN** every text/background pair of every theme passes its threshold

#### Scenario: Glass over any wallpaper
- **WHEN** the Glass backing with 0.92 opacity lies on a black or white background
- **THEN** body text on it has a contrast of at least 7:1

### Requirement: Choosing among four translations
The app SHALL offer in the toolbar a translation menu in the order KJV, Kralická, Огієнко, Синодальний with each one's language, and the commands ⌘⌥1…4 in the same order; the book list and chapter title SHALL be shown in the chosen translation's language (FR-28, FR-29).

#### Scenario: Switching to Ohienko
- **WHEN** the user chooses «Огієнко» on Genesis 1
- **THEN** the title is «Буття 1», verse text is in Ukrainian

#### Scenario: Menu order
- **WHEN** the user opens the translation menu
- **THEN** the items are: KJV — English, Kralická — čeština, Огієнко — українська, Синодальний — русский

### Requirement: Paging from the keyboard
The commands ⌘[ and ⌘] SHALL open the previous and next chapter just like ◀ and ▶, and ◀ ▶ and ⌘[ ⌘] SHALL close open search results or a search error (FR-6).

#### Scenario: Paging closes results
- **WHEN** search results for `love` are on screen and the user presses ⌘]
- **THEN** the results close and the next chapter opens

#### Scenario: End of the Bible
- **WHEN** Revelation 22 is open
- **THEN** ⌘] and ▶ are disabled

### Requirement: A chapter outside the book
A reference or a saved position with a chapter number greater than the book's chapter count SHALL open the book's last chapter (FR-8).

#### Scenario: John 99
- **WHEN** the user searches `John 99`
- **THEN** John 21 opens

### Requirement: Retry after a read error
If the database opened but a chapter could not be read, the app SHALL show the screen «Не вдалося прочитати базу» (Could not read the database) with a «Спробувати ще раз» (Try again) button that repeats the read; after a successful read the error screen SHALL disappear. Navigation SHALL NOT open chapter 0 if a book has no chapters (FR-7).

#### Scenario: A one-off error
- **WHEN** reading a chapter failed once and the user presses «Спробувати ще раз»
- **THEN** the chapter is shown, there is no error screen

#### Scenario: A book without chapters in a corrupted database
- **WHEN** the previous book has 0 chapters and chapter 1 is open
- **THEN** ◀ is disabled

### Requirement: Search field in theme and scale
The toolbar search field SHALL have the interface scale's font size and the active theme's text color and background; the Settings form SHALL have the active theme's background (FR-16, FR-31).

#### Scenario: Dark theme and large scale
- **WHEN** the «Темна» theme and the «Великий» scale are chosen
- **THEN** the text in the search field is light on a dark background and 1.2 times the system size

### Requirement: Text column
Without a parallel translation the chapter text SHALL stand as a centered column ~75 characters wide (40 em of the verse font), so a line does not stretch across a wide window (FR-15).

#### Scenario: A wide window
- **WHEN** the window is wider than the column, verse font 15 pt
- **THEN** verse lines are no wider than 600 pt and centered
