# Архітектура

## Модулі
```
Package.swift
├── BibleCore        бібліотека: моделі, BibleRepository, Reference (без UI)
├── bible-import     CLI: data/raw/*.json → bible.sqlite
└── BibleCoreTests   XCTest для BibleCore і імпорту
BibleReaderApp/      SwiftUI-додаток, залежить від BibleCore
data/raw/            вихідні тексти (thiagobodruk/bible) + SOURCE.md
```

## Межі
- `BibleCore` не імпортує SwiftUI/AppKit.
- Доступ до БД тільки через `BibleRepository` (GRDB, `DatabaseQueue`, read-only).
- UI-стан зберігається в `ReaderViewModel` (`@Observable`).

## Потік даних
`data/raw` → `bible-import` → `bible.sqlite` (ресурс бандла) → `BibleRepository` → `ReaderViewModel` → SwiftUI views.

## Ключові типи
- `Translation`: `kjv`, `synodal`.
- `Book`: номер 1–66, назви та скорочення en/ru.
- `Verse`: книга, розділ, вірш, текст.
- `Reference`: розбір (`Ин 3:16`, `John 3`) і форматування (`Ин. 3:16-18`).

Схема БД: [docs/generated/db-schema.md](docs/generated/db-schema.md).
