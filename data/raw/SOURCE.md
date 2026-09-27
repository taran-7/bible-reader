# Джерела текстів

| Файл | Переклад | Джерело | Ліцензія репозиторію | Статус тексту |
|---|---|---|---|---|
| `en_kjv.json` | King James Version | [thiagobodruk/bible](https://github.com/thiagobodruk/bible) `json/en_kjv.json` | MIT | суспільне надбання |
| `ru_synodal.json` | Синодальний переклад | [scrollmapper/bible_databases](https://github.com/scrollmapper/bible_databases) `formats/json/RusSynodal.json` | MIT | суспільне надбання |
| `uk_ohienko.json` | Переклад Івана Огієнка (видання 1962) | [bolls.life](https://bolls.life/UBIO/1/1/) `UBIO`, файл `bolls.life/static/translations/UBIO.zip`, завантажено 2026-09-27 | — | ліцензію на bolls.life не вказано; **права не перевірено** (див. нижче) |
| `cs_bkr.json` | Bible kralická (1613) | [getBible](https://api.getbible.net/v2/bkr.json) `bkr`, `distribution_version` 1.5, завантажено 2026-09-27 | — | суспільне надбання |

Формат обох файлів: масив із 66 книг `{abbrev, name, chapters: [[вірш, …], …]}` у протестантському порядку (індекс + 1 = номер книги).

`ru_synodal.json` згенеровано `scripts/convert_synodal.py`: з 78 книг джерела взято 66 канонічних, порожні вірші (Пс 114:9) відкинуто. Кількість розділів збережено як у Синодальному (Дан 14, Пс 151).

Чому не `thiagobodruk/bible` `ru_synod.json`: у ньому немає Есфірі й Даниїла (64 книги).

`uk_ohienko.json` і `cs_bkr.json` згенеровано `scripts/convert_getbible.py` (`python3 scripts/convert_getbible.py UBIO.json data/raw/uk_ohienko.json --align-to data/raw/en_kjv.json`; тести конвертера — `scripts/test_convert_getbible.py`, запускаються з `make test`): книги за полем `nr`, без знаків наголосу U+0301 і тегів `<…>`, у BKR альтернативні слова `{…}` → `(…)`, відсутні вірші — порожні рядки (імпорт їх пропускає, номери зберігаються).

Відомі особливості:
- **Огієнко:** нумерація вирівняна з KJV вірш у вірш (`--align-to data/raw/en_kjv.json`), 31 102 вірші — стільки ж, скільки в KJV, у кожному розділі. У джерелі єврейська нумерація, тому конвертер: зливає надпис псалма (1–2 вірші, у 62 псалмах) з першим віршем тексту, як у KJV; приєднує 1 Сам 21:1 до 20:42; зливає 3 Ів 1:14–15 в один вірш 14. Будь-яка інша розбіжність зупиняє конвертацію. Лапки „…“ (ASCII `"` у джерелі перетворено), курсив `<i>…</i>` знято, квадратні дужки […] лишено як у джерелі.
- **Чому не getBible `ukrogienko`:** у ньому бракує 88 віршів (переважно надписів псалмів), книги не впорядковані, текст із наголосами.
- **Права на Огієнка:** getBible позначає текст Огієнка як Public Domain, bolls.life ліцензії не вказує, але Огієнко помер 1972 р., а в Україні строк охорони — 70 років після смерті автора. Перед розповсюдженням перевірити правовласника видання 1962 року (PRD §9, tech debt).
- **BKR:** нумерація KJV, 31 102 вірші.
