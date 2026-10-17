## Why

Owner request 2026-10-17: the three selection buttons (Ілюстрації, Порівняти, Копіювати) stand to the right of the verse and are wide; they should stand to the left of the verse and be more compact.

## What Changes

- In the reading list the selection buttons are compact (icons only, tooltip and accessibility label stay) and stand in a margin to the left of the verse number, above the first selected verse's first line. The margin is the same in every row, so the selected verse does not shift.
- The "narrow column → icons only" switch (`SelectionButton.isCompact`, the list width tracking) goes away: the buttons are always compact there. In the cards of the Illustrations and Drafts panels nothing changes.

## Non-goals

- Changing what the buttons do, their order or the copy feedback.
