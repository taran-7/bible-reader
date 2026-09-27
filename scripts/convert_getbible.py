#!/usr/bin/env python3
"""Конвертує переклад у формат data/raw з двох джерел:
- getBible v2 (api.getbible.net/v2/<код>.json): {books: [{nr, chapters: [{chapter, verses}]}]};
- bolls.life (bolls.life/static/translations/<код>.zip): плаский список {book, chapter, verse, text}.

Книги сортуються за номером. Вірш з номером n
стає на позицію n-1; відсутні вірші — порожні рядки (імпорт їх пропускає, номери
наступних зберігаються). Прибирає знаки наголосу U+0301, теги <…> і одиночні
фігурні дужки; у BKR альтернативні слова {слово} стають (слово).
ASCII-лапки стають українськими „…“, курсив <i>…</i> — звичайним текстом.
З --align-to <файл data/raw> нумерація вирівнюється вірш у вірш за іншим перекладом (KJV), див. align_to.
Використання:
    python3 scripts/convert_getbible.py UBIO.json data/raw/uk_ohienko.json --align-to data/raw/en_kjv.json
    python3 scripts/convert_getbible.py bkr.json data/raw/cs_bkr.json
"""
import json
import re
import sys

# Контрольні вірші: (книга, розділ, вірш) → початок тексту після очищення.
CHECKS = {
    "UBIO": {(1, 1, 1): "На початку Бог створив", (43, 3, 16): "Так бо Бог полюбив світ",
             (19, 3, 1): "Псалом Давидів", (19, 23, 1): "Псалом Давидів. Господь то мій Пастир"},
    "bkr": {(1, 1, 1): "Na počátku stvořil Bůh", (43, 3, 16): "Nebo tak Bůh miloval svět"},
}


# Дозволені символи після очищення; будь-що інше зупиняє конвертацію, щоб нова розмітка не пройшла тихо.
ALLOWED_PUNCTUATION = set(" ,.;:!?-—–'’„“”«»()[]…")


def clean(text):
    text = text.replace("́", "")
    text = re.sub(r"<[^>]*>", "", text)
    text = re.sub(r"\{([^{}]*)\}", r"(\1)", text)
    text = text.replace("{", "").replace("}", "").replace("\\", "")
    # В Огієнка лапки „…“; у джерелах трапляються ASCII ": перед словом — відкривна, інакше закривна.
    text = re.sub(r'(^|[\s(\[—–-])"', "\\1„", text)
    text = text.replace('"', "“")
    text = re.sub(r"\s+", " ", text).strip()
    odd = {c for c in text if not (c.isalpha() or c.isdigit() or c in ALLOWED_PUNCTUATION)}
    if odd:
        sys.exit(f"неочікувані символи {sorted(odd)} у «{text[:60]}»")
    return text


def from_bolls(verses):
    """Плаский список bolls.life → структура getBible (розділи й вірші за номерами)."""
    books = {}
    for v in verses:
        books.setdefault(v["book"], {}).setdefault(v["chapter"], []).append(v)
    return {
        "abbreviation": verses[0].get("translation", "") if verses else "",
        "books": [
            {"nr": nr, "name": str(nr),
             "chapters": [{"chapter": c, "verses": chapters[c]} for c in sorted(chapters)]}
            for nr, chapters in books.items()
        ],
    }


