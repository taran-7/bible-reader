## 1. Core

- [x] 1.1 Red tests: manifest `coverage`/`optional`, own book names and reference parsing, import skip and 27-book offset, repository availability, reader switching to Matthew 1, Compare skipping unavailable translations (`PopchenkoTests`)
- [x] 1.2 `Translation.Coverage`, optional import, `hasTranslation`, `ReaderViewModel` rules, manifest entry
- [x] 1.3 Converter `--nt`, `--fixes`, `check_complete` (Python tests)

## 2. App

- [x] 2.1 Translation lists from `availableTranslations`; no empty Old Testament section; "not in this translation" cell in Compare and the parallel view

## 3. Local text

- [ ] 3.1 Rev 22:21 from the owner's printed edition added to `scripts/ppch_print_fixes.json` (text not in the repository yet)
- [ ] 3.2 `scripts/fetch_ppch.sh` run on the owner's Mac, `make db`, the text checked in the app (Ів. 3:16, switch from Genesis 1 opens Matthew 1)
