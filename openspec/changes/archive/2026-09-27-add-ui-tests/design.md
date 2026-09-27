## Контекст

Додаток: SwiftUI, логіка в `BibleCore` (`ReaderViewModel`). UI-тести на macOS потребують Automation Mode (локально: одноразове підтвердження або `automationmodetool`; на GitHub `macos-15` увімкнено).

## Рішення

- **Де тести.** `Tests/BibleReaderUITests/*Tests.swift`: так їх бачать `check-traceability` і `check-acceptance-methods` (шукають `@trace` у `Tests/`). SwiftPM цю теку ігнорує, бо таргет не оголошено в `Package.swift`.
- **База для тестів.** Тести працюють з реальною `bible.sqlite` з бандла (детермінована, генерується з `data/raw`). Для FR-7 додаток запускається з `BIBLE_READER_DB=/nonexistent/bible.sqlite`.
- **Вибір шляху.** `DatabaseLocation.url(environment:bundled:)`: непорожня `BIBLE_READER_DB` має пріоритет; інакше файл з бандла; немає ні того, ні іншого → `RepositoryError.cannotOpen`. Unit-тести в `BibleCoreTests`.
- **Ідентифікатори.** `verse-<n>` на рядку вірша, `search-result` на кнопці результату, `database-error` на екрані помилки.
- **Буфер обміну.** Тест читає `NSPasteboard.general` у процесі раннера (спільний системний буфер); перед дією очищає його.
- **Фокус.** «Вірш у фокусі» перевіряється як `isSelected` рядка `verse-16` після навігації.

- **Незалежність від розкладки.** `typeText` друкує кодами клавіш поточної розкладки (у розробника RussianWin), тому пошук вводиться вставкою через пункт меню `paste:`, а ⌘C натискається фізичною клавішею C (символ визначає `UCKeyTranslate`).
- **Відновлення вікон.** Запуск з `-ApplePersistenceIgnoreState YES`, інакше вікно інколи не відкривається.
- **Фокус після навігації.** `ChapterView` переводить клавіатурний фокус у список віршів, коли навігація фокусує вірш, щоб ⌘C копіював цитату.

## Ризики

- UI-тести повільні (~1 хв) і залежать від Automation Mode; локально перший запуск просить підтвердження.
- Флакі від анімацій: скрізь `waitForExistence`, без `sleep`.