def convert(source):
    books = sorted(source["books"], key=lambda b: b["nr"])
    if [b["nr"] for b in books] != list(range(1, 67)):
        sys.exit("очікувалось 66 книг з nr 1..66")
    out = []
    for book in books:
        chapters = []
        for index, chapter in enumerate(book["chapters"]):
            if chapter["chapter"] != index + 1:
                sys.exit(f"{book['name']}: розділ {chapter['chapter']} на позиції {index + 1}")
            numbers = [v["verse"] for v in chapter["verses"]]
            if not numbers:
                chapters.append([])
                continue
            if len(set(numbers)) != len(numbers) or min(numbers) < 1:
                sys.exit(f"{book['name']} {chapter['chapter']}: дублікати або некоректні номери віршів")
            texts = [""] * max(numbers)
            for verse in chapter["verses"]:
                texts[verse["verse"] - 1] = clean(verse["text"])
            chapters.append(texts)
        # Порожні розділи-заглушки в кінці книги (Огієнко: Естер 11–16, Пс 151) відкидаємо.
        while chapters and not chapters[-1]:
            chapters.pop()
        if not all(chapters):
            sys.exit(f"{book['name']}: порожній розділ посередині книги")
        out.append({"abbrev": str(book["nr"]), "name": book["name"], "chapters": chapters})
    return out


def align_to(books, reference):
    """Вирівнює нумерацію віршів за `reference` (формат data/raw) вірш у вірш.

    Відомі розбіжності єврейської нумерації з KJV, решта — помилка:
    - Псалми: надпис окремим віршем (1–2 вірші) → зливається з першим віршем тексту, як у KJV;
    - 1 Сам 21:1 → кінець 1 Сам 20:42;
    - 3 Ів 1:14–15 → один вірш 14.
    """
    for bi, (book, ref) in enumerate(zip(books, reference)):
        if len(book["chapters"]) != len(ref["chapters"]):
            sys.exit(f"книга {bi + 1}: {len(book['chapters'])} розділів, у зразку {len(ref['chapters'])}")
        for ci, (verses, ref_verses) in enumerate(zip(book["chapters"], ref["chapters"])):
            extra = len(verses) - len(ref_verses)
            if extra == 0:
                continue
            if bi + 1 == 19 and extra in (1, 2):
                verses = [" ".join(verses[:extra + 1])] + verses[extra + 1:]
            elif (bi + 1, ci + 1) == (9, 21) and extra == 1:
                previous = book["chapters"][ci - 1]
                previous[-1] = f"{previous[-1]} {verses[0]}"
                verses = verses[1:]
            elif (bi + 1, ci + 1) == (64, 1) and extra == 1:
                verses = verses[:-2] + [f"{verses[-2]} {verses[-1]}"]
            else:
                sys.exit(f"{bi + 1}:{ci + 1}: {len(verses)} віршів, у зразку {len(ref_verses)} — невідома розбіжність")
            book["chapters"][ci] = verses
    return books


def main(src, dst, align=None):
    source = json.load(open(src, encoding="utf-8"))
    if isinstance(source, list):
        source = from_bolls(source)
    books = convert(source)
    if align:
        books = align_to(books, json.load(open(align, encoding="utf-8-sig")))
    code = source.get("abbreviation", "")
    for (b, c, v), prefix in CHECKS.get(code, {}).items():
        text = books[b - 1]["chapters"][c - 1][v - 1]
        if not text.startswith(prefix):
            sys.exit(f"контрольний вірш {b}:{c}:{v}: «{text[:40]}» не починається з «{prefix}»")
    with open(dst, "w", encoding="utf-8") as f:
        json.dump(books, f, ensure_ascii=False, separators=(",", ":"))
    gaps = [f"{b['abbrev']}:{ci + 1}:{vi + 1}" for b in books
            for ci, c in enumerate(b["chapters"]) for vi, t in enumerate(c) if t == ""]
    total = sum(len(c) for b in books for c in b["chapters"])
    print(f"{dst}: 66 книг, {total - len(gaps)} віршів, пропущено {len(gaps)}")
    if gaps:
        print("пропущені (книга:розділ:вірш):", " ".join(gaps))


if __name__ == "__main__":
    args = sys.argv[1:]
    align = None
    if "--align-to" in args:
        i = args.index("--align-to")
        align = args[i + 1]
        del args[i:i + 2]
    if len(args) != 2:
        sys.exit(__doc__)
    main(args[0], args[1], align)
