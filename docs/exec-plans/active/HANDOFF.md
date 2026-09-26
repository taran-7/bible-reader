# Handoff: де ми зараз

> Для AI-агента: прочитай цей файл першим, коротко перекажи користувачу стан і скажи наступний крок. Після кожного завершеного кроку онови цей файл.

Оновлено: 2026-09-26. Прогрес 27/27; ручну перевірку 7.6 винесено в tech debt #7.

## Стан
- MVP (v1.0) завершено: [PR #1](https://github.com/taran-7/bible-reader/pull/1) змерджено в `main`.
- OpenSpec change `bible-reader-mvp` заархівовано в `openspec/changes/archive/2026-09-25-bible-reader-mvp/`; вимоги в `openspec/specs/` (`bible-reading`, `bible-search`, `bible-text-import`, `scripture-reference`).
- План MVP перенесено в `docs/exec-plans/completed/bible-reader-mvp.md`.
- `swift test`: 57 тестів зелені. Xcode 27.0 і XcodeGen встановлено.
- Продукт описано в PRD: [docs/product-specs/prd.md](../../product-specs/prd.md) (роадмап v1.1–v2.1).
- У PRD додано 6.18 «Теми оформлення» у v1.1: Світла, Темна, Скло (Liquid Glass), Пастельна, Манускрипт; палітри з перевіреним контрастом WCAG.
- У PRD додано v1.4 «Ілюстрації» (6.17): кнопка «Пошук ілюстрацій» поруч із «Копіювати», реальні історії до віршів (до 7), лише англомовні протестантські/баптистські джерела. Пошук безкоштовний: локальний індекс (sitemap/RSS у SQLite FTS) + живий пошук на сайтах allowlist. Стартовий allowlist/blocklist: [illustration-sources.md](../../product-specs/illustration-sources.md), домени ще не перевірені.

## Що далі (для агента)
1. Спитати користувача про відкрите питання PRD: що першим, v1.3 (закладки, нотатки) чи v2.0 (паралельний перегляд). Зараз v1.3 стоїть першим.
2. Почати v1.1 «Зручність читання» (PRD 6.1–6.3: масштаб шрифтів, масштаб інтерфейсу, напівпрозора кнопка копіювання праворуч зверху на виділенні з написом «Скопійовано»): гілка `feature/02-<change>`, `/opsx:propose`.
3. Перед реалізацією 6.17 обговорити: хто відбирає й переказує історії (кандидат Apple Foundation Models, macOS 26+), розмір і частоту оновлення індексу, адаптери сайтів; перевірити домени allowlist.
4. Далі за планом курсу: харнес (`.claude/agents/reviewer.md`, `make check`) і README сабмішену (відео робить користувач).

## Корисне знати
- База `bible.sqlite` не комітиться; генерується `make db` або pre-build скриптом Xcode.
- `.xcodeproj` генерується з `BibleReaderApp/project.yml` (`cd BibleReaderApp && xcodegen generate`), руками не правити.
- Відомі обмеження: `docs/exec-plans/tech-debt-tracker.md`.
- Користувач спілкується українською.
