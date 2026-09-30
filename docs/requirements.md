# Requirements Document

**Bible Reader for macOS**

*Reconstructed from the code, tests and `openspec/specs/` during the Project Factory onboarding (2026-09-25).*

> **ASSUMPTION.** Each MVP row describes behavior the code **already has**
> (baseline, v1.0). This is a hypothesis the owner confirms or corrects at
> the baseline sign-off checkpoint. The product description and priorities stay in
> the [PRD](product-specs/prd.md); this file holds the canonical IDs for the FR → spec → plan → test chain.

> **Baseline sign-off (2026-09-27).** The owner confirmed FR-1…FR-14 as they are.
> Evidence gaps were closed on 2026-09-27 (see §4).

## 1 Product overview

A lightweight native Bible reader for macOS with no network and no accounts: find a passage in
seconds, read it in several translations and quote it with a correct
reference. MVP (v1.0): KJV and Synodal, navigation, search, quote copying.
The v1.1–v2.1 roadmap is in the `Future` rows below (PRD item numbers in parentheses).

## 2 Functional Requirements (FR)

Verification tags: `local-verifiable` means `swift test` (`Tests/BibleCoreTests`)
proves the behavior deterministically; the test is tagged `@trace FR-n`.

### 2.1 Text import (`bible-text-import`)

| ID | Phase | Area | Description | Verification |
|---|---|---|---|---|
| FR-1 | MVP | Import | `bible-import` reads the KJV and Synodal JSON from `data/raw` and writes all verses into one database with translation, book (1–66), chapter and verse; control verses (Gen 1:1, John 3:16) are present. | local-verifiable |
| FR-2 | MVP | Import | The import builds an FTS index that is case- and diacritic-insensitive (Latin and Cyrillic); the index has as many entries as there are verses. | local-verifiable |
| FR-3 | MVP | Import | A missing or corrupted input file yields a non-zero exit code and a message naming the file; no partially written database is left behind. | local-verifiable |

### 2.2 Reading (`bible-reading`)

| ID | Phase | Area | Description | Verification |
|---|---|---|---|---|
| FR-4 | MVP | Reading | One translation on screen; switching KJV ↔ Synodal keeps the same book and chapter. | local-verifiable |
| FR-5 | MVP | Reading | A list of 66 books grouped into OT and NT, with names in the active translation's language. | local-verifiable |
| FR-6 | MVP | Reading | A chapter is shown with verse numbers; ◀ ▶ move between chapters and across book boundaries; at the ends of the Bible the button is disabled. | local-verifiable |
| FR-7 | MVP | Reading | If the database cannot be opened, an error screen is shown instead of an empty reader; the app does not crash. | local-verifiable |

### 2.3 References and quotes (`scripture-reference`)

| ID | Phase | Area | Description | Verification |
|---|---|---|---|---|
| FR-8 | MVP | Reference | Parsing `<book> <chapter>[:<verse>[-<verse>]]` by full name or abbreviation (en/ru), case-insensitive, with or without a period; anything else means "not a reference". | local-verifiable |
| FR-9 | MVP | Reference | A quote looks like `«text» (<full book name> <chapter>:<verse>)` in the translation's language; several verses give a range, texts joined with a space. | local-verifiable |
| FR-10 | MVP | Reference | Selected verses are copied in quote format via ⌘C and the context menu. | local-verifiable |

### 2.4 Search (`bible-search`)

| ID | Phase | Area | Description | Verification |
|---|---|---|---|---|
| FR-11 | MVP | Search | Search for verses containing all query words, only in the active translation, case-insensitive; results with a reference and a highlighted snippet, in book order (up to 200). | local-verifiable |
| FR-12 | MVP | Search | FTS special characters (`"`, `*`, `(`, `)`, `:`, `-`, `AND`…) are treated as text and cause no error; an empty query gives an empty result. | local-verifiable |
| FR-13 | MVP | Search | If the query parses as a reference, that passage opens with the verse in focus instead of a text search. | local-verifiable |
| FR-14 | MVP | Search | Clicking a result opens the chapter with that verse in focus. | local-verifiable |

