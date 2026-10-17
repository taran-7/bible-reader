## 1. App

- [x] 1.1 `ChapterView`: left margin and `topLeading` overlay, always compact buttons; `SelectionButton`: compact width 28, `isCompact` and the list width tracking removed
- [x] 1.2 `ReaderUITests.testSelectionButtonsAreLeftOfTheVerse`; the history test (buttons left of the panel) stays valid

## 2. Docs

- [x] 2.1 PRD 6.3 and 6.21, the `add-visit-history` texts about the buttons

## 3. Verification

- [x] 3.1 `make test`, app build, UI tests compiled (they run in CI, not locally by day)
- [ ] 3.2 A look in the running app: the buttons left of the verse, compact, at several window widths, also with Drafts open (4 buttons) and in the parallel view (manual, owner)
