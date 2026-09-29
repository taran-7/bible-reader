# Handoff: де ми зараз

> Для AI-агента: прочитай цей файл першим, коротко перекажи користувачу стан і скажи наступний крок. Після кожного завершеного кроку онови цей файл.

Оновлено: 2026-09-28. Уся черга плану зроблена й змерджена (PR #10–#19).

## Стан
- Змерджено в `master`: v1.1 (шрифти, копіювання, теми), v1.2 пошук ([PR #11](https://github.com/taran-7/bible-reader/pull/11)), v1.3 закладки/підсвітки/нотатки ([PR #12](https://github.com/taran-7/bible-reader/pull/12)), доступність і запуск < 1 с, v1.5 «Порівняти», v2.0 паралельний перегляд і таблиця відповідностей KJV ↔ Синодальний, v2.1 модулі перекладів ([PR #13](https://github.com/taran-7/bible-reader/pull/13)), вибір розділу ([PR #15](https://github.com/taran-7/bible-reader/pull/15)), пакет tech debt ([PR #16](https://github.com/taran-7/bible-reader/pull/16)), v2.2 ілюстрації ([PR #18](https://github.com/taran-7/bible-reader/pull/18)), «зручне читання» — колонка ~75 знаків і «Порівняти» в головному вікні ([PR #19](https://github.com/taran-7/bible-reader/pull/19)).
- Слайси заархівовано в `openspec/changes/archive/2026-09-28-*` (рев'ю — `review-findings.json` у кожному); план — [mvp-capability-plan.md](../../mvp-capability-plan.md).
- `make test`: 235 тестів; `npm run qa:verify`: [automated-verification-latest.md](../../qa/automated-verification-latest.md). UI-тести ганяє CI (локально — з `QA_UI_TESTS=1` і розблокованим екраном).
- PD-13: `check-trajectory` рахує `Slice:`-коміти лише з `HEAD` (див. [project-factory.md](../../project-factory.md)).
- Як додати переклад: [translation-modules.md](../../translation-modules.md).

## Що далі (для агента)
1. v2.3 «Чорнетки проповідей» (FR-38…40) — слайс `add-sermon-drafts`; v2.4 відбір ілюстрацій моделлю (FR-41) — `add-illustration-curation`. Наступні слайси на вибір власника: (а) Foster «New Cyclopaedia of Prose Illustrations» (public domain) — локальне джерело ілюстрацій поруч з онлайн-пошуком; (б) перехресні посилання KJV (TSK / OpenBible.info). Відкрито: перевірити конфесію доменів allowlist ілюстрацій перед релізом.
2. Відкритий tech debt: [tech-debt-tracker.md](../tech-debt-tracker.md) (зокрема #20 права на Огієнка, #26 новіший Xcode у CI). Пакет #8, #9, #11–#15, #18, #23, #25 закрито слайсом `close-tech-debt-batch`.
3. Ручна перевірка людиною: VoiceOver-прохід, вигляд тем і паралельного перегляду на широкому/вузькому вікні.

## Корисне знати
- Жодної атрибуції Claude у комітах і PR (ні `Co-Authored-By`, ні підпису) — вимога власника.
- Launch-тест (`testLaunchUnderOneSecond`) іноді падає на VM CI (2–2,5 с): перезапуск job.
- База `bible.sqlite` не комітиться; генерується `make db` або pre-build скриптом Xcode.
- `.xcodeproj` генерується з `BibleReaderApp/project.yml` (`cd BibleReaderApp && xcodegen generate`), руками не правити.
- Відомі обмеження: `docs/exec-plans/tech-debt-tracker.md`.
- Користувач спілкується українською.
