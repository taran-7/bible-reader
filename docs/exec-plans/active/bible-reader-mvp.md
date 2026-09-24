# План: Bible Reader для macOS (capstone)

## Context
Capstone курсу вимагає власний невеликий проєкт з доведеними практиками agentic engineering. Користувач обрав десктопний додаток для читання Біблії в дусі biblequote.org. MVP: один переклад на екрані з перемикачем KJV ↔ Синодальний, навігація книга → розділ → вірш, копіювання цитати з посиланням, повнотекстовий пошук. Стек: SwiftUI + Swift Package `BibleCore` + GRDB (SQLite FTS5) + Swift CLI-конвертер. Паралельний перегляд і таблиця відповідностей нумерації поза межами MVP.

Репозиторій: `bible-reader` (окремий від форку курсу; у форку лише README з посиланням). Структура: `Package.swift`, `BibleReaderApp/`, `data/`, `docs/`, `openspec/`, `.claude/`.

## Кроки
1. **Специфікація**: OpenSpec change `bible-reader-mvp` (`/opsx:propose`) + `docs/product-specs/bible-reader-mvp.md` з погодженим дизайном; коміт на гілці `oleksandr-taraniuk`.
2. **План реалізації** через скіл writing-plans (задачі TDD: червоний тест → зелений).
3. **Дані**: `data/raw/en_kjv.json`, `data/raw/ru_synodal.json` з `thiagobodruk/bible` (однаковий формат для обох, суспільне надбання), `data/raw/SOURCE.md` з посиланням і ліцензією.
4. **Package.swift**: таргети `BibleCore` (lib, залежить від GRDB), `bible-import` (executable), `BibleCoreTests`. macOS 14+.
5. **BibleCore**: `Translation`, `Book` (1–66, назви/скорочення en/ru), `Verse`, `BibleRepository` (books, chapterCount, verses, search з екрануванням FTS-запиту), `Reference` (format/parse, діапазони).
6. **bible-import**: JSON → `bible.sqlite` (таблиця `verses` + `verses_fts` FTS5 `unicode61 remove_diacritics 2`).
7. **BibleReaderApp** (Xcode-проєкт): `NavigationSplitView`, тулбар з перемикачем перекладу, `.searchable` (посилання → перехід, інакше FTS), копіювання ⌘C/контекстне меню, екран помилки БД. `ReaderViewModel` `@Observable`.
8. **Харнес для доказів практик**: `CLAUDE.md` сабмішену (правила: TDD, `swift test` перед комітом), субагент-рецензент `.claude/agents/reviewer.md`, цикл `make check` (swift test до зеленого).
9. **README сабмішену** і заповнений PR-шаблон; відео робить користувач.

## Verification
- `swift test` у корені проєкту: імпорт (66 книг, кількість віршів KJV за джерелом ≈31 102, контрольні Быт 1:1 / Ин 3:16), Reference (parse/format обох мов, діапазони), пошук (регістр, кирилиця, спецсимволи `"*` не падають).
- `swift run bible-import data/raw BibleReaderApp/Resources/bible.sqlite` генерує базу.
- `xcodebuild -scheme BibleReader build`, потім ручна перевірка: навігація, перемикач, пошук «love»/«любовь», перехід «Ин 3:16», копіювання 3:16-18.
- Прохід субагента-рецензента по diff перед PR.

## Погоджений дизайн (коротко)
- **UI:** `NavigationSplitView`; бічна панель 66 книг (СЗ/НЗ) мовою перекладу; основна область з текстом розділу, ◀ ▶ і вибір розділу; перемикач KJV / Синодальний у тулбарі.
- **Пошук:** `.searchable`; якщо запит розбирається як посилання (`Ин 3:16`, `John 3`), відбувається перехід, інакше FTS з підсвіченими фрагментами; клік відкриває вірш.
- **Копіювання:** `«текст» (Ин. 3:16)`, діапазони `Ин. 3:16-18`.
- **Дані:** `ReaderViewModel` (`@Observable`) → `BibleRepository`; БД read-only з бандла, один `DatabaseQueue`.
- **Помилки:** екран помилки, якщо БД не відкрилась; «Нічого не знайдено»; FTS-запит екранується.
- **Відоме обмеження:** нумерація Синодального місцями відрізняється від KJV (Псалми тощо); UI перевіряється вручну.
