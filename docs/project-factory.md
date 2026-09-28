# Project Factory

Цикл фабрики агентів з [taran-7/project-factory](https://github.com/taran-7/project-factory)
(форк koldovsky/project-factory), встановлений через `onboard`. Адаптації під
Swift описано в [ADR-0001](adr/0001-adopt-swift-stack.md).

## Що де

| Що | Де |
|---|---|
| Агенти (requirements-analyst, spec-writer, test-engineer, capability-implementer, code-reviewer, security-reviewer, spec-compliance-auditor, qa-documenter, process-auditor…) | `.claude/agents/` |
| Воркфлоу (spec-pipeline, review-gate, trajectory-eval, eval-suite, uat-triage) | `.claude/workflows/` |
| Детерміновані перевірки | `scripts/check-*.mjs`, `scripts/qa-verify.mjs`, `scripts/gate-status.mjs` |
| Вимоги з ID | [requirements.md](requirements.md) |
| План слайсів | [mvp-capability-plan.md](mvp-capability-plan.md) |
| Машинний стан фази | [current-state.md](current-state.md) |
| Згенеровані звіти (руками не правити) | `docs/qa/traceability-report.md`, `docs/qa/trajectory-report.md`, `trace/` |
| Хеш-замок скриптів гейтів | `factory-lock.json` |

## Правила ланцюга

- Спека цитує свої FR (`FR-n`), тест позначено `// @trace FR-n`.
- Коміт, що змінює `Sources/` чи `BibleReaderApp/`, має трейлер `Slice: <change>` або `Refs: FR-n`.
- Зміна скрипта гейту потребує коміту з `Refs: PD-x`, інакше `check:integrity` червоний.

## Команди

- `npm run qa:verify`: увесь набір перевірок, звіт у `docs/qa/automated-verification-latest.md`.
- `npm run gate:status`: обчислений стан гейтів G0–G8.
- `npm run check:trace`: ланцюг FR → spec → план → тест.
- `make coverage && npm run check:coverage`: ratchet покриття.

## Відкриті питання після онбордингу (2026-09-26)

1. ~~**Baseline sign-off.**~~ Закрито 2026-09-27: FR-1…FR-14 і план підтверджено, v1.3 перед v2.0. Було: власник ще не підтвердив [requirements.md](requirements.md) (FR-1…FR-14 як ASSUMPTION) і [план слайсів](mvp-capability-plan.md). Поки цього немає, G1 і G3 стоять як «needs sign-off».
2. ~~**Нові пункти PRD не в ланцюгу.**~~ Закрито 2026-09-27: FR-31…FR-35, слайс `add-illustrations`, NFR-2 уточнено. Було: 6.17 «Ілюстрації» (v1.4) і 6.18 «Теми оформлення» (v1.1) з'явилися в PRD після онбордингу. Їх треба додати в `requirements.md` як Future-рядки і розподілити по слайсах плану.
3. ~~**Waivers для baseline.**~~ Закрито 2026-09-27 (PD-8): MVP FR-1…14 уже мали тести, червоніли лише Future-рядки. `check-acceptance-methods --mode=artifact` тепер друкує їх як SKIP-pending і не рахує у вердикт; waivers не потрібні. Було: Крок онбордингу 2b не зроблено: для MVP-вимог немає `docs/qa/waivers/*-baseline-*.md`, тому `check-acceptance-methods --mode=artifact` червоний. Набір waivers підтверджує власник разом із baseline.
4. ~~**Червоні G6/G7 через веб-специфічні гейти.**~~ Закрито 2026-09-27 (PD-9): recordings і visual прибрано з G6/G7 і `--strict-recordings` з релізного traceability; evals відкладено до `add-illustrations`. Було: `gate-status` досі вимагає recordings і visual-fidelity, яких для нативного додатка немає. Треба вирішити: адаптувати `gate-status` (коміт з `Refs: PD-x`, бо скрипт під lock) чи закрити їх waiver-ами.
5. **Докази UI.** Рішення 2026-09-27: слайс `add-ui-tests`, XCUITest-таргет (`@trace FR-10`, `FR-14`), закриває tech debt #7; окреме завдання після проходу питань. FR-10 (⌘C, контекстне меню) і FR-14 (клік по результату) перевірено лише на рівні `ReaderViewModel`. Потрібен XCUITest або явний waiver; це пов'язано з tech debt #7.
6. ~~**Тест на діакритику (FR-2).**~~ Закрито 2026-09-27: новий тест знайшов баг (кирилічне «ё» не згорталось, 69 входжень у Синодальному); виправлено згортанням `ё → е` у `BibleCore`. Було: Тест перевіряє лише кількість записів індексу, а нечутливість до діакритики не перевіряє.
7. ~~**NFR без механізму.**~~ Закрито 2026-09-27: механізми і слайси (`add-platform-checks`, `add-ui-tests`) у [плані](mvp-capability-plan.md). Було: NFR-1…NFR-5 (платформа, офлайн, швидкодія, доступність, розмір) стоять як Future, бо перевірок для них немає. Для кожного треба визначити механізм і слайс.
8. ~~**Ratchet покриття не ввімкнено.**~~ Закрито 2026-09-27 (PD-10): baseline lines 96,15 %, regions 91,97 %, functions 92,86 %; branches виключено, бо Swift їх не збирає (було фіктивні 100 % на 0/0). Було: `quality/coverage-baseline.json` ще не створено. Треба прогнати `make coverage` і `check-coverage-ratchet --update`, а потім закомітити baseline.
9. ~~**Process ratchet і телеметрія.**~~ Закрито 2026-09-27: `trace/ledger.jsonl` локальний (у `.gitignore`), у git лише дайджест `trace/process-health.json` + `docs/qa/process-health.md` (`npm run retro:digest`); `quality/process-baseline.json` зароблено після зеленого `qa:verify` (acceptance coverage 14/40, vacuousPasses 0). Було: `quality/process-baseline.json` лишається шаблоном, а `trace/process-health.json` немає. Треба запустити `npm run retro:digest` і `check:process --update` після чесного зеленого прогону. Також вирішити, чи комітити `trace/ledger.jsonl`: хуки змінюють його після кожного коміту.
10. ~~**Claude Code-хук.**~~ Закрито 2026-09-27: Stop-хук `.claude/hooks/swift-build-on-stop.sh` запускає `swift build`, якщо змінено `.swift`, і блокує завершення ходу при помилці. Було: `check:integrity` попереджає, що в `.claude/settings.json` немає `hooks`. ESLint-хук нам не підходить; можлива заміна — `swift build` після редагування `.swift`, але вона повільна.
11. **CI не перевірено.** `.github/workflows/ci.yml` ще жодного разу не запускався на GitHub (runner `macos-15`, `CODE_SIGNING_ALLOWED=NO`, генерація бази в pre-build). Також `check-traceability --check-fresh` у CI може впасти, якщо звіт закомічено несвіжим.
12. ~~**Інші інструменти.**~~ Закрито 2026-09-27 як «не потрібно»: працюємо лише в Claude Code; уроки pixel-parity нерелевантні після PD-9. Повернутися, якщо з'явиться другий інструмент або візуальні макети (наприклад, для тем 6.18). Було: Адаптери Cursor, Codex і Copilot не встановлено. Три уроки про pixel-parity не вставлено в AGENTS.md. Якщо вони знадобляться, треба доставити.
13. ~~**Оновлення з upstream.**~~ Закрито 2026-09-27: правки лишаються локальними, процедура в розділі «Оновлення з upstream». Форк з конфігом шляхів — лише якщо оновлення стануть регулярними. Було: Адаптовані скрипти розходяться з `project-factory`. Кожне оновлення означає повторну адаптацію і перегенерацію lock з `Refs: PD-x`. Можливо, варто перенести Swift-адаптацію у форк фабрики (конфіг шляхів замість правок у коді).
14. ~~**Релізний trajectory і retrofit.**~~ Закрито 2026-09-27: справжнє retrofit-рев'ю (code, security, spec), 5 підтверджених дефектів виправлено (R1–R4, trace FR-9), решта в tech debt #8–#14; `review-findings.json` у архіві слайсу. Було: `check-trajectory --release --check-fresh` червоний для `bible-reader-mvp`: немає `review-findings.json`, коміту з `Slice: bible-reader-mvp`, а звіт «застарілий» у релізному режимі. Варіанти: справжнє рев'ю baseline (`code-reviewer`, `security-reviewer`) або релізний режим, що поважає `.project-factory/retrofit.json`.

## Оновлення з upstream

Скрипти фабрики адаптовано під Swift правками в коді. Список адаптацій лежить у `factory-lock.json` → `adaptations`, правила проєкту позначено в коді як `PD-8`, `PD-9`, `PD-10` (див. нижче). Оновлення скрипта:

1. `diff` нашої копії з новою версією upstream.
2. Взяти нову версію і знову накласти Swift-адаптації та правки `PD-n` (шукати `grep -n "PD-" scripts/*.mjs`).
3. `npm run qa:verify` має лишитися Pass.
4. `node scripts/check-factory-integrity.mjs --init-lock --adaptation "<що змінено>"` і коміт з `Refs: PD-<n>`.

## Зміни правил фабрики

- **PD-8 (2026-09-27).** `check-acceptance-methods --mode=artifact`: рядки `Future` без артефакту друкуються як SKIP-pending і не входять у вердикт; PASS/FAIL вирішують лише MVP-рядки. Причина: роадмап без коду робив перевірку вічно червоною (26 FAIL), а waiver на кожен майбутній рядок змішував «ще не будували» зі «свідомо приймаємо ризик». Слайс, що переводить рядок у MVP, робить перевірку знову жорсткою.
- **PD-9 (2026-09-27).** `gate-status`: `recordings` і `visual-fidelity` (Playwright, попіксельне порівняння) не входять у G6/G7, а релізний traceability запускається без `--strict-recordings`. Нативний macOS-додаток без веб-макетів таких артефактів не має, тож гейти були б червоні назавжди. `evals` відкладено до слайсу `add-illustrations` (v1.4): у G6 він видимий як `deferred`, у PASS не рахується. Рядки цих перевірок і далі друкуються в таблиці.
- **PD-10 (2026-09-27).** `check-coverage-ratchet` і `swift-coverage-summary`: метрика з порожнім скоупом (0 з 0) має `pct: null`, друкується як SKIP-pending і не входить у baseline. Причина: Swift не збирає покриття гілок, а 0/0 рахувалося як 100 % і ставало планкою над нічим. Якщо метрика є в baseline, а скоупу вже немає, це FAIL.

- **PD-11 (2026-09-27).** `qa-verify`: UI-тести (XCUITest) керують реальними мишею, клавіатурою і буфером обміну, тож локально запускаються лише з `QA_UI_TESTS=1`, а в CI — завжди; без них член `app-ui-tests` у списку DEFERRED. Причина: слайс `add-ui-tests`.
- **PD-12 (2026-09-27).** `qa-verify` і CI: член `app-build` тепер `scripts/check-platform.mjs` — Release-збірка замість Debug, і на ній перевіряється — мінімальна macOS 14.0, архітектура `arm64`, `.app` < 100 МБ (WARN від 80). Причина: NFR-1 і NFR-5 не мали механізму перевірки (слайс `add-platform-checks`); власник звузив NFR-1 до Apple Silicon і підняв межу NFR-5 до 100 МБ.
- **PD-13 (2026-09-28).** `check-trajectory`: коміти з `Slice:` рахуються лише досяжні з `HEAD` (було `git log --all`). Причина: `--all` залежав від локальних гілок і старих SHA після rebase, тож звіт, згенерований на машині розробника, у CI був «застарілим» (PR #12), а його регенерація нічого не виправляла.
- **PD-14 (2026-09-28).** CI: UI-тест часу запуску (NFR-3) на спільній VM GitHub має межу 2000 мс (`TEST_RUNNER_BIBLE_LAUNCH_BUDGET_MS`), локально на Mac — 1000 мс. Причина: на CI теплий запуск Debug-збірки коливався 800–1800 мс навіть на PR лише з документацією; вимір лишається й записується у вкладення, а межа 1 с перевіряється на реальному Mac (`QA_UI_TESTS=1`).

## Correction events

- **2026-09-27, vacuous passes у журналі.** `trace/process-health.json` мав 2 vacuous passes: `qa-verify` 2026-09-26 запускав `eval-ratchet` на нульовому скоупі (`scope_n: 0`, exit 0), бо evals тоді не були відкладені. Причину усунуто PD-9 (`eval-ratchet` у `qa-verify` як DEFERRED). Журнал до виправлення заархівовано локально як `trace/ledger-2026-09-26.jsonl`; baseline процесу зароблено на новому журналі.
