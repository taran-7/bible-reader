#!/usr/bin/env python3
"""Конвертує RusSynodal.json (scrollmapper/bible_databases) у формат thiagobodruk.

Бере 66 канонічних книг у протестантському порядку, відкидає неканонічні
книги і порожні вірші. Використання:
    python3 scripts/convert_synodal.py RusSynodal.json data/raw/ru_synodal.json
"""
import json
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


def verses_of(book, chapter):
    """Тексти віршів розділу; порожні дозволені лише в кінці.

    Імпорт нумерує вірші за позицією, тож порожній вірш посередині зсунув би номери.
    """
    texts = [v["text"].strip() for v in chapter["verses"]]
    if [v["verse"] for v in chapter["verses"]] != list(range(1, len(texts) + 1)):
        sys.exit(f"{book} {chapter['chapter']}: номери віршів не 1..N")
    while texts and not texts[-1]:
        texts.pop()
    if not all(texts):
        sys.exit(f"{book} {chapter['chapter']}: порожній вірш посередині розділу")
    return texts


def main(src, dst):
    books = {b["name"]: b for b in json.load(open(src, encoding="utf-8-sig"))["books"]}
    out = []
    for number, name in enumerate(CANON, start=1):
        chapters = [verses_of(name, ch) for ch in books[name]["chapters"]]
        out.append({"abbrev": str(number), "name": name, "chapters": chapters})
    with open(dst, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