### 2.5 Roadmap (Future)

| ID | Phase | Area | Description | Verification |
|---|---|---|---|---|
| FR-15 | MVP | Reading | Font scale for verses and the book list, ⌘+ / ⌘− / ⌘0, persisted between launches; without a parallel translation the text is a centered ~75-character column (PRD 6.1). | local-verifiable |
| FR-16 | MVP | Reading | Overall interface scale in Settings, respecting the system text size (PRD 6.2). | local-verifiable |
| FR-17 | MVP | Reference | A semi-transparent copy button above the selection, a "Copied" label for ~1.5 s (PRD 6.3). | local-verifiable |
| FR-18 | MVP | Search | Morphological search: en/ru via Snowball, uk/cs via light stemmers (PRD 6.4). | local-verifiable |
| FR-19 | MVP | Search | Search scope filter: Bible / OT / NT / current book (PRD 6.5). | local-verifiable |
| FR-20 | MVP | Search | All results with a "Found: N" counter and incremental loading (PRD 6.6). | local-verifiable |
| FR-21 | MVP | Search | Exact phrase search in quotes (PRD 6.7). | local-verifiable |
| FR-22 | MVP | Notes | Bookmarks on a verse or chapter (PRD 6.8). | local-verifiable |
| FR-23 | MVP | Notes | Colored verse highlights (PRD 6.9). | local-verifiable |
| FR-24 | MVP | Notes | Verse notes with search (PRD 6.10). | local-verifiable |
| FR-25 | MVP | Reading | Opening at the last reading position (PRD 6.11). | local-verifiable |
| FR-26 | MVP | Parallel | Two translations side by side with synchronized scrolling (PRD 6.12). | local-verifiable |
| FR-27 | MVP | Parallel | KJV ↔ Synodal numbering mapping table (PRD 6.13). | local-verifiable |
| FR-28 | MVP | Import | The Ohienko translation (PRD 6.14). | local-verifiable |
| FR-29 | MVP | Import | Bible kralická 1613 (PRD 6.15). | local-verifiable |
| FR-30 | MVP | Import | Translation modules: a new translation without code changes (PRD 6.16). | local-verifiable |
| FR-31 | MVP | Themes | Five themes (Light, Dark, Glass, Pastel, Manuscript) and "System"; a theme changes the whole interface without a restart and persists between launches (PRD 6.18). | local-verifiable |
| FR-32 | MVP | Themes | A theme is a set of tokens in `BibleCore`; every text/background pair of every theme passes contrast: body text ≥ 7:1, secondary and accent ≥ 4.5:1 (PRD 6.18). | local-verifiable |
| FR-33 | MVP | Illustrations | A "Find illustrations" button on the selection opens a panel to the right of the text (35/65, draggable divider) with ≤ 7 stories (title, text, source); "Get more" loads the next ≤ 7 while any are found; the card has "Translate" into the on-screen Bible's language via Apple's system translator (on-device, macOS 15+; "Original" restores the English text) and "Copy" (what is currently on the card, with the source); stories are not stored; offline shows "No network connection", an error shows a message; both with "Retry" (PRD 6.17, owner decision 2026-09-28). | local-verifiable |
| FR-34 | MVP | Illustrations | Stories only from allowlisted domains (Protestant sites, Wikipedia); Catholic and Orthodox domains are in the blocklist; on Wikipedia only biographies without Catholic or Orthodox categories; a story with an address outside the allowlist is dropped (PRD 6.17). | local-verifiable |
| FR-35 | MVP | Illustrations | Live search on click, no local index: no network requests before the click; sources are WordPress REST (Christianity Today, IMB), Wikipedia and, with the user's key, Brave Search over the allowlist; copyrighted articles show the first ≤ 1500 characters and "Read on site" (PRD 6.17). | local-verifiable |
| FR-36 | MVP | Compare | A "Compare" button on the selected verse: a window with translation checkboxes (the choice persists), then a mode in the main window: the whole chapter in columns by translation, rows aligned by verse (FR-26 mapping table), selected verses highlighted, column headers are the book name in the translation's language; ✕ / Esc go back to reading (PRD 6.19). | local-verifiable |
| FR-37 | MVP | Reading | Clicking a book in the sidebar shows a popover next to the book with its chapter numbers (all of them, without scrolling, if the screen allows); the chapter title in the toolbar opens the same popover downward (current one marked); clicking a number opens the chapter, Esc or a click outside closes it without navigating; there is no chapter picker in the toolbar (owner request 2026-09-28). | local-verifiable |
| FR-38 | MVP | Drafts | "Drafts": a panel on the right with a list (search) and a Markdown editor, autosaved in the user database; "To draft" on selected verses appends a quote with a reference; references in the text are recognized and open the passage (PRD 6.20). | local-verifiable |
| FR-39 | MVP | Drafts | "New sermon" with a structure; "To draft" on an illustration card; a marker next to verses mentioned in drafts, linking to them (PRD 6.20). | local-verifiable |
| FR-40 | MVP | Drafts | "Sermon" mode (text only in a large font, ⌘+ / ⌘−, Esc); export: copy, Markdown, print / PDF (PRD 6.20). | local-verifiable |
| FR-41 | MVP | Illustrations | Model curation of illustrations: a model (Claude with the user's key; without a key, Apple on-device) writes search queries from the verse's theme, scores candidates (threshold 6, best first) and writes "Why this story" in the translation's language; without a model or on its error, behavior is as before (PRD 6.17). | local-verifiable |

## 3 Non-Functional Requirements (NFR)

NFRs from PRD §3 and §7 do not yet have an automatic verification mechanism, so they stand
as `Future`: they become MVP rows together with the slice that adds the check
(see `check-acceptance-methods`).

| ID | Phase | Area | Description | Verification |
|---|---|---|---|---|
| NFR-1 | MVP | Platform | macOS 14+, Apple Silicon only (`arm64`); Intel is out of scope (owner decision 2026-09-27, open source: whoever needs it can build it). | local-verifiable |
| NFR-2 | MVP | Privacy | Offline, no telemetry; the only network exception is illustrations (FR-33…FR-35) after a click: the allowlist, the Wikipedia and Brave APIs, and for model curation (FR-41) the Claude API with the user's key; network code only in `IllustrationNetwork.swift` (test `NetworkIsolationTests`). | local-verifiable |
| NFR-3 | MVP | Performance | Launch < 1 s; search < 200 ms over the whole Bible (search: the `improve-search` test; launch: `launch-time` in a UI test, Debug build, warm launch; limit 1 s on a Mac, 2 s on the CI VM, PD-14). | local-verifiable |
| NFR-4 | MVP | A11y | VoiceOver reads verse numbers and texts; full keyboard operation; WCAG AA contrast. | local-verifiable |
| NFR-5 | MVP | Size | Release `.app` size < 100 MB (warning from 80 MB); the limit was raised from 60 MB by owner decision on 2026-09-27. | local-verifiable |

## 4 Baseline gaps

- ~~**FR-7, FR-10, FR-13, FR-14 (UI)**~~ closed on 2026-09-27 by the `add-ui-tests` slice:
  XCUITest in `Tests/BibleReaderUITests/` (`make ui-test`). The ⌘C test found a bug:
  after a search the focus stayed in the field, and ⌘C copied the query text instead of the quote.
- ~~**FR-2 (diacritics)**~~ closed on 2026-09-27: the `testFtsIgnoresDiacritics` test
  found that `unicode61` does not fold the Cyrillic "ё"; `ё → е` folding was added
  (`SearchText.fold`, `search_text` column), test `testYoFoldsToYe`.
