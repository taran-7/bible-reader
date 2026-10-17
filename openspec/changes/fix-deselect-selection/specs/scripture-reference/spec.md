## ADDED Requirements

### Requirement: Deselecting verses
Esc SHALL deselect the selected verses whatever has the focus, except while a text field is being edited, a sheet, popover or the chapter picker is open, search results replace the chapter, or the Drafts panel is open; Illustrations and Compare close on Esc first. A click on the window header (title bar or empty toolbar space, not a toolbar control) SHALL deselect too. Deselecting SHALL also remove the semibold emphasis of the verse reached by a jump, so nothing stays marked (FR-17).

#### Scenario: Esc after a jump
- **WHEN** the user jumps to John 3:16 by reference and presses Esc
- **THEN** no verse is highlighted, there are no selection buttons, and John 3:16 is no longer semibold

#### Scenario: A click on the empty header
- **WHEN** a verse is selected and the user clicks an empty part of the toolbar
- **THEN** the selection and the emphasis are gone

#### Scenario: A toolbar control keeps the selection
- **WHEN** a verse is selected and the user opens the translation menu in the toolbar
- **THEN** the selection stays, and choosing another translation opens the same verse in it (FR-27)

#### Scenario: Esc in a text field
- **WHEN** the cursor is in the search field and the user presses Esc
- **THEN** the field handles the key and the selection stays
