# Requirements Document

**Bible Reader для macOS**

*Реконструйовано з коду, тестів і `openspec/specs/` під час онбордингу Project Factory (2026-09-25).*

> **ASSUMPTION.** Кожен рядок MVP описує поведінку, яку код **уже має**
> (baseline, v1.0). Це гіпотеза, яку власник підтверджує або виправляє на
> чекпоінті baseline sign-off. Продуктовий опис і пріоритети лишаються в
> [PRD](product-specs/prd.md); тут канонічні ID для ланцюга FR → spec → план → тест.

## 1 Огляд продукту

Легкий нативний читач Біблії для macOS без мережі й акаунтів: знайти місце за
секунди, прочитати його в кількох перекладах і процитувати з правильним
посиланням. MVP (v1.0): KJV і Синодальний, навігація, пошук, копіювання цитат.
Роадмап v1.1–v2.1 у рядках `Future` нижче (номери пунктів PRD у дужках).

## 2 Functional Requirements (FR)

Verification tags: `local-verifiable` означає, що `swift test` (`Tests/BibleCoreTests`)
доводить поведінку детерміновано; тест позначено `@trace FR-n`.

### 2.1 Імпорт текстів (`bible-text-import`)

| ID | Phase | Area | Description | Verification |
|---|---|---|---|---|
| FR-1 | MVP | Import | `bible-import` зчитує JSON KJV і Синодального з `data/raw` і пише всі вірші в одну базу з перекладом, книгою (1–66), розділом і віршем; контрольні вірші (Gen 1:1, John 3:16) присутні. | local-verifiable |
| FR-2 | MVP | Import | Імпорт будує FTS-індекс, нечутливий до регістру й діакритики (латиниця й кирилиця); записів індексу стільки ж, скільки віршів. | local-verifiable |
| FR-3 | MVP | Import | Відсутній або зіпсований вхідний файл дає ненульовий код і повідомлення з назвою файлу; частково записаної бази не лишається. | local-verifiable |

### 2.2 Читання (`bible-reading`)

| ID | Phase | Area | Description | Verification |
|---|---|---|---|---|
| FR-4 | MVP | Reading | На екрані один переклад; перемикання KJV ↔ Синодальний лишає ту саму книгу й розділ. | local-verifiable |
| FR-5 | MVP | Reading | Список 66 книг, згрупований на СЗ і НЗ, з назвами мовою активного перекладу. | local-verifiable |
| FR-6 | MVP | Reading | Розділ показано з номерами віршів; ◀ ▶ переходять між розділами і через межу книги; на межах Біблії кнопка неактивна. | local-verifiable |
| FR-7 | MVP | Reading | Якщо базу не вдалося відкрити, показано екран помилки замість порожнього читача; додаток не падає. | local-verifiable |

### 2.3 Посилання і цитати (`scripture-reference`)

| ID | Phase | Area | Description | Verification |
|---|---|---|---|---|
| FR-8 | MVP | Reference | Розбір `<книга> <розділ>[:<вірш>[-<вірш>]]` за повною назвою або скороченням (en/ru), без урахування регістру, з крапкою чи без; інше означає «не посилання». | local-verifiable |
| FR-9 | MVP | Reference | Цитата має вигляд `«текст» (<повна назва книги> <розділ>:<вірш>)` мовою перекладу; кілька віршів дають діапазон, тексти з'єднано пробілом. | local-verifiable |
| FR-10 | MVP | Reference | Виділені вірші копіюються у форматі цитати через ⌘C і контекстне меню. | local-verifiable |

### 2.4 Пошук (`bible-search`)

| ID | Phase | Area | Description | Verification |
|---|---|---|---|---|
| FR-11 | MVP | Search | Пошук віршів з усіма словами запиту лише в активному перекладі, без урахування регістру; результати з посиланням і підсвіченим фрагментом, у порядку книг (до 200). | local-verifiable |
| FR-12 | MVP | Search | Спецсимволи FTS (`"`, `*`, `(`, `)`, `:`, `-`, `AND`…) трактуються як текст і не дають помилки; порожній запит дає порожній результат. | local-verifiable |
| FR-13 | MVP | Search | Якщо запит розбирається як посилання, відкривається це місце з віршем у фокусі замість текстового пошуку. | local-verifiable |
| FR-14 | MVP | Search | Клік по результату відкриває розділ із цим віршем у фокусі. | local-verifiable |

