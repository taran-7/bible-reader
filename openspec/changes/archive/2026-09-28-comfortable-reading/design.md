# Design: comfortable-reading

> Written retroactively on 2026-09-30: the slice was archived without `design.md`, and
> `check-trajectory --release` has failed on every push to `master` since PR #19. PR checks do not run
> `--release`, so the gap was noticed only when reviewing CI history.

## Text column
- `ReadingPreferences.textColumnWidth`: 40 em of the verse font (~75 characters plus the verse number), centered.
- Only without a parallel translation; the parallel view keeps the full width for two columns.

## "Compare" in the main window
- `ComparisonMode` in `BibleCore` builds rows from the on-screen chapter and reuses the parallel view's
  `Versification` mapping, so compare and parallel view cannot disagree on verse alignment.
- The translation picker stores the chosen codes in `ReadingPreferences.compareTranslations`; the
  on-screen translation is always the first column and is not offered in the picker.
- Changing chapter or translation clears `comparison` in `ReaderViewModel`; ✕ / Esc do the same.
- The separate window, panel reordering and dragging were removed instead of being adapted.
