import CSnowball
import Foundation

/// A word stem for morphological search (FR-18). The same stemmer is applied to the text
/// at import (`verses_stem_fts`) and to the query, so all that matters is that forms of one word
/// give the same stem.
/// - English, Russian: Snowball; for KJV first `-eth`/`-est` → `-es` (`loveth` → `loves`);
/// - Ukrainian: light suffix stripping (Snowball has no Ukrainian stemmer);
/// - Czech: the Dolamic & Savoy light stemmer (like `CzechStemmer` in Lucene).
/// Not thread-safe: Snowball keeps state; create one instance per operation.
public final class Stemmer {
    public let language: Language
    private let env: OpaquePointer?

    public init(language: Language) {
        self.language = language
        switch language {
        case .english: env = english_UTF_8_create_env()
        case .russian: env = russian_UTF_8_create_env()
        case .ukrainian, .czech, .other: env = nil
        }
    }

    deinit {
        switch language {
        case .english: english_UTF_8_close_env(env)
        case .russian: russian_UTF_8_close_env(env)
        case .ukrainian, .czech, .other: break
        }
    }

    public struct Word: Equatable {
        public let text: String
        public let range: Range<String.Index>
    }

    /// Words as `unicode61` sees them: runs of letters and digits; an apostrophe and the rest are separators.
    public static func words(in text: String) -> [Word] {
        var result: [Word] = []
        var start: String.Index?
        for index in text.indices {
            let character = text[index]
            if character.isLetter || character.isNumber {
                if start == nil { start = index }
            } else if let begin = start {
                result.append(Word(text: String(text[begin..<index]), range: begin..<index))
                start = nil
            }
        }
        if let begin = start {
            result.append(Word(text: String(text[begin...]), range: begin..<text.endIndex))
        }
        return result
    }

    /// Text for the stem index: word stems separated by spaces.
    public func stemmed(_ text: String) -> String {
        Self.words(in: text).map { stem($0.text) }.joined(separator: " ")
    }

    public func stem(_ word: String) -> String {
        let word = SearchText.fold(word).lowercased()
        switch language {
        case .english: return snowball(Self.kjvVerbForm(word), stem: english_UTF_8_stem)
        case .russian: return Self.russianFleetingVowel(snowball(word, stem: russian_UTF_8_stem))
        case .ukrainian: return Self.ukrainian(word)
        // A language without a stemmer: match exact word forms (as before FR-18).
        case .other: return word
        // Without diacritics: the index folds them, and the query `buh` must give the same stem as `bůh`.
        case .czech: return Self.czech(word.folding(options: .diacriticInsensitive, locale: nil))
        }
    }

    private func snowball(_ word: String, stem: (OpaquePointer?) -> Int32) -> String {
        let bytes = Array(word.utf8)
        var length: Int32 = 0
        guard let env, SN_set_current(env, Int32(bytes.count), bytes) == 0, stem(env) >= 0,
              let result = snowball_result(env, &length) else { return word }
        return String(decoding: UnsafeBufferPointer(start: result, count: Int(length)), as: UTF8.self)
    }

    // MARK: - English (KJV)

    /// Words ending in -est that are not 2nd person verb forms (priest, beast…).
    private static let notVerbForms: Set<String> = [
        "priest", "beast", "feast", "east", "west", "rest", "best", "nest", "breast", "chest", "guest",
        "harvest", "forest", "honest", "earnest", "tempest", "request", "conquest", "manifest", "interest",
        "lest", "jest", "test", "quest", "crest", "pest", "vest", "zest", "least", "midst", "modest",
    ]

    /// `loveth`, `lovest` → `loves`: then Snowball gives the same stem as for `loved`, `loving`.
    static func kjvVerbForm(_ word: String) -> String {
        guard word.count >= 5, !notVerbForms.contains(word),
              word.hasSuffix("eth") || word.hasSuffix("est") else { return word }
        return String(word.dropLast(3)) + "es"
    }

    // MARK: - Russian

    private static let russianVowels = Set("аеиоуыэюяё")

    /// A fleeting vowel: `любви` → `любв`, but `любовь` → `любов`; a stem ending in consonant+«в» gets «о» added.
    static func russianFleetingVowel(_ stem: String) -> String {
        let letters = Array(stem)
        guard letters.count >= 3, letters.last == "в", !russianVowels.contains(letters[letters.count - 2]),
              letters[letters.count - 2].isLetter, letters[letters.count - 2] != "ь" else { return stem }
        return String(letters.dropLast()) + "ов"
    }

