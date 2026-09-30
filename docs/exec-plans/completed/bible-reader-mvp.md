# Plan: Bible Reader for macOS (capstone)

## Context
The course capstone requires an own small project with proven agentic engineering practices. The user chose a desktop Bible reading app in the spirit of biblequote.org. MVP: one translation on screen with a KJV ↔ Synodal switcher, navigation book → chapter → verse, copying a quote with a reference, full-text search. Stack: SwiftUI + Swift Package `BibleCore` + GRDB (SQLite FTS5) + a Swift CLI converter. The parallel view and the numbering mapping table are outside the MVP.

Repository: `bible-reader` (separate from the course fork; the fork only has a README with a link). Structure: `Package.swift`, `BibleReaderApp/`, `data/`, `docs/`, `openspec/`, `.claude/`.

## Steps
1. **Spec**: OpenSpec change `bible-reader-mvp` (`/opsx:propose`) + `docs/product-specs/bible-reader-mvp.md` with the agreed design; a commit on the `feature/01-bible-reader-mvp` branch (branch numbering: `feature/NN-<change>` per OpenSpec change).
2. **Implementation plan** via the writing-plans skill (TDD tasks: red test → green).
3. **Data**: `data/raw/en_kjv.json`, `data/raw/ru_synodal.json` from `thiagobodruk/bible` (same format for both, public domain), `data/raw/SOURCE.md` with a link and license.
4. **Package.swift**: targets `BibleCore` (lib, depends on GRDB), `bible-import` (executable), `BibleCoreTests`. macOS 14+.
5. **BibleCore**: `Translation`, `Book` (1–66, names/abbreviations en/ru), `Verse`, `BibleRepository` (books, chapterCount, verses, search with FTS query escaping), `Reference` (format/parse, ranges).
6. **bible-import**: JSON → `bible.sqlite` (table `verses` + `verses_fts` FTS5 `unicode61 remove_diacritics 2`).
7. **BibleReaderApp** (Xcode project): `NavigationSplitView`, a toolbar with the translation switcher, `.searchable` (reference → jump, otherwise FTS), copying via ⌘C/context menu, a DB error screen. `ReaderViewModel` `@Observable`.
8. **Harness for practice evidence**: the submission's `CLAUDE.md` (rules: TDD, `swift test` before committing), a reviewer subagent `.claude/agents/reviewer.md`, a `make check` loop (swift test until green).
9. **Submission README** and a filled PR template; the user records the video.

## Verification
- `make test` (`swift test`) at the project root: import (66 books, KJV verse count per source ≈31,102, control verses Быт 1:1 / Ин 3:16), Reference (parse/format in both languages, ranges), search (case, Cyrillic, special characters `"*` do not crash).
- `swift run bible-import data/raw BibleReaderApp/Resources/bible.sqlite` generates the database.
- `xcodebuild -scheme BibleReader build`, then a manual check: navigation, switcher, search "love"/"любовь", jumping to "Ин 3:16", copying 3:16-18.
- A reviewer subagent pass over the diff before the PR.

## Agreed design (short)
- **UI:** `NavigationSplitView`; a sidebar with 66 books (OT/NT) in the translation's language; a main area with the chapter text, ◀ ▶ and a chapter picker; a KJV / Synodal switcher in the toolbar.
- **Search:** `.searchable`; if the query parses as a reference (`Ин 3:16`, `John 3`), it jumps there, otherwise FTS with highlighted snippets; a click opens the verse.
- **Copying:** `«текст» (От Иоанна 3:16)`, ranges `От Иоанна 3:16-18` (full book name).
- **Data:** `ReaderViewModel` (`@Observable`) → `BibleRepository`; the DB is read-only from the bundle, one `DatabaseQueue`.
- **Errors:** an error screen if the DB did not open; "Nothing found"; the FTS query is escaped.
- **Known limitation:** Synodal numbering differs from KJV in places (Psalms etc.); the UI is checked manually.
