## Why

PRD 6.22 (v2.5, FR-43): the owner reads Yuriy Popchenko's Ukrainian New Testament (bolls.life `PPCH`). The text is under copyright and the repository is public, so it must stay on the owner's Mac: fetched by a local script, never committed, and optional in the build.

## What Changes

- Manifest fields `coverage` (`bible` | `nt`) and `optional`; a `coverage: nt` module has 27 books (40…66) and its own book names.
- The import skips an `optional` module whose file is absent (CI and a fresh clone stay green) and places a 27-book file on books 40…66.
- The app lists only translations whose text is in the database; Old Testament books are hidden for an NT module; switching to it from the Old Testament opens Matthew 1; Compare and the parallel view show a "not in this translation" cell for Old Testament verses.
- `scripts/fetch_ppch.sh` + `convert_getbible.py --nt --fixes`: downloads, converts to the git-ignored `data/raw/uk_popchenko.json`, applies the print fixes (`scripts/ppch_print_fixes.json`).
- Manifest entry «Попченко Ю.» with book names and abbreviations from the owner's printed table of contents.

## Non-goals

- Popchenko Psalms (FR-44, a later slice, waits for the owner's photos).
- Committing any Popchenko text beyond the print-fix verses listed in `ppch_print_fixes.json`.