    // MARK: - Ukrainian

    private static let ukrainianVowels = Set("аеєиіїоуюя")

    /// Endings, roughly from longer to shorter; the first one is stripped after which the stem keeps
    /// at least one letter after the first vowel and ≥ 2 letters in total.
    private static let ukrainianEndings: [String] = [
        "ювали", "ували", "ившись", "увшись",
        "ачи", "ячи", "учи", "ючи", "вши", "ись", "ися",
        "ами", "ями", "ові", "еві", "єві", "ого", "ому", "ього", "ьому", "ими", "іми",
        "ала", "яла", "ила", "іла", "ула", "ело", "ало", "ило", "іло", "али", "яли", "или", "іли", "ули",
        "ати", "яти", "ити", "іти", "ути", "ємо", "емо", "имо", "ете", "єте", "ите", "ить", "іть",
        "ать", "ять", "уть", "ють", "ся", "сь",
        "ий", "ій", "ої", "ою", "єю", "ею", "ам", "ям", "ах", "ях", "ів", "їв", "ей", "ем", "ом", "им", "ім",
        "их", "іх", "ав", "ив", "ов", "ла", "ло", "ли", "єш", "иш", "еш", "ую", "юю",
        "а", "я", "о", "е", "є", "у", "ю", "і", "ї", "и", "ь",
    ]

    static func ukrainian(_ word: String) -> String {
        let letters = Array(word)
        guard let firstVowel = letters.firstIndex(where: ukrainianVowels.contains) else { return word }
        for ending in ukrainianEndings where word.hasSuffix(ending) {
            let stemLength = letters.count - ending.count
            if stemLength - (firstVowel + 1) >= 1, stemLength >= 2 {
                var stem = String(letters[..<stemLength])
                if stem.hasSuffix("ь") { stem.removeLast() }
                return stem
            }
        }
        return word
    }

    // MARK: - Czech (Dolamic & Savoy, light)
    // The word arrives already without diacritics (see `stem`), so the rules with ě, ů, č, ž do not fire here, and
    // `z` → `h` also hits a genuine `z`. Deliberately: otherwise a query without diacritics (`buh`) would not find `Bůh`;
    // the stemmer is slightly less precise, but the index and the query always give the same stem. The rules stay as in
    // the original, to compare against Lucene `CzechStemmer`.

    static func czech(_ word: String) -> String {
        var s = Array(word)
        func ends(_ suffixes: String...) -> Bool {
            suffixes.contains { suffix in s.count >= suffix.count && s.suffix(suffix.count).elementsEqual(suffix) }
        }
        // Case endings.
        if s.count > 7, ends("atech") {
            s.removeLast(5)
        } else if s.count > 6, ends("ětem", "etem", "atům") {
            s.removeLast(4)
        } else if s.count > 5, ends("ech", "ich", "ích", "ého", "ěmi", "emi", "ému", "ěte", "ete", "ěti", "eti",
                                     "ího", "iho", "ími", "ímu", "imu", "ách", "ata", "aty", "ých", "ama", "ami",
                                     "ové", "ovi", "ými") {
            s.removeLast(3)
        } else if s.count > 4, ends("em", "es", "ém", "ím", "ům", "at", "ám", "os", "us", "ým", "mi", "ou") {
            s.removeLast(2)
        } else if s.count > 3, ends("a", "e", "i", "o", "u", "ů", "y", "á", "é", "í", "ý", "ě") {
            s.removeLast(1)
        }
        // Possessives.
        if s.count > 5, ends("ov", "in", "ův") { s.removeLast(2) }
        // Normalizing alternations.
        if ends("čt") {
            s.replaceSubrange((s.count - 2)..., with: "ck")
        } else if ends("št") {
            s.replaceSubrange((s.count - 2)..., with: "sk")
        } else if let last = s.last {
            switch last {
            case "c", "č": s[s.count - 1] = "k"
            case "z", "ž": s[s.count - 1] = "h"
            default:
                if s.count > 1, s[s.count - 2] == "e" {
                    s.remove(at: s.count - 2)
                } else if s.count > 2, s[s.count - 2] == "ů" {
                    s[s.count - 2] = "o"
                }
            }
        }
        return String(s)
    }
}
