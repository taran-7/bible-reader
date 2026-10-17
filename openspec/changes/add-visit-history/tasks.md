## 1. Core

- [x] 1.1 Red tests: `VisitHistoryTests` (title, order, dedupe, limit 50, persistence, clear, unknown translation) and reader tests (recording, `openVisit`, Compare and parallel kept)
- [x] 1.2 `VisitEntry`, `VisitHistory`, migration `v3`, `ReaderViewModel` wiring

## 2. App

- [x] 2.1 `HistoryPanel` column, toolbar toggle, hide next to Drafts / Illustrations
- [x] 2.2 Selection buttons next to the text (first at the column's right edge, later moved left of the verse, `ChapterView`)

## 3. Verification

- [x] 3.1 `make test` (301 tests), app build, `HistoryUITests` compiled (they run in CI, not locally by day)
- [ ] 3.2 A look in the running app: selection buttons left of the verse, row click, Compare and parallel keep their mode (manual, owner)
