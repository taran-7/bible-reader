# Architecture

## Modules
```
Package.swift
├── BibleCore        library: models, BibleRepository, Reference (no UI)
├── bible-import     CLI: data/raw/*.json → bible.sqlite
└── BibleCoreTests   tests for BibleCore and the importer
BibleReaderApp/      SwiftUI app, depends on BibleCore
data/raw/            source texts (thiagobodruk/bible) + SOURCE.md
```

## Boundaries
- `BibleCore` does not import SwiftUI/AppKit.
- Database access goes only through `BibleRepository` (GRDB, `DatabaseQueue`, read-only).
- UI state lives in `ReaderViewModel` (`@Observable`).

## Data flow
`data/raw` → `bible-import` → `bible.sqlite` (bundle resource) → `BibleRepository` → `ReaderViewModel` → SwiftUI views.

## Key types
- `Translation`: `kjv`, `synodal`.
- `Book`: number 1–66, names and abbreviations en/ru.
- `Verse`: book, chapter, verse, text.
- `Reference`: parsing (`Ин 3:16`, `John 3`) and formatting (`Ин. 3:16-18`).

DB schema: [docs/generated/db-schema.md](docs/generated/db-schema.md).
