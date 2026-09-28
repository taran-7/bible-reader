# platform Specification

## Purpose
Платформа, приватність, розмір, швидкість запуску й доступність: macOS 14+ лише на Apple Silicon, без мережі, `.app` < 100 МБ, запуск < 1 с, VoiceOver і клавіатура.

Вимоги в [docs/requirements.md](../../../docs/requirements.md): NFR-1, NFR-2, NFR-3, NFR-4, NFR-5.

## Requirements

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

### Requirement: Швидкий запуск
Додаток SHALL показувати перший розділ менш ніж за 1 секунду від старту процесу при повторному запуску (NFR-3).

#### Scenario: Повторний запуск
- **WHEN** додаток запускають удруге
- **THEN** від старту процесу до першого кадру з віршами минає < 1000 мс

### Requirement: Доступність
VoiceOver SHALL читати номер і текст кожного вірша, а кнопки тулбара SHALL мати текстові назви. Читання, пошук, копіювання, закладки, перехід між розділами й перекладами SHALL бути доступні лише з клавіатури (NFR-4).

#### Scenario: Мітка вірша
- **WHEN** VoiceOver фокусується на першому вірші Genesis 1
- **THEN** мітка починається з «1 In the beginning God created»

#### Scenario: Без миші
- **WHEN** користувач натискає ⌘F, вводить `John 3:16`, Return, ↓, ⌘C, ⌘D, ⌘], ⌘[, ⌘⌥3
- **THEN** відкривається John 3, копіюється цитата John 3:17, з'являється закладка розділу, відкриваються John 4 і знову John 3, а потім «Від Івана 3» в Огієнка
