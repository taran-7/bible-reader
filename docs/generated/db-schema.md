# DB schema

> Генерується `bible-import`. Руками не правити. До появи генератора тут проєктна схема.

```sql
CREATE TABLE verses (
  translation TEXT    NOT NULL,  -- 'kjv' | 'synodal'
  book        INTEGER NOT NULL,  -- 1..66
  chapter     INTEGER NOT NULL,
  verse       INTEGER NOT NULL,
  text        TEXT    NOT NULL,
  PRIMARY KEY (translation, book, chapter, verse)
);

CREATE VIRTUAL TABLE verses_fts USING fts5(
  text,
  content='verses',
  tokenize='unicode61 remove_diacritics 2'
);
```
