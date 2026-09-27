## Контекст

Debug-збірка завжди містить лише архітектуру поточного Mac, тож перевіряти треба Release. `qa-verify.mjs` і `.github/workflows/ci.yml` зафіксовані в `factory-lock.json`: зміна потребує коміту з `Refs: PD-<n>` і запису в `docs/project-factory.md`.

## Рішення

- **Скрипт.** `scripts/check-platform.mjs` (Node, як інші `check-*`): `xcodebuild -configuration Release -derivedDataPath build/platform build`, потім:
  - `project.yml`: `deploymentTarget.macOS` = `"14.0"`;
  - `Info.plist` зібраного `.app`: `LSMinimumSystemVersion` = `14.0`;
  - `lipo -archs` бінарника містить `arm64`;
  - `du -sk` `.app` < 100 МБ (FAIL), ≥ 80 МБ — WARN.
  Друкує `Scope: 3 platform check(s)` і `Result: PASS|FAIL`, як решта перевірок; `--skip-build` бере вже зібраний `.app` (для CI після `make ui-test` не підходить — там Debug, тож CI будує Release окремо).
- **Архітектура.** `ARCHS: arm64` у `project.yml` для обох конфігурацій: Release не робить універсальний бінарник, `.app` менший.
- **Мережа.** Swift-тест, а не скрипт: живе поруч з кодом, `@trace NFR-2`, падає зі списком «файл:рядок». Шукаються `URLSession`, `URLRequest`, `NSURLConnection`, `import Network`, `WKWebView`, `http://`, `https://` у рядках коду (коментарі теж — адреса в коментарі не шкодить, але правило просте і без винятків). Дозволені файли — порожній список `allowedFiles`, який слайс `add-illustrations` поповнить.
- **Межі.** 100 МБ і 80 МБ — константи на початку скрипта.

## Ризики

- Release-збірка в CI додає ~1 хв.
- `du` рахує блоки диска, не байти; для межі в 100 МБ різниця незначна.
