## Рішення

### Потік
`ChapterView` → `ReaderViewModel.illustrationRequest(for:)` (посилання мовою екрана + текст KJV тих самих віршів через `canonicalKeys`) → вікно `IllustrationsView` → `IllustrationSearch` (actor).

### Запити
`IllustrationQuery`: слова ≥ 4 літер без службових (KJV-архаїзми теж), частіші першими; запити від вужчого до ширшого: 3 слова, 2, кожне окремо (WordPress шукає всі слова разом).

### Джерела (`IllustrationProvider`)
- `WordPressAdapter`: `/wp-json/wp/v2/search` (лише `post`), текст — `/wp-json/wp/v2/posts/<id>` з `_links.self` того самого хоста; зайва сторінка → 400 → кінець. Початок ≤ 1500 символів по межі абзацу/речення.
- `WikipediaAdapter`: `generator=search` + `extracts|categories|info` одним запитом; до запиту додаються підказки (missionary, evangelist, …); лишаються статті з категорією «… births/deaths» і без слів catholic/orthodox/pope/saint/… у категоріях.
- `BraveAdapter`: `q = <запит> (site:a OR site:b …)` по allowlist без Вікіпедії; заголовок, уривок, посилання; 401/403/429 — зрозумілі помилки.

### Курсор
(запит, джерело, сторінка). `next()` тягне сторінки, доки не набере 7 або курсор не вичерпається; дублікати — за адресою і нормалізованим заголовком; усе поза allowlist відкидається. `hasMore` керує «Отримати ще».

### Помилки
`IllustrationNetwork` перетворює `URLError` без мережі (notConnected, DNS, timeout…) на `.offline`, решту — на `.failed(текст)`.

### Ризики
- Шум у результатах: без моделі немає перевірки «реальні люди, місце, час», крім біографій Вікіпедії.
- Адаптери ламаються зі зміною API сайтів; тести на фікстурах цього не ловлять (моніторинг — поза слайсом).