### 2.5 Роадмап (Future)

| ID | Phase | Area | Description | Verification |
|---|---|---|---|---|
| FR-15 | Future | Reading | Масштаб шрифту віршів і списку книг, ⌘+ / ⌘− / ⌘0, зберігається між запусками (PRD 6.1). | local-verifiable |
| FR-16 | Future | Reading | Загальний масштаб інтерфейсу в Settings, поважає системний розмір тексту (PRD 6.2). | local-verifiable |
| FR-17 | Future | Reference | Напівпрозора кнопка копіювання над виділенням, напис «Скопійовано» ~1,5 с (PRD 6.3). | local-verifiable |
| FR-18 | Future | Search | Морфологічний пошук (стемер en/ru) (PRD 6.4). | local-verifiable |
| FR-19 | Future | Search | Фільтр області пошуку: Біблія / СЗ / НЗ / поточна книга (PRD 6.5). | local-verifiable |
| FR-20 | Future | Search | Усі результати з лічильником «Знайдено: N» і довантаженням (PRD 6.6). | local-verifiable |
| FR-21 | Future | Search | Пошук точної фрази в лапках (PRD 6.7). | local-verifiable |
| FR-22 | Future | Notes | Закладки на вірш чи розділ (PRD 6.8). | local-verifiable |
| FR-23 | Future | Notes | Кольорова підсвітка віршів (PRD 6.9). | local-verifiable |
| FR-24 | Future | Notes | Нотатки до віршів з пошуком (PRD 6.10). | local-verifiable |
| FR-25 | Future | Reading | Відкриття на останньому місці читання (PRD 6.11). | local-verifiable |
| FR-26 | Future | Parallel | Два переклади поруч із синхронним прокручуванням (PRD 6.12). | local-verifiable |
| FR-27 | Future | Parallel | Таблиця відповідностей нумерації KJV ↔ Синодальний (PRD 6.13). | local-verifiable |
| FR-28 | Future | Import | Переклад Огієнка (PRD 6.14). | local-verifiable |
| FR-29 | Future | Import | Біблія Кралицька 1613 (PRD 6.15). | local-verifiable |
| FR-30 | Future | Import | Модулі перекладів: новий переклад без змін коду (PRD 6.16). | local-verifiable |

## 3 Non-Functional Requirements (NFR)

NFR з PRD §3 і §7 поки не мають автоматичного механізму перевірки, тому стоять
як `Future`: вони стануть MVP-рядками разом із слайсом, який додасть перевірку
(див. `check-acceptance-methods`).

| ID | Phase | Area | Description | Verification |
|---|---|---|---|---|
| NFR-1 | Future | Platform | macOS 14+, Apple Silicon та Intel. | local-verifiable |
| NFR-2 | Future | Privacy | Офлайн, жодних мережевих викликів і телеметрії. | local-verifiable |
| NFR-3 | Future | Performance | Запуск < 1 с; пошук < 200 мс на всій Біблії. | local-verifiable |
| NFR-4 | Future | A11y | VoiceOver читає номери й тексти віршів; повна робота з клавіатури; контраст WCAG AA. | local-verifiable |
| NFR-5 | Future | Size | Розмір додатка < 60 МБ з трьома перекладами. | local-verifiable |

## 4 Прогалини baseline

- **FR-10, FR-14:** тести покривають логіку `ReaderViewModel` (формування
  цитати, відкриття результату), але не SwiftUI-прив'язку (⌘C, контекстне
  меню, клік). UI перевіряли вручну; ручну перевірку 7.6 винесено в tech debt #7.
- **FR-2 (діакритика):** тест перевіряє кількість записів індексу, але не
  нечутливість до діакритики.
