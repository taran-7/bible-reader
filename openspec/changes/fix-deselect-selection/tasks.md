## 1. Core

- [x] 1.1 Red tests in `ReaderViewModelTests`: emphasis cleared with the selection, `updateSelection(first:)`, `escapeClearsSelection`, `headerClickClearsSelection`
- [x] 1.2 `ReaderViewModel` implementation

## 2. App

- [x] 2.1 `SelectionDismissal` monitor for Esc and the header click; wired in `ContentView`
- [x] 2.2 `ChapterView`: `updateSelection(first:)` also right after a jump

## 3. Verification

- [x] 3.1 `make test` (307 tests), app build
- [ ] 3.2 A look in the running app: Esc and a click on the empty header deselect; the translation menu in the toolbar keeps the selection (manual, owner)
