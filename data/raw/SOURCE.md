# Джерела текстів

| Файл | Переклад | Джерело | Ліцензія репозиторію | Статус тексту |
|---|---|---|---|---|
| `en_kjv.json` | King James Version | [thiagobodruk/bible](https://github.com/thiagobodruk/bible) `json/en_kjv.json` | MIT | суспільне надбання |
| `ru_synodal.json` | Синодальний переклад | [scrollmapper/bible_databases](https://github.com/scrollmapper/bible_databases) `formats/json/RusSynodal.json` | MIT | суспільне надбання |
| `uk_ohienko.json` | Переклад Івана Огієнка | [getBible](https://api.getbible.net/v2/ukrogienko.json) `ukrogienko`, `distribution_version` 3.1, завантажено 2026-09-27 | — | getBible: Public Domain; **права не перевірено** (див. нижче) |
| `cs_bkr.json` | Bible kralická (1613) | [getBible](https://api.getbible.net/v2/bkr.json) `bkr`, `distribution_version` 1.5, завантажено 2026-09-27 | — | суспільне надбання |

Формат обох файлів: масив із 66 книг `{abbrev, name, chapters: [[вірш, …], …]}` у протестантському порядку (індекс + 1 = номер книги).

`ru_synodal.json` згенеровано `scripts/convert_synodal.py`: з 78 книг джерела взято 66 канонічних, порожні вірші (Пс 114:9) відкинуто. Кількість розділів збережено як у Синодальному (Дан 14, Пс 151).

Чому не `thiagobodruk/bible` `ru_synod.json`: у ньому немає Есфірі й Даниїла (64 книги).

`uk_ohienko.json` і `cs_bkr.json` згенеровано `scripts/convert_getbible.py` (`python3 scripts/convert_getbible.py ukrogienko.json data/raw/uk_ohienko.json`): книги за полем `nr`, без знаків наголосу U+0301 і тегів `<…>`, у BKR альтернативні слова `{…}` → `(…)`, відсутні вірші — порожні рядки (імпорт їх пропускає, номери зберігаються).

Відомі особливості:
- **Огієнко:** нумерація як у Синодальному (Пс 151 розділ без заглушки, Йоіл 4); у джерелі бракує 88 віршів, переважно надписів псалмів (вірш 1); порожні розділи-заглушки Естер 11–16 і Пс 151 відкинуто.
- **Права на Огієнка:** getBible позначає текст як Public Domain, але Огієнко помер 1972 р., а в Україні строк охорони — 70 років після смерті автора. Перед розповсюдженням перевірити видання (1930 чи 1962) і правовласника (PRD §9, tech debt).
- **BKR:** нумерація KJV, 31 102 вірші.
