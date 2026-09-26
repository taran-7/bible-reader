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

1. **Baseline sign-off.** Власник ще не підтвердив [requirements.md](requirements.md) (FR-1…FR-14 як ASSUMPTION) і [план слайсів](mvp-capability-plan.md). Поки цього немає, G1 і G3 стоять як «needs sign-off».
2. **Нові пункти PRD не в ланцюгу.** 6.17 «Ілюстрації» (v1.4) і 6.18 «Теми оформлення» (v1.1) з'явилися в PRD після онбордингу. Їх треба додати в `requirements.md` як Future-рядки і розподілити по слайсах плану.
3. **Waivers для baseline.** Крок онбордингу 2b не зроблено: для MVP-вимог немає `docs/qa/waivers/*-baseline-*.md`, тому `check-acceptance-methods --mode=artifact` червоний. Набір waivers підтверджує власник разом із baseline.
4. **Червоні G6/G7 через веб-специфічні гейти.** `gate-status` досі вимагає recordings і visual-fidelity, яких для нативного додатка немає. Треба вирішити: адаптувати `gate-status` (коміт з `Refs: PD-x`, бо скрипт під lock) чи закрити їх waiver-ами.
5. **Докази UI.** FR-10 (⌘C, контекстне меню) і FR-14 (клік по результату) перевірено лише на рівні `ReaderViewModel`. Потрібен XCUITest або явний waiver; це пов'язано з tech debt #7.
6. **Тест на діакритику (FR-2).** Тест перевіряє лише кількість записів індексу, а нечутливість до діакритики не перевіряє.
7. **NFR без механізму.** NFR-1…NFR-5 (платформа, офлайн, швидкодія, доступність, розмір) стоять як Future, бо перевірок для них немає. Для кожного треба визначити механізм і слайс.
8. **Ratchet покриття не ввімкнено.** `quality/coverage-baseline.json` ще не створено. Треба прогнати `make coverage` і `check-coverage-ratchet --update`, а потім закомітити baseline.
9. **Process ratchet і телеметрія.** `quality/process-baseline.json` лишається шаблоном, а `trace/process-health.json` немає. Треба запустити `npm run retro:digest` і `check:process --update` після чесного зеленого прогону. Також вирішити, чи комітити `trace/ledger.jsonl`: хуки змінюють його після кожного коміту.
10. **Claude Code-хук.** `check:integrity` попереджає, що в `.claude/settings.json` немає `hooks`. ESLint-хук нам не підходить; можлива заміна — `swift build` після редагування `.swift`, але вона повільна.
11. **CI не перевірено.** `.github/workflows/ci.yml` ще жодного разу не запускався на GitHub (runner `macos-15`, `CODE_SIGNING_ALLOWED=NO`, генерація бази в pre-build). Також `check-traceability --check-fresh` у CI може впасти, якщо звіт закомічено несвіжим.
12. **Інші інструменти.** Адаптери Cursor, Codex і Copilot не встановлено. Три уроки про pixel-parity не вставлено в AGENTS.md. Якщо вони знадобляться, треба доставити.
13. **Оновлення з upstream.** Адаптовані скрипти розходяться з `project-factory`. Кожне оновлення означає повторну адаптацію і перегенерацію lock з `Refs: PD-x`. Можливо, варто перенести Swift-адаптацію у форк фабрики (конфіг шляхів замість правок у коді).
