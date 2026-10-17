## 1. Core

- [x] 1.1 Red tests in `ReaderViewModelTests`: emphasis cleared with the selection, `updateSelection(first:)`, `escapeClearsSelection`, `headerClickClearsSelection`
- [x] 1.2 `ReaderViewModel` implementation

## 2. App

- [x] 2.1 `SelectionDismissal` monitor for Esc and the header click; wired in `ContentView`
- [x] 2.2 `ChapterView`: `updateSelection(first:)` also right after a jump

## 3. Verification

- [x] 3.1 `make test` (309 tests), app build
- [ ] 3.2 A look in the running app: Esc, a click on the empty header and a click in the history panel / book list deselect; Esc in full screen does not leave it; the translation menu in the toolbar keeps the selection (manual, owner)
