## Why

Owner report 2026-10-17: a Synodal search for «желаю» returns Esther 1:1 and 3:13 as walls of text. These are Greek (Septuagint) additions that the Synodal prints in square brackets and that KJV, based on the Hebrew text, does not have. The owner decided they are not part of the text the app follows and asked to remove them.

## What Changes

- `scripts/convert_synodal.py` drops the long Greek insertions (bracket of 100+ characters) in the Old Testament, all brackets in Esther and the two chapter-final bracketed blocks (Joshua 24:34–36, Proverbs 4:28–29); `--strip-converted` applies it to an already converted file.
- `data/raw/ru_synodal.json` is converted accordingly (23,288 characters, 5 verses).
- Kept: short brackets, the two long brackets that are Hebrew text (Deuteronomy 21:5, 2 Kings 7:13), the multi-verse Hebrew brackets (Judges 20:27–28, Psalm 67:23–24), and Daniel 3:24–90, Daniel 13–14, Psalm 151.

## Non-goals

- Removing Daniel 3:24–90 (67 mid-chapter verses): needs the KJV numbering mapping to follow; a separate change if wanted.
- Removing short bracketed words or any bracket in the New Testament.
