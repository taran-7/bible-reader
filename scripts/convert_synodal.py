#!/usr/bin/env python3
"""Converts RusSynodal.json (scrollmapper/bible_databases) into the thiagobodruk format.

Takes the 66 canonical books in Protestant order, drops non-canonical
books and empty verses, and drops the long Greek (Septuagint) additions that the
Synodal prints in square brackets and that KJV, based on the Hebrew text, does not have. Usage:
    python3 scripts/convert_synodal.py RusSynodal.json data/raw/ru_synodal.json
    python3 scripts/convert_synodal.py --strip-converted data/raw/ru_synodal.json   # the same removal for a converted file
"""
import json
import re
import sys

CANON = [
    "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua", "Judges", "Ruth",
    "I Samuel", "II Samuel", "I Kings", "II Kings", "I Chronicles", "II Chronicles",
    "Ezra", "Nehemiah", "Esther", "Job", "Psalms", "Proverbs", "Ecclesiastes",
    "Song of Solomon", "Isaiah", "Jeremiah", "Lamentations", "Ezekiel", "Daniel",
    "Hosea", "Joel", "Amos", "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk",
    "Zephaniah", "Haggai", "Zechariah", "Malachi",
    "Matthew", "Mark", "Luke", "John", "Acts", "Romans", "I Corinthians",
    "II Corinthians", "Galatians", "Ephesians", "Philippians", "Colossians",
    "I Thessalonians", "II Thessalonians", "I Timothy", "II Timothy", "Titus",
    "Philemon", "Hebrews", "James", "I Peter", "II Peter", "I John", "II John",
    "III John", "Jude", "Revelation of John",
]

OLD_TESTAMENT = 39
ESTHER = 17
# A bracketed insertion this long (brackets included) is a passage from the Greek text; shorter ones are words the
# Septuagint adds or the translators supply, and they stay (owner decision 2026-10-17).
LONG_INSERTION = 100
# (book, chapter, verse): long brackets that are Hebrew text the Septuagint lacks; they are in KJV, so they stay.
HEBREW_IN_BRACKETS = {(5, 21, 5), (12, 7, 13)}
# (book, chapter): first verse of a block that is one Greek addition to the end of the chapter (Josh 24:34-36, Prov 4:28-29).
# Other multi-verse brackets (Judges 20:27-28, Ps 67:23-24) are Hebrew text; Dan 3:24-90 sits mid-chapter, so it stays
# until the numbering mapping to KJV can follow.
TRAILING_ADDITIONS = {(6, 24): 34, (20, 4): 28}
BRACKETED = re.compile(r"\[[^\[\]]*\]")


def strip_additions(book, chapter, verse, text):
    """The text of a verse without its Greek additions: all bracketed ones in Esther, long ones elsewhere in the Old Testament."""
    if book > OLD_TESTAMENT or "[" not in text:
        return text
    keep_long = (book, chapter, verse) in HEBREW_IN_BRACKETS

    def removal(match):
        removed = book == ESTHER or (len(match.group()) >= LONG_INSERTION and not keep_long)
        return "" if removed else match.group()

    result = BRACKETED.sub(removal, text)
    if result == text:
        return text
    result = re.sub(r"[ \t]{2,}", " ", result)
    result = re.sub(r"\s+([,.;:!?»”])", r"\1", result)
    # A comma or colon left before the sentence end by the removed insertion: "в дом, [...]." -> "в дом."
    return re.sub(r"[,;:]+([.!?»”])", r"\1", result).strip()


def drop_trailing_additions(book, chapter, texts):
    """Drops the verses at the end of a chapter that are one bracketed Greek addition; stops if the source looks different."""
    first = TRAILING_ADDITIONS.get((book, chapter))
    if first is None:
        return texts
    if len(texts) < first or not texts[first - 1].startswith("[") or not texts[-1].endswith("]"):
        sys.exit(f"book {book} chapter {chapter}: verses {first}-{len(texts)} are not one bracketed addition")
    return texts[:first - 1]


def clean_chapter(name, number, chapter_number, texts):
    """The verses of a chapter without Greek additions; empty ones are allowed only at the end.

    The import numbers verses by position, so an empty verse in the middle would shift the numbers.
    """
    texts = drop_trailing_additions(number, chapter_number, texts)
    texts = [strip_additions(number, chapter_number, verse, text) for verse, text in enumerate(texts, start=1)]
    while texts and not texts[-1]:
        texts.pop()
    if not all(texts):
        sys.exit(f"{name} {chapter_number}: an empty verse in the middle of a chapter")
    return texts


def verses_of(book, chapter, number):
    texts = [v["text"].strip() for v in chapter["verses"]]
    if [v["verse"] for v in chapter["verses"]] != list(range(1, len(texts) + 1)):
        sys.exit(f"{book} {chapter['chapter']}: verse numbers are not 1..N")
    return clean_chapter(book, number, chapter["chapter"], texts)


def main(src, dst):
    books = {b["name"]: b for b in json.load(open(src, encoding="utf-8-sig"))["books"]}
    out = []
    for number, name in enumerate(CANON, start=1):
        chapters = [verses_of(name, ch, number) for ch in books[name]["chapters"]]
        out.append({"abbrev": str(number), "name": name, "chapters": chapters})
    with open(dst, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False)


def strip_converted(path):
    """The same removal of Greek additions for an already converted file (verses are numbered by position), in place."""
    with open(path, encoding="utf-8") as f:
        books = json.load(f)
    for number, book in enumerate(books, start=1):
        book["chapters"] = [clean_chapter(book["name"], number, chapter_number, texts)
                            for chapter_number, texts in enumerate(book["chapters"], start=1)]
    with open(path, "w", encoding="utf-8") as f:
        json.dump(books, f, ensure_ascii=False)


if __name__ == "__main__":
    if sys.argv[1] == "--strip-converted":
        strip_converted(sys.argv[2])
    else:
        main(sys.argv[1], sys.argv[2])
