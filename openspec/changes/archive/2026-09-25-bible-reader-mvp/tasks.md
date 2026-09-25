## 1. Каркас і дані

- [x] 1.1 Додати `data/raw/en_kjv.json` (`thiagobodruk/bible`), `data/raw/ru_synodal.json` (`scrollmapper/bible_databases` через `scripts/convert_synodal.py`) і `data/raw/SOURCE.md` (посилання, ліцензія); перевірка: обидва файли парсяться, по 66 книг
- [x] 1.2 Створити `Package.swift` (macOS 14, GRDB, таргети `BibleCore`, `bible-import`, `BibleCoreTests`, Swift Testing), `.gitignore` для `*.sqlite`; тест `SmokeTests.testPackageBuilds` зелений у `swift test`
- [x] 1.3 Оновити розділ «Команди» в `AGENTS.md`; перевірка: команди з розділу виконуються

## 2. Моделі

- [x] 2.1 `Translation` і `Book` (66 книг, заповіт, назви і скорочення en/ru); червоний→зелений `BookTests.testSixtySixBooks`, `testRussianNames` (1 = «Бытие», 40 = «От Матфея»), `testTestamentSplit`
- [x] 2.2 `Verse`; тест `VerseTests.testIdentity` (рівність за перекладом/книгою/розділом/віршем)

## 3. Імпорт (bible-text-import)

- [x] 3.1 `BibleImporter` читає JSON-фікстуру (2 книги) і пише `verses`; тест `ImporterTests.testImportsFixture`
- [x] 3.2 Очищення тексту (BOM, `{…}`); тест `ImporterTests.testStripsMarkup`
- [x] 3.3 FTS5 `verses_fts` і `rebuild`; тест `ImporterTests.testFtsRowCountMatchesVerses`
- [x] 3.4 Атомарний запис через `.tmp` і помилка для відсутнього/битого файлу; тести `ImporterTests.testMissingFileFailsWithoutOutput`, `testMalformedJsonFails`
- [x] 3.5 Імпорт реальних даних; тести `RealDataImportTests.testSixtySixBooksPerTranslation`, `testKjvVerseCount`, `testControlVerses` (Быт 1:1, Gen 1:1, Ин 3:16)
- [x] 3.6 CLI `bible-import <raw> <out>`; перевірка: `swift run bible-import data/raw BibleReaderApp/Resources/bible.sqlite` створює базу, код виходу 0; оновити `docs/generated/db-schema.md`

## 4. Репозиторій і навігація (bible-reading)

- [x] 4.1 Протокол `BibleRepository` і `SQLiteBibleRepository` (read-only `DatabaseQueue`): `books`, `chapterCount`, `verses`; тести `RepositoryTests.testChapterCount` (Genesis = 50), `testVersesOfJohn3`
- [x] 4.2 Помилка відкриття бази; тест `RepositoryTests.testMissingDatabaseThrows`
- [x] 4.3 `Navigator` (наступний/попередній розділ з переходом між книгами і межами Біблії); тести `NavigatorTests.testNextAtBookEnd` (Gen 50 → Exod 1), `testPreviousAtStartIsNil`, `testNextAtEndIsNil`

## 5. Посилання (scripture-reference)

- [x] 5.1 `Reference.parse`: тести `ReferenceParseTests.testRussianAbbrevWithVerse` (`Ин 3:16`), `testEnglishChapterOnly` (`John 3`), `testRange` (`ин. 3:16-18`), `testNumberedBooks` (`1 Кор 13:4`, `1 Cor 13:4`), `testNotAReference` (`любовь`, `Xyz 3:16`)
- [x] 5.2 Parse кожної з 66 книг за назвою і скороченням обох мов; тест `ReferenceParseTests.testAllBooksRoundTrip`
- [x] 5.3 `Reference.format` і `Quote.format`; тести `QuoteTests.testSingleVerseSynodal` (`(От Иоанна 3:16)`), `testRangeKjv` (`(John 3:16-18)`), `testJoinsTextsWithSpace`

## 6. Пошук (bible-search)

- [x] 6.1 Екранування запиту; тести `SearchQueryTests.testQuotesTokens`, `testEmptyQueryIsNil`
- [x] 6.2 `search(_:in:)` з фрагментами і сортуванням за книгами; тести `SearchTests.testLatin` (`love`), `testCyrillicCaseInsensitive` (`ЛЮБОВЬ` = `любовь`), `testOnlyActiveTranslation`, `testSpecialCharactersDoNotThrow` (`"love*`, `(`)

## 7. SwiftUI-додаток

- [x] 7.1 `ReaderViewModel` (`@Observable`): переклад, місце, вірші, пошук (посилання → перехід, інакше FTS), помилка; тести `ReaderViewModelTests.testSwitchTranslationKeepsPlace`, `testReferenceQueryNavigates`, `testTextQuerySearches` на фейковому репозиторії (view model у `BibleCore` або окремому тестованому таргеті)
- [x] 7.2 Xcode-проєкт `BibleReaderApp` (XcodeGen, `project.yml`) з локальною залежністю на пакет і ресурсом `bible.sqlite`; перевірка: `xcodebuild -scheme BibleReader build` успішний
- [x] 7.3 `NavigationSplitView`: книги СЗ/НЗ, текст розділу, вибір розділу, ◀ ▶, перемикач перекладу в тулбарі; ручна перевірка сценаріїв `bible-reading`
- [x] 7.4 `.searchable` з результатами і підсвіченими фрагментами, «Нічого не знайдено», клік відкриває вірш; ручна перевірка `love`/`любовь`, `Ин 3:16`
- [x] 7.5 Виділення віршів, ⌘C і контекстне меню «Копіювати»; ручна перевірка копіювання Ин 3:16-18
- [x] 7.6 Екран помилки бази; ручна перевірка з перейменованим `bible.sqlite` (реалізовано; ручну перевірку відкладено, tech debt #7)

## 8. Завершення

- [x] 8.1 Записати в `docs/exec-plans/tech-debt-tracker.md` обмеження нумерації і відсутності стемінгу; перевірка: записи присутні
- [x] 8.2 `swift test` зелений, прохід рецензента по diff; перевірка: вивід `swift test` без падінь
