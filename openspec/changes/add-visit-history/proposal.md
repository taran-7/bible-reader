## Why

PRD 6.21 (v2.4, FR-42): while reading, jumping between passages (search, bookmarks, draft links, Compare) loses the way back. The free space right of the ~75-character reading column can hold a list of recently visited verses; a click returns to one, in the translation it was visited in.

## What Changes

- `VisitHistory` in `BibleCore`: records visits (translation + book + chapter + verse, or a chapter without a verse), newest first, deduplicated, at most 50, persisted in the user database (migration `v3`), "Clear history".
- `ReaderViewModel` records on `open(_:focus:)` and when a verse is selected; `openVisit(_:)` opens an entry in its translation and keeps Compare / the parallel view.
- A `HistoryPanel` column to the right of the reading area: a separate column, so the selection highlight and the selection buttons end at its left border; the selection buttons are compact icons to the left of the selected verse (later owner request) instead of wide buttons at the right window edge.
- With Drafts or Illustrations open the panel hides; a toolbar toggle shows it next to them and the text column narrows.

## Non-goals

- Grouping by day, search in history, time or text excerpts in a row (owner decisions 2026-10-17).
- Syncing history between machines or including it in the notes export.
