## Decisions

1. `Translation.coverage` (`bible`, `nt`) carries the book range; `bookName(_:)` indexes the module's own names by `number - range.lowerBound`, and falls back to the built-in language names for books outside the range (Compare titles).
2. Optional is a manifest flag, not a build flag: the importer skips the module when its file is missing, so `make db` and CI need no special case.
3. Availability is asked of the database (`BibleRepository.hasTranslation`, a primary-key lookup), not of the manifest, so a menu never offers a translation without text. A saved reading position in a missing translation is ignored.
4. Old Testament hiding needs no filter: `books(translation:)` already lists only books present in the database; the sidebar drops a testament section with no books.
5. `ReaderViewModel.open` ignores a book the translation lacks (bookmarks, draft links); a typed reference to such a book falls through to text search; switching translation from such a book opens the first covered book, chapter 1.
6. The converter applies fixes to the raw verse before cleaning (a `^` typo would otherwise stop the conversion) and, in `--nt` mode, refuses any leftover `^` or empty verse, so a text with a known defect is never imported silently.
