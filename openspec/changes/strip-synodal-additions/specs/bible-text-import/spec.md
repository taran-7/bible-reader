## ADDED Requirements

### Requirement: Synodal text without Greek additions
The Synodal text in the database SHALL NOT contain the Greek (Septuagint) additions that the printed Synodal puts in square brackets and that KJV lacks: every bracket in Esther, and every other bracketed insertion of 100 or more characters in the Old Testament, except Hebrew text that the Synodal brackets only because the Septuagint lacks it (Deuteronomy 21:5, 2 Kings 7:13). Verses that were a whole bracketed block at the end of a chapter (Joshua 24:34–36, Proverbs 4:28–29) SHALL NOT exist, so these chapters have as many verses as in KJV (FR-1, FR-27). Short bracketed words SHALL stay.

#### Scenario: Esther
- **WHEN** Esther 1:1 is read in the Synodal
- **THEN** it begins «И было во дни Артаксеркса, — этот Артаксеркс царствовал» and no Esther verse contains a square bracket

#### Scenario: A chapter that ended in an addition
- **WHEN** Proverbs 4 and Joshua 24 are read in the Synodal
- **THEN** they have 27 and 33 verses, as in KJV, and no verse of the Synodal in them lacks a KJV counterpart

#### Scenario: Hebrew text in brackets stays
- **WHEN** Deuteronomy 21:5 is read in the Synodal
- **THEN** it still contains the bracketed clause «ибо их избрал Господь Бог твой»

#### Scenario: Short bracketed words stay
- **WHEN** Genesis 2:13 is read in the Synodal
- **THEN** it still contains «[Геон]»
