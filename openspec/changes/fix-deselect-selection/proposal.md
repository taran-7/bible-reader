## Why

Owner report 2026-10-17: with a verse selected, Esc and a click on the window header do not deselect it. Esc relied only on a menu key equivalent (Edit → Deselect), which depends on the focus and on SwiftUI refreshing the menu in time; there was no header click at all. Also, after a jump the verse stayed semibold when the selection was gone, so it still looked selected.

## What Changes

- `SelectionDismissal` (app layer): a local event monitor for the reader window catches Esc, a click on the empty window header (title bar, toolbar space without controls) and a click anywhere else outside the verse list (book list, history panel, not on a control, not while Drafts are open) whatever has the focus. An Esc nobody uses is swallowed in full screen, where AppKit would leave the mode on it (owner report, same day).
- `ReaderViewModel` decides: `escapeClearsSelection(otherOwnsEscape:)`, `escapeIsFree(otherOwnsEscape:)`, `headerClickClearsSelection()`, `outsideClickClearsSelection(draftsOpen:)`, `updateSelection(first:)`; deselecting also clears the jump emphasis (`focusedVerse`).
- `ChapterView` syncs the anchor verse explicitly after a jump, so a re-selected identical verse does not leave `canClearSelection` false.

## Non-goals

- A click on blank space inside the text: rows span the whole width, so there is none; ⌘-click on the selected verse already deselects.
