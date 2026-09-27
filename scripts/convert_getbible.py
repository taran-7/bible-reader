#!/usr/bin/env python3
"""Конвертує переклад getBible v2 (api.getbible.net/v2/<код>.json) у формат data/raw.

Книги сортуються за полем nr (в Огієнка масив не впорядкований). Вірш з номером n
стає на позицію n-1; відсутні вірші — порожні рядки (імпорт їх пропускає, номери
наступних зберігаються). Прибирає знаки наголосу U+0301, теги <…> і одиночні
фігурні дужки; у BKR альтернативні слова {слово} стають (слово).
Використання:
    python3 scripts/convert_getbible.py ukrogienko.json data/raw/uk_ohienko.json
    python3 scripts/convert_getbible.py bkr.json data/raw/cs_bkr.json
"""
import json
import re
import sys

# Контрольні вірші: (книга, розділ, вірш) → початок тексту після очищення.
CHECKS = {
    "ukrogienko": {(1, 1, 1): "На початку Бог створив", (43, 3, 16): "Так бо Бог полюбив світ"},
    "bkr": {(1, 1, 1): "Na počátku stvořil Bůh", (43, 3, 16): "Nebo tak Bůh miloval svět"},
}


# Дозволені символи після очищення; будь-що інше зупиняє конвертацію, щоб нова розмітка не пройшла тихо.
ALLOWED_PUNCTUATION = set(" ,.;:!?-—–'’„“”«»()[]…")


def clean(text):
    text = text.replace("́", "")
    text = re.sub(r"<[^>]*>", "", text)
    text = re.sub(r"\{([^{}]*)\}", r"(\1)", text)
    text = text.replace("{", "").replace("}", "").replace("\\", "")
    # В Огієнка лапки „…“; зрідка закривна — ASCII ".
    text = text.replace('"', "“")
    text = re.sub(r"\s+", " ", text).strip()
    odd = {c for c in text if not (c.isalpha() or c.isdigit() or c in ALLOWED_PUNCTUATION)}
    if odd:
        sys.exit(f"неочікувані символи {sorted(odd)} у «{text[:60]}»")
    return text


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


def main(src, dst):
    source = json.load(open(src, encoding="utf-8"))
    books = convert(source)
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
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
