# AGENTS.md

Bible Reader: нативний macOS-додаток (SwiftUI) для читання Біблії, KJV і Синодальний переклад. Capstone курсу fwdays «Agentic Engineering».

Цей файл є картою, а не енциклопедією. Деталі лежать у `docs/`.

## Куди дивитися
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
Код ще не створено. Команди (`swift test`, `swift run bible-import …`, `xcodebuild …`) з'являться разом із `Package.swift`; тоді оновити цей розділ.
