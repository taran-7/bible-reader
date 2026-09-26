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
