# DB schema

> Генерується `bible-import` (`Sources/BibleCore/BibleImporter.swift`). Руками не правити; оновлювати виводом `sqlite3 BibleReaderApp/Resources/bible.sqlite .schema` після `make db`.

```sql
CREATE TABLE verses (
  translation TEXT    NOT NULL,  -- 'kjv' | 'synodal'
  book        INTEGER NOT NULL,  -- 1..66, протестантський порядок
  chapter     INTEGER NOT NULL,
  verse       INTEGER NOT NULL,
  text        TEXT    NOT NULL,
  search_text TEXT,              -- згорнутий текст (ё → е); NULL, якщо збігається з text
  PRIMARY KEY (translation, book, chapter, verse)
);

-- джерело для FTS: згорнутий текст, якщо є, інакше оригінал
CREATE VIEW verses_search AS
  SELECT rowid AS rowid, coalesce(search_text, text) AS search_text FROM verses;

-- external content: rowid збігається з verses.rowid, заповнюється 'rebuild'
CREATE VIRTUAL TABLE verses_fts USING fts5(
  search_text,
  content='verses_search',
  tokenize='unicode61 remove_diacritics 2'
);
```

Обсяг: KJV 31 102 вірші, Синодальний 31 349; файл ≈18 МБ.
