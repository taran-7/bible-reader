# Handoff: де ми зараз

> Для AI-агента: прочитай цей файл першим, коротко перекажи користувачу стан і скажи наступний крок. Після кожного завершеного кроку онови ручну частину. Блок «Останні зміни» внизу генерує `node scripts/handoff.mjs` (pre-commit оновлює його сам). CI падає, якщо PR змінює код, а ручна частина ні; якщо стан справді не змінився, додай трейлер `Handoff: skip`.

Оновлено: 2026-09-30. Уся черга плану зроблена й змерджена (PR #10–#25).

## Стан
- Після плану: чорнетки проповідей FR-38…40 (#22), відбір ілюстрацій моделлю FR-41 (#23), рожева пастельна тема з м'ятною підсвіткою (#24), хуки: pre-push сканер секретів і хуки Claude Code (#25, PD-19), свіжість HANDOFF (PD-20).
- Змерджено в `master`: v1.1 (шрифти, копіювання, теми), v1.2 пошук ([PR #11](https://github.com/taran-7/bible-reader/pull/11)), v1.3 закладки/підсвітки/нотатки ([PR #12](https://github.com/taran-7/bible-reader/pull/12)), доступність і запуск < 1 с, v1.5 «Порівняти», v2.0 паралельний перегляд і таблиця відповідностей KJV ↔ Синодальний, v2.1 модулі перекладів ([PR #13](https://github.com/taran-7/bible-reader/pull/13)), вибір розділу ([PR #15](https://github.com/taran-7/bible-reader/pull/15)), пакет tech debt ([PR #16](https://github.com/taran-7/bible-reader/pull/16)), v2.2 ілюстрації ([PR #18](https://github.com/taran-7/bible-reader/pull/18)), «зручне читання» — колонка ~75 знаків і «Порівняти» в головному вікні ([PR #19](https://github.com/taran-7/bible-reader/pull/19)).
- Слайси заархівовано в `openspec/changes/archive/2026-09-28-*` (рев'ю — `review-findings.json` у кожному); план — [mvp-capability-plan.md](../../mvp-capability-plan.md).
- `make test`: 235 тестів; `npm run qa:verify`: [automated-verification-latest.md](../../qa/automated-verification-latest.md). UI-тести ганяє CI (локально — з `QA_UI_TESTS=1` і розблокованим екраном).
- PD-13: `check-trajectory` рахує `Slice:`-коміти лише з `HEAD` (див. [project-factory.md](../../project-factory.md)).
- Як додати переклад: [translation-modules.md](../../translation-modules.md).

## Що далі (для агента)
1. Наступні слайси на вибір власника: (а) Foster «New Cyclopaedia of Prose Illustrations» (public domain) — локальне джерело ілюстрацій поруч з онлайн-пошуком; (б) перехресні посилання KJV (TSK / OpenBible.info). Відкрито: перевірити конфесію доменів allowlist ілюстрацій перед релізом.
2. Відкритий tech debt: [tech-debt-tracker.md](../tech-debt-tracker.md) (зокрема #20 права на Огієнка, #26 новіший Xcode у CI). Пакет #8, #9, #11–#15, #18, #23, #25 закрито слайсом `close-tech-debt-batch`.
3. Реліз без підтвердження Gatekeeper: Developer ID + нотаризація (`make release`), коли у власника буде акаунт Apple Developer.
4. Ручна перевірка людиною: VoiceOver-прохід, вигляд тем і паралельного перегляду на широкому/вузькому вікні.

## Корисне знати
- Жодної атрибуції Claude у комітах і PR (ні `Co-Authored-By`, ні підпису) — вимога власника.
- Launch-тест (`testLaunchUnderOneSecond`) іноді падає на VM CI (2–2,5 с): перезапуск job.
- База `bible.sqlite` не комітиться; генерується `make db` або pre-build скриптом Xcode.
- `.xcodeproj` генерується з `BibleReaderApp/project.yml` (`cd BibleReaderApp && xcodegen generate`), руками не правити.
- Відомі обмеження: `docs/exec-plans/tech-debt-tracker.md`.
- Користувач спілкується українською.

<!-- BEGIN GENERATED: не редагувати вручну, оновлює `node scripts/handoff.mjs` -->
## Останні зміни (з git)
- 2026-09-29 PR #25: Хуки: pre-push сканер секретів і хуки Claude Code (PD-19)
- 2026-09-29 PR #24: Пастельна тема: рожева палітра (FR-31, FR-32)
- 2026-09-29 PR #23: Відбір ілюстрацій моделлю (FR-41) і запобіжники від витоку ключів (PD-18)
- 2026-09-29 PR #22: Чорнетки проповідей (FR-38…FR-40)
- 2026-09-28 PR #21: Виділений вірш не зсувається; Esc знімає виділення (PD-17)
- 2026-09-28 PR #20: Рев'ю останніх слайсів (maker ≠ checker), README і HANDOFF (PD-16, review-gate)
- 2026-09-28 PR #19: Зручне читання: колонка тексту і «Порівняти» в головному вікні (FR-15, FR-36)
- 2026-09-28 PR #18: Ілюстрації: живий пошук історій до віршів (FR-33…FR-35)

Активні зміни openspec: немає.
<!-- END GENERATED -->
