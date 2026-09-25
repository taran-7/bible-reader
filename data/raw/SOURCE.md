# Джерела текстів

| Файл | Переклад | Джерело | Ліцензія репозиторію | Статус тексту |
|---|---|---|---|---|
| `en_kjv.json` | King James Version | [thiagobodruk/bible](https://github.com/thiagobodruk/bible) `json/en_kjv.json` | MIT | суспільне надбання |
| `ru_synodal.json` | Синодальний переклад | [scrollmapper/bible_databases](https://github.com/scrollmapper/bible_databases) `formats/json/RusSynodal.json` | MIT | суспільне надбання |

Формат обох файлів: масив із 66 книг `{abbrev, name, chapters: [[вірш, …], …]}` у протестантському порядку (індекс + 1 = номер книги).

`ru_synodal.json` згенеровано `scripts/convert_synodal.py`: з 78 книг джерела взято 66 канонічних, порожні вірші (Пс 114:9) відкинуто. Кількість розділів збережено як у Синодальному (Дан 14, Пс 151).

Чому не `thiagobodruk/bible` `ru_synod.json`: у ньому немає Есфірі й Даниїла (64 книги).
