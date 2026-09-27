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

Порядок за [PRD](product-specs/prd.md) §6. Власник затвердив план 2026-09-27: v1.3 іде перед v2.0; v1.1 розділено на три слайси (1, 1a, 1b).

| # | Слайс (OpenSpec change) | Вимоги | Залежність | Паралельність |
|---|---|---|---|---|
| 0 | `add-platform-checks` | NFR-1, NFR-2, NFR-5 | — | parallel-safe |
| 0a | `add-ui-tests` (XCUITest) | FR-7, FR-10, FR-13, FR-14 (UI-докази) | — | зроблено 2026-09-27 (архів `2026-09-27-add-ui-tests`) |
| 0b | `add-a11y-launch-checks` | NFR-3 (запуск < 1 с), NFR-4 (VoiceOver, клавіатура) | 0a | parallel-safe з 0 |
| 1 | `add-reading-comfort` (v1.1) | FR-15, FR-16 | — | зроблено 2026-09-27 (архів `2026-09-27-add-reading-comfort`) |
| 1a | `add-copy-button` (v1.1) | FR-17 | 1 | зроблено 2026-09-27 (архів `2026-09-27-add-copy-button`) |
| 1b | `add-themes` (v1.1) | FR-31, FR-32, NFR-4 (контраст, зокрема кнопки копіювання 0,6) | 1 (масштаб шрифтів у всіх темах) | у роботі |
| 2 | `improve-search` (v1.2) | FR-18, FR-19, FR-20, FR-21, NFR-3 (пошук < 200 мс) | — | parallel-safe з 1 |
| 3 | `add-user-notes` (v1.3) | FR-22, FR-23, FR-24, FR-25 | — | serialize |
| 4 | `add-illustrations` (v1.4) | FR-33, FR-34, FR-35 | 1a (кнопка поруч із 6.3) | serialize |
| 5 | `add-parallel-view` (v2.0) | FR-26, FR-27 | — | serialize |
| 6 | `add-translations` (v2.1) | FR-28, FR-29, FR-30 | 5 (для Огієнка) | serialize |

Механізми NFR (затверджено 2026-09-27):

| NFR | Механізм |
|---|---|
| NFR-1 | Скрипт: `MACOSX_DEPLOYMENT_TARGET` у `project.yml` = 14.0 і `lipo -archs` бінарника містить arm64 і x86_64 |
| NFR-2 | Тест `@trace NFR-2`: у `Sources/` немає `URLSession`/`Network`, крім модуля ілюстрацій (FR-33…35) |
| NFR-3 | Пошук: тест з таймером на реальній базі (`improve-search`); запуск: вимір у XCUITest (`add-a11y-launch-checks`) |
| NFR-4 | XCUITest (`add-a11y-launch-checks`): accessibility labels і робота з клавіатури; контраст: тест токенів тем (FR-32) |
| NFR-5 | Скрипт: розмір `.app` після `xcodebuild` < 60 МБ |

NFR стає MVP-рядком разом зі слайсом, який додає його механізм.
