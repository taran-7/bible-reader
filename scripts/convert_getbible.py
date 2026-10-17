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
With --nt the source is a New Testament only (books 40..66) and the result has 27 books (the local Popchenko module).
With --fixes <json> whole verses are replaced (or added) before cleaning: {"book:chapter:verse": "text"}.
Usage:
    python3 scripts/convert_getbible.py UBIO.json data/raw/uk_ohienko.json --align-to data/raw/en_kjv.json
    python3 scripts/convert_getbible.py bkr.json data/raw/cs_bkr.json
    python3 scripts/convert_getbible.py PPCH.json data/raw/uk_popchenko.json --nt --align-to data/raw/en_kjv.json \\
        --fixes scripts/ppch_print_fixes.json
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


def load_fixes(path):
    """{"book:chapter:verse": "text"} → {(book, chapter, verse): "text"}."""
    fixes = {}
    for key, text in json.load(open(path, encoding="utf-8")).items():
        book, chapter, verse = (int(n) for n in key.split(":"))
        fixes[(book, chapter, verse)] = text
    return fixes


def convert(source, first_book=1, overrides=None):
    """`first_book` 40 means a New Testament source (books 40..66). `overrides` replace or add whole verses."""
    overrides = overrides or {}
    books = sorted(source["books"], key=lambda b: b["nr"])
    if [b["nr"] for b in books] != list(range(first_book, 67)):
        sys.exit(f"expected {67 - first_book} books with nr {first_book}..66")
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
            fixed = {n: t for (b, c, n), t in overrides.items() if (b, c) == (book["nr"], chapter["chapter"])}
            texts = [""] * max(numbers + list(fixed))
            for verse in chapter["verses"]:
                if verse["verse"] not in fixed:
                    texts[verse["verse"] - 1] = clean(verse["text"])
            for number, text in fixed.items():
                texts[number - 1] = clean(text)
            chapters.append(texts)
        # Empty stub chapters at the end of a book (Ohienko: Esther 11–16, Ps 151) are dropped.
        while chapters and not chapters[-1]:
            chapters.pop()
        if not all(chapters):
            sys.exit(f"{book['name']}: an empty chapter in the middle of a book")
        out.append({"abbrev": str(book["nr"]), "name": book["name"], "chapters": chapters})
    return out


def align_to(books, reference, first_book=1):
    """Aligns verse numbering to `reference` (data/raw format) verse by verse.
    With `first_book` 40 the books are a New Testament and are compared with the same books of the reference.

    Known differences of the Hebrew numbering from KJV; anything else is an error:
    - Psalms: a superscription as a separate verse (1–2 verses) → merged into the first verse of the text, as in KJV;
    - 1 Sam 21:1 → the end of 1 Sam 20:42;
    - 3 John 1:14–15 → one verse 14.
    """
    reference = reference[first_book - 1:]
    for index, (book, ref) in enumerate(zip(books, reference)):
        bi = index + first_book - 1
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


def check_complete(books, first_book=1):
    """After the fixes no verse may be empty and no `^` typo mark may remain (a defect in the source we did not fix)."""
    for index, book in enumerate(books):
        for ci, chapter in enumerate(book["chapters"]):
            for vi, text in enumerate(chapter):
                where = f"{first_book + index}:{ci + 1}:{vi + 1}"
                if text == "":
                    sys.exit(f"{where}: the verse is missing in the source; add it to the fixes file from the printed edition")
                if "^" in text:
                    sys.exit(f"{where}: a typo mark ^ in the source; add the verse to the fixes file from the printed edition")


def main(src, dst, align=None, first_book=1, fixes=None):
    source = json.load(open(src, encoding="utf-8"))
    if isinstance(source, list):
        source = from_bolls(source)
    books = convert(source, first_book, load_fixes(fixes) if fixes else None)
    if align:
        books = align_to(books, json.load(open(align, encoding="utf-8-sig")), first_book)
    if first_book > 1:
        check_complete(books, first_book)
    code = source.get("abbreviation", "")
    for (b, c, v), prefix in CHECKS.get(code, {}).items():
        text = books[b - first_book]["chapters"][c - 1][v - 1]
        if not text.startswith(prefix):
            sys.exit(f"control verse {b}:{c}:{v}: «{text[:40]}» does not start with «{prefix}»")
    with open(dst, "w", encoding="utf-8") as f:
        json.dump(books, f, ensure_ascii=False, separators=(",", ":"))
    gaps = [f"{b['abbrev']}:{ci + 1}:{vi + 1}" for b in books
            for ci, c in enumerate(b["chapters"]) for vi, t in enumerate(c) if t == ""]
    total = sum(len(c) for b in books for c in b["chapters"])
    print(f"{dst}: {len(books)} books, {total - len(gaps)} verses, {len(gaps)} missing")
    if gaps:
        print("missing (book:chapter:verse):", " ".join(gaps))


if __name__ == "__main__":
    args = sys.argv[1:]
    align = None
    if "--align-to" in args:
        i = args.index("--align-to")
        align = args[i + 1]
        del args[i:i + 2]
    fixes = None
    if "--fixes" in args:
        i = args.index("--fixes")
        fixes = args[i + 1]
        del args[i:i + 2]
    first_book = 1
    if "--nt" in args:
        args.remove("--nt")
        first_book = 40
    if len(args) != 2:
        sys.exit(__doc__)
    main(args[0], args[1], align, first_book, fixes)
