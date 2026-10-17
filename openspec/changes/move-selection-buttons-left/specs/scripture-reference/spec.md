## MODIFIED Requirements

### Requirement: Copy button on the selection
When one or more verses are selected, the app SHALL show, to the left of the first selected verse (in the margin before the verse number, level with its first line), compact semi-transparent icon-only buttons for illustrations, compare and copy; each has a tooltip and an accessibility label («Копіювати цитату» for copy) and none covers verse text. The margin SHALL be the same in every row, so the selected verse does not move. A click on copy SHALL put the same quote on the clipboard as ⌘C and for ~1.5 s show a check mark and «Скопійовано» in place of its icon (FR-17).

#### Scenario: No selection
- **WHEN** no verse is selected
- **THEN** there is no copy button

#### Scenario: Copying with the button
- **WHEN** John 3:16 is selected and the user clicks the copy button
- **THEN** the clipboard contains `«…» (John 3:16)`, as after ⌘C
- **AND** «Скопійовано» is the button's label in place of «Копіювати цитату», and after ~1.5 s the copy label is back

#### Scenario: Several verses
- **WHEN** verses 3–5 of Genesis 1 are selected and the user clicks the copy button
- **THEN** the buttons are to the left of verse 3, and the clipboard contains the quote `(Genesis 1:3-5)`

#### Scenario: Left of the verse
- **WHEN** John 3:16 is selected
- **THEN** the buttons are in the left half of the verse row, in the order illustrations, compare, copy, and left of the history panel
