# AGENTS.md

Bible Reader: нативний macOS-додаток (SwiftUI) для читання Біблії, KJV і Синодальний переклад. Capstone курсу fwdays «Agentic Engineering».

Цей файл є картою, а не енциклопедією. Деталі лежать у `docs/`.

## Куди дивитися
- **Почни з [docs/exec-plans/active/HANDOFF.md](docs/exec-plans/active/HANDOFF.md)**: поточний стан і наступний крок.
- [ARCHITECTURE.md](ARCHITECTURE.md): модулі, межі, потік даних.
- [docs/design-docs/core-beliefs.md](docs/design-docs/core-beliefs.md): принципи, яких тримаємося.
- [docs/product-specs/](docs/product-specs/index.md): що будуємо (поведінка для користувача).
- [docs/exec-plans/active/](docs/exec-plans/active/): поточний план виконання. Завершені плани переносимо в `completed/`.
- [docs/exec-plans/tech-debt-tracker.md](docs/exec-plans/tech-debt-tracker.md): відомі обмеження і борг.
- [docs/generated/db-schema.md](docs/generated/db-schema.md): схема БД (генерується, руками не правити).
- `openspec/`: зміни у форматі OpenSpec (`/opsx:propose`, `/opsx:apply`, `/opsx:archive`).

## Правила
- Мова документації: українська.
- TDD: спочатку червоний тест у `BibleCoreTests`, потім реалізація.
- Перед комітом `swift test` має бути зеленим.
- Логіка живе в `BibleCore`; SwiftUI-шар тільки відображає стан і викликає `BibleRepository`.

## Команди
- `make test`: `swift test` (якщо активні лише Command Line Tools, додає шляхи до Swift Testing). Тести пишемо на Swift Testing (`import Testing`).
- `make db`: `swift run bible-import data/raw BibleReaderApp/Resources/bible.sqlite`.
- `python3 scripts/convert_synodal.py RusSynodal.json data/raw/ru_synodal.json`: перегенерувати Синодальний (див. `data/raw/SOURCE.md`).
- `cd BibleReaderApp && xcodegen generate`: перегенерувати `BibleReader.xcodeproj` з `project.yml` (руками `.xcodeproj` не правити).
- `xcodebuild -project BibleReaderApp/BibleReader.xcodeproj -scheme BibleReader build`: збірка додатка; база генерується pre-build скриптом, якщо її немає.
