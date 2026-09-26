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

## Project Factory

Цикл фабрики агентів (гейти, агенти `.claude/agents/`, скрипти `scripts/check-*.mjs`) описано в [docs/project-factory.md](docs/project-factory.md). Команда `npm run qa:verify` запускає весь набір перевірок, а `npm run gate:status` показує стан гейтів.

<!-- BEGIN-FACTORY-LESSONS -->
<!-- BEGIN-LESSON-vacuous-pass-not-earned -->
### Lesson: a PASS over zero evidence is NOT-EARNED (vacuous-pass-not-earned, v1)

- Never report a gate or check as PASS when its evidence scope is 0 ("Scope: 0
  clip(s)", empty archive, no eval results) while product code exists under
  `app/`, `src/`, `lib/`, `server/`, or `packages/`. Render it **NOT-EARNED**
  and exit non-zero.
- Before product code exists, an empty scope is **SKIP-pending**: print it
  explicitly; it is visible and never counted as PASS.
- Never fold SKIP / 0-scope results into an overall "Pass" summary
  (`qa-verify`, `gate-status`). Field evidence: `worst()` folded SKIP into
  PASS and G4–G8 rendered green over literally nothing
  (2026-07-02-pixel-perfect-forensics.md, RC2).
<!-- END-LESSON-vacuous-pass-not-earned -->

<!-- BEGIN-LESSON-declared-method-needs-mechanism -->
### Lesson: a declared acceptance method needs an executable mechanism (declared-method-needs-mechanism, v1)

- Every FR/NFR that declares a verification method (pixel-diff, e2e,
  recording, a11y, eval, ...) must resolve to a real, executable, non-stub
  mechanism BEFORE the build phase starts: an installed check script, or a
  package.json script whose body does not match
  `/^echo |^true$|not yet configured/i`.
- A spec file that restates the requirement is NOT a mechanism. Field
  evidence: NFR-19 encoded "≥ 99% pixel match" while no pixel-diff tool
  existed anywhere and `test:e2e` was an echo stub exiting 0
  (2026-07-02-pixel-perfect-forensics.md, RC1).
- If a declared method has no mechanism, do not proceed: implement the check,
  or record an explicit human waiver — never let the declaration float
  unverifiable into the build.
<!-- END-LESSON-declared-method-needs-mechanism -->

<!-- BEGIN-LESSON-done-claims-need-evidence -->
### Lesson: done-claims need evidence pointers (done-claims-need-evidence, v1)

- Never write strong completion language ("Convergence reached", "all gates
  pass", "verification-only", "Overall result: Pass", "ready for release /
  sign-off", "done", "complete") into current-state.md, PR bodies, or handoff
  docs unless the same line carries a resolvable evidence pointer — a path
  that exists on disk (e.g. `docs/qa/automated-verification-latest.md`) and
  is fresh — or an explicit "Scope NOT delivered" section.
- The verdict belongs to exit-coded checks, not narrative. Field evidence:
  "Convergence reached … verification-only" was written while the same file
  admitted the formal acceptance was never run
  (2026-07-02-pixel-perfect-forensics.md, RC6).
- When you catch an unbacked claim, treat it as a correction event: file it,
  do not silently rewrite it.
<!-- END-LESSON-done-claims-need-evidence -->

<!-- END-FACTORY-LESSONS -->
