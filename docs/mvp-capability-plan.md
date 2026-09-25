# Capability plan

Кожна вимога має одного власника. Baseline (v1.0) побудовано до онбордингу
фабрики, тому його слайс позначено як retrofitted у `.project-factory/retrofit.json`.

## Baseline (v1.0, retrofitted)

| Слайс | Capability (spec) | Вимоги | Статус |
|---|---|---|---|
| `bible-reader-mvp` | `bible-text-import` | FR-1, FR-2, FR-3 | заархівовано 2026-09-25 |
| `bible-reader-mvp` | `bible-reading` | FR-4, FR-5, FR-6, FR-7 | заархівовано 2026-09-25 |
| `bible-reader-mvp` | `scripture-reference` | FR-8, FR-9, FR-10 | заархівовано 2026-09-25 |
| `bible-reader-mvp` | `bible-search` | FR-11, FR-12, FR-13, FR-14 | заархівовано 2026-09-25 |

## Нова робота (кожен слайс проходить повний цикл G4)

Порядок за [PRD](product-specs/prd.md) §6. Відкрите питання PRD: v1.3 чи v2.0 першим.

| # | Слайс (OpenSpec change) | Вимоги | Залежність | Паралельність |
|---|---|---|---|---|
| 1 | `add-reading-comfort` (v1.1) | FR-15, FR-16, FR-17 | — | serialize |
| 2 | `improve-search` (v1.2) | FR-18, FR-19, FR-20, FR-21, NFR-3 | — | parallel-safe з 1 |
| 3 | `add-user-notes` (v1.3) | FR-22, FR-23, FR-24, FR-25 | — | serialize |
| 4 | `add-parallel-view` (v2.0) | FR-26, FR-27 | — | serialize |
| 5 | `add-translations` (v2.1) | FR-28, FR-29, FR-30 | 4 (для Огієнка) | serialize |

NFR-1, NFR-2, NFR-4, NFR-5 стають MVP-рядками, коли відповідний слайс додає
для них механізм перевірки.
