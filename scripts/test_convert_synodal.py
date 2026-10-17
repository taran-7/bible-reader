#!/usr/bin/env python3
"""Synodal converter tests: python3 scripts/test_convert_synodal.py"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(__file__))
from convert_synodal import drop_trailing_additions, strip_additions, strip_converted  # noqa: E402

LONG = "Каинана. По рождении Каинана Арфаксад жил триста тридцать лет и родил сынов и дочерей и умер. Каинан жил сто тридцать лет, и родил"
JOSHUA, ESTHER, DEUTERONOMY, KINGS2, MATTHEW = 6, 17, 5, 12, 40


class StripAdditionsTests(unittest.TestCase):
    def test_removes_a_long_septuagint_insertion_and_closes_the_gap(self):
        text = f"Арфаксад жил тридцать пять лет и родил [{LONG}] Салу."
        self.assertEqual(strip_additions(1, 11, 12, text), "Арфаксад жил тридцать пять лет и родил Салу.")

    def test_keeps_short_brackets(self):
        # Words the Septuagint adds or the translators supply are short; they stay.
        text = "Имя второй реки Гихон [Геон]: она обтекает всю землю Куш."
        self.assertEqual(strip_additions(1, 2, 13, text), text)

    def test_keeps_a_long_bracket_that_is_hebrew_text(self):
        # Deut 21:5 and 2 Kings 7:13 are in the Hebrew and in KJV; the brackets only say the Septuagint lacks them.
        text = "и придут священники, сыны Левиины [" + "ибо их избрал Господь Бог твой служить Ему и благословлять именем Господа, и по слову их " * 2 + "]"
        self.assertEqual(strip_additions(DEUTERONOMY, 21, 5, text), text)
        self.assertEqual(strip_additions(KINGS2, 7, 13, text), text)

    def test_esther_loses_every_bracketed_addition_even_a_short_one(self):
        text = "На третий день Есфирь [перестав молиться, сняла одежды сетования и] оделась по-царски, [и сделавшись великолепною] взяла служанок."
        self.assertEqual(strip_additions(ESTHER, 5, 1, text), "На третий день Есфирь оделась по-царски, взяла служанок.")

    def test_punctuation_after_a_removed_insertion_has_no_space_before_it(self):
        text = f"Он родил [{LONG}] , и умер."
        self.assertEqual(strip_additions(1, 11, 12, text), "Он родил, и умер.")

    def test_a_comma_before_the_sentence_end_is_dropped_with_the_insertion(self):
        text = f"против входа в дом, [{LONG}]. Когда царь увидел царицу."
        self.assertEqual(strip_additions(ESTHER, 5, 1, text), "против входа в дом. Когда царь увидел царицу.")

    def test_new_testament_is_untouched(self):
        text = "и не знал Ее. [Как] наконец Она родила Сына [" + "x" * 120 + "]"
        self.assertEqual(strip_additions(MATTHEW, 1, 25, text), text)

    def test_a_verse_without_brackets_is_returned_as_is(self):
        self.assertEqual(strip_additions(1, 1, 1, "В начале  сотворил Бог небо и землю."), "В начале  сотворил Бог небо и землю.")

    def test_a_verse_made_only_of_an_addition_becomes_empty(self):
        self.assertEqual(strip_additions(ESTHER, 4, 17, "[И молился он Господу]"), "")


class TrailingAdditionsTests(unittest.TestCase):
    def joshua24(self):
        verses = [f"стих {n}" for n in range(1, 34)]
        return verses + ["[В тот день взяв ковчег", "И сыны пошли", "И стали служить Астарте.]"]

    def test_drops_the_bracketed_verses_at_the_end_of_a_chapter(self):
        self.assertEqual(drop_trailing_additions(JOSHUA, 24, self.joshua24()), [f"стих {n}" for n in range(1, 34)])

    def test_other_chapters_are_untouched(self):
        verses = ["a", "b", "c"]
        self.assertEqual(drop_trailing_additions(JOSHUA, 23, verses), verses)

    def test_unexpected_shape_stops_the_conversion(self):
        # If the source changes (the block does not open or close with a bracket), nothing is silently dropped.
        broken = self.joshua24()
        broken[33] = "В тот день без скобки"
        with self.assertRaises(SystemExit):
            drop_trailing_additions(JOSHUA, 24, broken)
        with self.assertRaises(SystemExit):
            drop_trailing_additions(JOSHUA, 24, ["short"])


class ConvertedFileTests(unittest.TestCase):
    def test_strips_a_converted_file_in_place_and_is_idempotent(self):
        import json
        import tempfile
        books = [{"abbrev": str(n), "name": f"B{n}", "chapters": [["a [b] c"]]} for n in range(1, 67)]
        books[ESTHER - 1]["chapters"] = [["Первый [вставка] стих", "второй"], ["[только вставка]"]]
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as f:
            json.dump(books, f, ensure_ascii=False)
        for _ in range(2):
            strip_converted(f.name)
            with open(f.name, encoding="utf-8") as g:
                out = json.load(g)
            self.assertEqual(out[ESTHER - 1]["chapters"], [["Первый стих", "второй"], []])
            self.assertEqual(out[0]["chapters"], [["a [b] c"]], "short brackets outside Esther stay")
        os.unlink(f.name)


if __name__ == "__main__":
    unittest.main()
