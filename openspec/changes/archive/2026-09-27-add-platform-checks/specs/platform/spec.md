## ADDED Requirements

### Requirement: Платформа
Додаток SHALL збиратися для macOS 14 і новіших і SHALL містити код для Apple Silicon (`arm64`); збірка під Intel не підтримується (NFR-1).

#### Scenario: Release-збірка
- **WHEN** виконується `node scripts/check-platform.mjs`
- **THEN** `LSMinimumSystemVersion` зібраного додатка — `14.0`, а `lipo -archs` бінарника містить `arm64`

### Requirement: Без мережі
Код додатка SHALL не використовувати мережеві API (`URLSession`, `URLRequest`, `NSURLConnection`, `Network`, `WKWebView`) і не містити адрес `http(s)://`, окрім файлів модуля ілюстрацій, явно дозволених у тесті (NFR-2).

#### Scenario: Мережевий виклик у коді
- **WHEN** у файлі з `Sources/` з'являється `URLSession`
- **THEN** тест `NetworkIsolationTests` падає з назвою файлу і номером рядка

### Requirement: Розмір додатка
Зібраний Release `.app` SHALL бути меншим за 100 МБ; від 80 МБ перевірка SHALL друкувати попередження (NFR-5).

#### Scenario: Наближення до межі
- **WHEN** `.app` важить 85 МБ
- **THEN** `check-platform` друкує WARN, але результат PASS
