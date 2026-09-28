## 1. Процес (PD-15)

- [x] 1.1 Pre-commit: `execFileSync("git", ["show", ...])` замість shell-рядка (#8); перевірено файлом `$(touch PWNED)`
- [x] 1.2 CI: `permissions: contents: read`, actions за SHA, `@fission-ai/openspec@1.13.2` (#9); перепечатано `factory-lock.json`

## 2. Навігація й помилка читання

- [x] 2.1 Червоні тести: `testPreviousIntoEmptyBookIsNil`, `testTransientReadErrorClearsOnNextSuccessfulLoad`, `testPrevNextCloseSearchResults`, `testCanGoDoesNotQueryDatabaseOnEveryRead`, `testChapterPastBookEndOpensLastChapter`
- [x] 2.2 `Navigator.previous` без розділу 0; `canGoPrevious/Next` при завантаженні; `retryLoad`; кнопка в `DatabaseErrorView`

## 3. Імпорт

- [x] 3.1 Червоні тести: `testTruncatedSourceFailsWithoutOutput`, `testCommandUsageErrorExits64`, `testCommandImportErrorExits1WithMessage`
- [x] 3.2 `expectedBooks`, `ImportError.incomplete`, `ImportCommand`

## 4. Переклади

- [x] 4.1 Червоний тест `testShortcutByPhysicalKeyIgnoresLayout`; `TranslationShortcut.index(forKeyCode:)`, `TranslationKeyMonitor`
- [x] 4.2 Червоні тести `CustomVersificationTests`, `testNewNumberingNeedsTableInManifest`; `Numbering` як рядок, `VersificationTable`, KJV-вузол

## 5. Тема й масштаб поля пошуку

- [x] 5.1 Червоний тест `testSearchFieldFollowsThemeAndScale`; `SearchFieldStyle`, `SearchFieldStyler`; фон форми Settings

## 6. Спеки й борг

- [x] 6.1 Дельти спек: ⌘[ ⌘], розділ поза книгою, `1Ин`, неповний імпорт, нумерації з маніфесту, ⌘⌥ за клавішею, поле пошуку в темі
- [x] 6.2 `tech-debt-tracker.md`: #8, #9, #11–#15, #18, #23, #25 закрито
