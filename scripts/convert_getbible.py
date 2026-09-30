#!/usr/bin/env python3
"""Converts a translation into the data/raw format from two sources:
- getBible v2 (api.getbible.net/v2/<code>.json): {books: [{nr, chapters: [{chapter, verses}]}]};
- bolls.life (bolls.life/static/translations/<code>.zip): a flat list {book, chapter, verse, text}.

Books are sorted by number. A verse with number n
goes to position n-1; missing verses are empty strings (the import skips them, following
numbers are kept). Removes U+0301 stress marks, <…> tags and lone
curly braces; in BKR alternative words {word} become (word).
ASCII quotes become Ukrainian „…“, italics <i>…</i> become plain text.
With --align-to <data/raw file> the numbering is aligned verse by verse to another translation (KJV), see align_to.
Usage:
    python3 scripts/convert_getbible.py UBIO.json data/raw/uk_ohienko.json --align-to data/raw/en_kjv.json
    python3 scripts/convert_getbible.py bkr.json data/raw/cs_bkr.json
"""
import json
import re
import sys

# Control verses: (book, chapter, verse) → the start of the text after cleaning.
CHECKS = {
    "UBIO": {(1, 1, 1): "На початку Бог створив", (43, 3, 16): "Так бо Бог полюбив світ",
             (19, 3, 1): "Псалом Давидів", (19, 23, 1): "Псалом Давидів. Господь то мій Пастир"},
    "bkr": {(1, 1, 1): "Na počátku stvořil Bůh", (43, 3, 16): "Nebo tak Bůh miloval svět"},
}


# Allowed characters after cleaning; anything else stops the conversion, so new markup does not slip through silently.
ALLOWED_PUNCTUATION = set(" ,.;:!?-—–'’„“”«»()[]…")


def clean(text):
    text = text.replace("́", "")
    text = re.sub(r"<[^>]*>", "", text)
    text = re.sub(r"\{([^{}]*)\}", r"(\1)", text)
    text = text.replace("{", "").replace("}", "").replace("\\", "")
    # Ohienko uses „…“ quotes; sources contain ASCII ": before a word it opens, otherwise it closes.
    text = re.sub(r'(^|[\s(\[—–-])"', "\\1„", text)
    text = text.replace('"', "“")
    text = re.sub(r"\s+", " ", text).strip()
    odd = {c for c in text if not (c.isalpha() or c.isdigit() or c in ALLOWED_PUNCTUATION)}
    if odd:
        sys.exit(f"unexpected characters {sorted(odd)} in «{text[:60]}»")
    return text


def from_bolls(verses):
    """A flat bolls.life list → the getBible structure (chapters and verses by number)."""
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
        sys.exit("expected 66 books with nr 1..66")
    out = []
    for book in books:
        chapters = []
        for index, chapter in enumerate(book["chapters"]):
            if chapter["chapter"] != index + 1:
                sys.exit(f"{book['name']}: chapter {chapter['chapter']} at position {index + 1}")
            numbers = [v["verse"] for v in chapter["verses"]]
            if not numbers:
                chapters.append([])
                continue
            if len(set(numbers)) != len(numbers) or min(numbers) < 1:
                sys.exit(f"{book['name']} {chapter['chapter']}: duplicate or invalid verse numbers")
            texts = [""] * max(numbers)
            for verse in chapter["verses"]:
                texts[verse["verse"] - 1] = clean(verse["text"])
            chapters.append(texts)
        # Empty stub chapters at the end of a book (Ohienko: Esther 11–16, Ps 151) are dropped.
        while chapters and not chapters[-1]:
            chapters.pop()
        if not all(chapters):
            sys.exit(f"{book['name']}: an empty chapter in the middle of a book")
        out.append({"abbrev": str(book["nr"]), "name": book["name"], "chapters": chapters})
    return out


def align_to(books, reference):
    """Aligns verse numbering to `reference` (data/raw format) verse by verse.

    Known differences of the Hebrew numbering from KJV; anything else is an error:
    - Psalms: a superscription as a separate verse (1–2 verses) → merged into the first verse of the text, as in KJV;
    - 1 Sam 21:1 → the end of 1 Sam 20:42;
    - 3 John 1:14–15 → one verse 14.
    """
    for bi, (book, ref) in enumerate(zip(books, reference)):
        if len(book["chapters"]) != len(ref["chapters"]):
            sys.exit(f"book {bi + 1}: {len(book['chapters'])} chapters, the reference has {len(ref['chapters'])}")
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
                sys.exit(f"{bi + 1}:{ci + 1}: {len(verses)} verses, the reference has {len(ref_verses)}: an unknown difference")
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
            sys.exit(f"control verse {b}:{c}:{v}: «{text[:40]}» does not start with «{prefix}»")
    with open(dst, "w", encoding="utf-8") as f:
        json.dump(books, f, ensure_ascii=False, separators=(",", ":"))
    gaps = [f"{b['abbrev']}:{ci + 1}:{vi + 1}" for b in books
            for ci, c in enumerate(b["chapters"]) for vi, t in enumerate(c) if t == ""]
    total = sum(len(c) for b in books for c in b["chapters"])
    print(f"{dst}: 66 books, {total - len(gaps)} verses, {len(gaps)} missing")
    if gaps:
        print("missing (book:chapter:verse):", " ".join(gaps))


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
