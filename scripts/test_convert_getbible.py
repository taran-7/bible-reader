#!/usr/bin/env python3
"""getBible converter tests: python3 scripts/test_convert_getbible.py"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(__file__))
from convert_getbible import align_to, clean, convert, from_bolls  # noqa: E402


def book(nr, chapters):
    return {"nr": nr, "name": f"B{nr}", "chapters": chapters}


def chapter(n, verses):
    return {"chapter": n, "verses": [{"verse": v, "text": t} for v, t in verses]}


class ConvertTests(unittest.TestCase):
    def source(self, **overrides):
        books = [book(nr, [chapter(1, [(1, "a")])]) for nr in range(1, 67)]
        for nr, chapters in overrides.items():
            books[int(nr[1:]) - 1] = book(int(nr[1:]), chapters)
        return {"books": list(reversed(books))}

    def test_orders_by_nr(self):
        out = convert(self.source())
        self.assertEqual([b["abbrev"] for b in out], [str(n) for n in range(1, 67)])

    def test_fills_gaps_with_empty_strings(self):
        out = convert(self.source(b19=[chapter(1, [(2, "друге"), (4, "четверте")])]))
        self.assertEqual(out[18]["chapters"][0], ["", "друге", "", "четверте"])

    def test_drops_trailing_empty_chapters(self):
        out = convert(self.source(b17=[chapter(1, [(1, "a")]), chapter(2, [])]))
        self.assertEqual(len(out[16]["chapters"]), 1)

    def test_empty_chapter_in_the_middle_fails(self):
        with self.assertRaises(SystemExit):
            convert(self.source(b17=[chapter(1, []), chapter(2, [(1, "a")])]))

    def test_clean(self):
        self.assertEqual(clean("поча́тку"), "початку")
        self.assertEqual(clean("<title x='1'>Псалом</title> Давидів"), "Псалом Давидів")
        self.assertEqual(clean("kněží {biskupy} a"), "kněží (biskupy) a")
        self.assertEqual(clean("і { сказав"), "і сказав")
        self.assertEqual(clean("яспіс. \\"), "яспіс.")
        self.assertEqual(clean("„ви боги\"?"), "„ви боги“?")

    def test_bolls_flat_list(self):
        # A flat verse list in arbitrary order → books 1..66, chapters and verses by number.
        verses = [{"book": nr, "chapter": 1, "verse": 1, "text": "a"} for nr in range(66, 0, -1)]
        verses += [{"book": 19, "chapter": 2, "verse": 2, "text": "Господи"},
                   {"book": 19, "chapter": 2, "verse": 1, "text": "Псалом Давидів."}]
        out = convert(from_bolls(verses))
        self.assertEqual([b["abbrev"] for b in out], [str(n) for n in range(1, 67)])
        self.assertEqual(out[18]["chapters"], [["a"], ["Псалом Давидів.", "Господи"]])

    def test_align_to_kjv(self):
        books = [{"abbrev": str(n), "name": str(n), "chapters": [["a"]]} for n in range(1, 67)]
        reference = [{"chapters": [["x"]]} for _ in range(66)]
        # Ps 1: a superscription in two verses → merged into the first verse of the text.
        books[18]["chapters"] = [["Надпис.", "Продовження надпису.", "Перший.", "Другий."]]
        reference[18]["chapters"] = [["1", "2"]]
        # 1 Sam 20–21: 21:1 is the end of chapter 20.
        books[8]["chapters"] = [["a"]] * 19 + [["20:1", "20:2"], ["хвіст", "21:1"]]
        reference[8]["chapters"] = [["x"]] * 19 + [["1", "2"], ["1"]]
        # 3 John: the last two verses are one in KJV.
        books[63]["chapters"] = [["1", "14", "15"]]
        reference[63]["chapters"] = [["1", "14"]]
        out = align_to(books, reference)
        self.assertEqual(out[18]["chapters"][0], ["Надпис. Продовження надпису. Перший.", "Другий."])
        self.assertEqual(out[8]["chapters"][19], ["20:1", "20:2 хвіст"])
        self.assertEqual(out[8]["chapters"][20], ["21:1"])
        self.assertEqual(out[63]["chapters"][0], ["1", "14 15"])

    def test_align_rejects_unknown_mismatch(self):
        books = [{"abbrev": str(n), "name": str(n), "chapters": [["a", "b"]]} for n in range(1, 67)]
        reference = [{"chapters": [["x"]]} for _ in range(66)]
        with self.assertRaises(SystemExit):
            align_to(books, reference)

    def test_ascii_quotes_become_ukrainian(self):
        self.assertEqual(clean('"Я мандрував по землі."'), "„Я мандрував по землі.“")
        self.assertEqual(clean('спів: „На смерть сина". Псалом'), "спів: „На смерть сина“. Псалом")
        self.assertEqual(clean("відрочив їм <i>справу</i>, говорячи"), "відрочив їм справу, говорячи")

    def test_rejects_unexpected_characters(self):
        with self.assertRaises(SystemExit):
            clean("текст | з трубою")


if __name__ == "__main__":
    unittest.main()
