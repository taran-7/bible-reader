## Why

NFR-1 (платформа), NFR-2 (офлайн) і NFR-5 (розмір) виконуються, але їх ніщо не перевіряє: зламати будь-яку можна без жодного червоного тесту. Після `add-translations` `.app` важить ~46 МБ і росте з кожним перекладом, а мережа з'явиться в v1.4 (ілюстрації).

Власник 2026-09-27 уточнив вимоги для open source: збираємо лише під Apple Silicon (Intel — поза обсягом, хто потребує, збере сам); межа розміру — 100 МБ замість 60 (60 МБ не мало технічної причини).

## What Changes

- NFR-1: macOS 14+, лише Apple Silicon; `project.yml` явно задає `ARCHS = arm64`.
- NFR-5: `.app` < 100 МБ, попередження від 80 МБ.
- `scripts/check-platform.mjs`: Release-збірка, мінімальна macOS 14.0 у `project.yml` і в `Info.plist` зібраного додатка, `lipo -archs` містить `arm64`, розмір `.app`.
- Тест `NetworkIsolationTests` (NFR-2): у `Sources/` і `BibleReaderApp/Sources/` немає мережевих API (`URLSession`, `import Network`, `NSURLConnection`, `WKWebView`) і адрес `http(s)://`; виняток — майбутній модуль ілюстрацій (порожній список дозволених файлів).
- `qa-verify` і CI запускають `check-platform` (`Refs: PD-12`).
- PRD і `docs/requirements.md`: NFR-1, NFR-5 з новими формулюваннями; NFR-1, NFR-2, NFR-5 → MVP.

## Non-goals

- Збірка під Intel чи універсальний бінарник.
- Підпис, нотаризація, ліцензія репозиторію (окреме питання open source).
