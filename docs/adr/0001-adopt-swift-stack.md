# ADR-0001: Лишаємо наявний стек Swift і адаптуємо під нього Project Factory

- **Статус:** accepted
- **Дата:** 2026-09-25

## Контекст

Project Factory ставиться на наявний проєкт (`/project-factory:onboard`). Фабрика
розрахована на Node/Next.js (Vitest, Playwright, ESLint, tsc), а Bible Reader
це Swift-пакет `BibleCore` + SwiftUI-додаток (XcodeGen), тести на Swift Testing,
SQLite FTS5, без мережі.

## Рішення

Стек не мігруємо. Node потрібен лише для детермінованих скриптів `scripts/*.mjs`;
runtime-залежностей у `package.json` немає. Адаптації (усі записано в `factory-lock.json`):

- Продуктовий код: `Sources/`, `BibleReaderApp/`, розширення `.swift`; тести: `Tests/**/*Tests.swift`.
  Без цього перевірки не бачили б Swift-код і давали б порожні «PASS».
- Модулі для `check-trajectory`: `Sources/<Module>/`.
- pre-commit: `swift build` замість ESLint/tsc; commit-msg вимагає трейлер для змін у `Sources/`, `BibleReaderApp/`.
- Набір `qa-verify`: `make test`, покриття через llvm-cov (`scripts/swift-coverage-summary.mjs`),
  збірка через `xcodebuild`; без Playwright, відеозаписів, a11y-сканера й pixel-parity.
- CI на `macos-15`.
- Не встановлено: `check-recordings`, `record-demos`, `check-a11y`, `check-visual-fidelity`
  (веб-специфічні), Claude Code PostToolUse-хук ESLint, адаптери Cursor/Codex/Copilot.
  Уроки `block-conquest-doctrine`, `capture-determinism`, `sampling-blindness` не
  вставлено в AGENTS.md: вони про pixel-parity вебсторінок.

## Наслідки

- Докази UI (FR-10, FR-14, NFR-4) поки ручні; для автоматизації потрібен XCUITest,
  і це окремий слайс.
- Оновлення скриптів з upstream потребує повторної адаптації і коміту з `Refs: PD-x`.
