# DB schema

> Генерується `bible-import` (`Sources/BibleCore/BibleImporter.swift`). Руками не правити; оновлювати виводом `sqlite3 BibleReaderApp/Resources/bible.sqlite .schema` після `make db`.

```sql
CREATE TABLE verses (
  translation TEXT    NOT NULL,  -- 'kjv' | 'synodal'
  book        INTEGER NOT NULL,  -- 1..66, протестантський порядок
  chapter     INTEGER NOT NULL,
  verse       INTEGER NOT NULL,
  text        TEXT    NOT NULL,
  PRIMARY KEY (translation, book, chapter, verse)
);

-- external content: rowid збігається з verses.rowid, заповнюється 'rebuild'
CREATE VIRTUAL TABLE verses_fts USING fts5(
  text,
  content='verses',
  tokenize='unicode61 remove_diacritics 2'
);
```

Обсяг: KJV 31 102 вірші, Синодальний 31 349; файл ≈18 МБ.
