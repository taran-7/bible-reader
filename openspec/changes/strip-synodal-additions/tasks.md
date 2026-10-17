## 1. Converter

- [x] 1.1 Red tests `scripts/test_convert_synodal.py` (long insertion, short kept, Esther all, Hebrew kept, trailing blocks, punctuation, in-place and idempotent); hooked into `make test`
- [x] 1.2 `strip_additions`, `drop_trailing_additions`, `--strip-converted` in `scripts/convert_synodal.py`

## 2. Data

- [x] 2.1 `data/raw/ru_synodal.json` converted; `data/raw/SOURCE.md` documents the rule and what stays
- [x] 2.2 `SynodalTextTests`; the mapping test no longer lists 6:24 and 20:4

## 3. Verification

- [x] 3.1 `make test` (312 tests), `make db`
- [ ] 3.2 A look in the running app after the database is rebuilt: a Synodal search for «желаю» no longer returns walls of Esther text (manual, owner)
