# Translation modules (FR-30)

A new translation is added as data, with no code changes:

1. A `data/raw/<code>.json` file in the `thiagobodruk` format: an array of 66 books `{"chapters": [["verse 1", "verse 2", …], …]}`.
   An empty string is a verse missing in the source (following verse numbers are kept). A converter for getBible and bolls.life:
   `scripts/convert_getbible.py`.
2. A line in the manifest `Sources/BibleCore/Resources/translations.json`:

   ```json
   {"code": "web", "title": "WEB", "language": "en", "languageTitle": "English", "numbering": "kjv", "file": "en_web.json"}
   ```

   - `code`: the key in the database and settings (unique);
   - `language`: `en`, `ru`, `uk`, `cs` (built-in book names and stemmer) or another code; then `books` is required:
     66 objects `{"name": …, "abbreviation": …}` in canonical order, and search matches exact word forms;
   - `numbering`: `kjv` (like KJV, Kralická, Ohienko), `synodal` (like the Synodal; built-in mapping table) or a new system, e.g. `vulgate`;
   - `versification`: for a new system, `{"segments": [{"book": 19, "chapter": 10, "from": 1, "to": 18, "localChapter": 9, "localVerse": 22}]}`, only the differences from KJV (`merge: true` means several KJV verses in one). One module of that system is enough; between two non-KJV systems a verse is mapped through KJV;
   - line order is menu order; the first nine get ⌘⌥1…9;
   - the codes `kjv`, `bkr`, `ohienko`, `synodal` are required (the code relies on them).
3. `make db` rebuilds the database; the app shows the translation in the menu, search, "Compare" and the parallel view.

The manifest is validated on load: a duplicate code, a new numbering without a `versification` table, or a language without book names is an error.
