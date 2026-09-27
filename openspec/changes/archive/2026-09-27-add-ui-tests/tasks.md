## 1. Шлях до бази (BibleCore)

- [x] 1.1 Червоні тести `DatabaseLocationTests`: змінна середовища має пріоритет; порожня змінна ігнорується; без змінної береться бандл; без обох — `RepositoryError.cannotOpen`
- [x] 1.2 `DatabaseLocation.url(environment:bundled:)`; `BibleReaderApp` використовує його

## 2. UI-таргет і ідентифікатори

- [x] 2.1 Таргет `BibleReaderUITests` у `project.yml`, схема `BibleReader` запускає його в `test`; `make ui-test`
- [x] 2.2 Accessibility identifiers: `verse-<n>`, `search-result`, `database-error`

## 3. UI-тести (спершу червоні)

- [x] 3.1 FR-13: пошук `John 3:16` відкриває John 3 з виділеним віршем 16; потім `Rom 3:16` виділяє 16 у Romans 3
- [x] 3.2 FR-10 (знайдено і виправлено баг: після пошуку фокус лишався в полі, ⌘C копіював запит; `ChapterView` тепер фокусує список): ⌘C на виділеному вірші кладе в буфер `«…» (John 3:16)`; контекстне меню «Копіювати» робить те саме
- [x] 3.3 FR-14: текстовий пошук і клік по першому результату відкривають його розділ з виділеним віршем
- [x] 3.4 FR-7: запуск з `BIBLE_READER_DB` на неіснуючий файл показує екран помилки

## 4. Батарея і документи

- [x] 4.1 `qa-verify` і CI: `xcodebuild test` замість `build` (`Refs: PD-11`)
- [x] 4.2 `docs/requirements.md` §4, tech debt #2 і #7, план слайсів; рев'ю; архів
