public enum Testament: Sendable {
    case old
    case new
}

/// Книга протестантського канону (1–66) з назвами і скороченнями обох мов.
public struct Book: Hashable, Identifiable, Sendable {
    public let number: Int
    public let englishName: String
    public let englishAbbreviation: String
    public let russianName: String
    public let russianAbbreviation: String
    /// Додаткові написання для розбору посилань.
    let aliases: [String]

    public var id: Int { number }
    public var testament: Testament { number <= 39 ? .old : .new }

    public init?(number: Int) {
        guard (1...Book.all.count).contains(number) else { return nil }
        self = Book.all[number - 1]
    }

    private init(_ number: Int, _ en: String, _ enAbbr: String, _ ru: String, _ ruAbbr: String, _ aliases: [String]) {
        self.number = number
        englishName = en
        englishAbbreviation = enAbbr
        russianName = ru
        russianAbbreviation = ruAbbr
        self.aliases = aliases
    }

    public func name(in translation: Translation) -> String {
        translation == .kjv ? englishName : russianName
    }

    public func abbreviation(in translation: Translation) -> String {
        translation == .kjv ? englishAbbreviation : russianAbbreviation
    }

    /// Усі написання: назви, скорочення, синоніми.
    var spellings: [String] {
        [englishName, englishAbbreviation, russianName, russianAbbreviation] + aliases
    }

    public static let all: [Book] = [
        Book(1, "Genesis", "Gen", "Бытие", "Быт", ["Бт"]),
        Book(2, "Exodus", "Exod", "Исход", "Исх", ["Ex"]),
        Book(3, "Leviticus", "Lev", "Левит", "Лев", []),
        Book(4, "Numbers", "Num", "Числа", "Чис", []),
        Book(5, "Deuteronomy", "Deut", "Второзаконие", "Втор", []),
        Book(6, "Joshua", "Josh", "Иисус Навин", "Нав", ["Иисус Навина"]),
        Book(7, "Judges", "Judg", "Судьи", "Суд", ["Судей"]),
        Book(8, "Ruth", "Ruth", "Руфь", "Руф", []),
        Book(9, "1 Samuel", "1 Sam", "1 Царств", "1 Цар", []),
        Book(10, "2 Samuel", "2 Sam", "2 Царств", "2 Цар", []),
        Book(11, "1 Kings", "1 Kgs", "3 Царств", "3 Цар", []),
        Book(12, "2 Kings", "2 Kgs", "4 Царств", "4 Цар", []),
        Book(13, "1 Chronicles", "1 Chr", "1 Паралипоменон", "1 Пар", []),
        Book(14, "2 Chronicles", "2 Chr", "2 Паралипоменон", "2 Пар", []),
        Book(15, "Ezra", "Ezra", "Ездра", "Езд", []),
        Book(16, "Nehemiah", "Neh", "Неемия", "Неем", []),
        Book(17, "Esther", "Esth", "Есфирь", "Есф", []),
        Book(18, "Job", "Job", "Иов", "Иов", []),
        Book(19, "Psalms", "Ps", "Псалтирь", "Пс", ["Psalm", "Псалом", "Псалмы"]),
        Book(20, "Proverbs", "Prov", "Притчи", "Притч", []),
        Book(21, "Ecclesiastes", "Eccl", "Екклесиаст", "Еккл", []),
        Book(22, "Song of Solomon", "Song", "Песнь песней", "Песн", ["Песнь песней Соломона"]),
        Book(23, "Isaiah", "Isa", "Исаия", "Ис", []),
        Book(24, "Jeremiah", "Jer", "Иеремия", "Иер", []),
        Book(25, "Lamentations", "Lam", "Плач Иеремии", "Плач", []),
        Book(26, "Ezekiel", "Ezek", "Иезекииль", "Иез", []),
        Book(27, "Daniel", "Dan", "Даниил", "Дан", []),
        Book(28, "Hosea", "Hos", "Осия", "Ос", []),
        Book(29, "Joel", "Joel", "Иоиль", "Иоил", []),
        Book(30, "Amos", "Amos", "Амос", "Ам", []),
        Book(31, "Obadiah", "Obad", "Авдий", "Авд", []),
        Book(32, "Jonah", "Jonah", "Иона", "Ион", []),
        Book(33, "Micah", "Mic", "Михей", "Мих", []),
        Book(34, "Nahum", "Nah", "Наум", "Наум", []),
        Book(35, "Habakkuk", "Hab", "Аввакум", "Авв", []),
        Book(36, "Zephaniah", "Zeph", "Софония", "Соф", []),
        Book(37, "Haggai", "Hag", "Аггей", "Агг", []),
        Book(38, "Zechariah", "Zech", "Захария", "Зах", []),
        Book(39, "Malachi", "Mal", "Малахия", "Мал", []),
        Book(40, "Matthew", "Matt", "От Матфея", "Мф", ["Mt", "Матфея", "Мат", "Матф"]),
        Book(41, "Mark", "Mark", "От Марка", "Мк", ["Mk", "Марка", "Мар"]),
        Book(42, "Luke", "Luke", "От Луки", "Лк", ["Lk", "Луки", "Лук"]),
        Book(43, "John", "John", "От Иоанна", "Ин", ["Jn", "Иоанна", "Иоан"]),
        Book(44, "Acts", "Acts", "Деяния", "Деян", ["Деяния апостолов"]),
        Book(45, "Romans", "Rom", "Римлянам", "Рим", []),
        Book(46, "1 Corinthians", "1 Cor", "1 Коринфянам", "1 Кор", []),
        Book(47, "2 Corinthians", "2 Cor", "2 Коринфянам", "2 Кор", []),
        Book(48, "Galatians", "Gal", "Галатам", "Гал", []),
        Book(49, "Ephesians", "Eph", "Ефесянам", "Еф", []),
        Book(50, "Philippians", "Phil", "Филиппийцам", "Флп", []),
        Book(51, "Colossians", "Col", "Колоссянам", "Кол", []),
        Book(52, "1 Thessalonians", "1 Thess", "1 Фессалоникийцам", "1 Фес", []),
        Book(53, "2 Thessalonians", "2 Thess", "2 Фессалоникийцам", "2 Фес", []),
        Book(54, "1 Timothy", "1 Tim", "1 Тимофею", "1 Тим", []),
        Book(55, "2 Timothy", "2 Tim", "2 Тимофею", "2 Тим", []),
        Book(56, "Titus", "Titus", "Титу", "Тит", []),
        Book(57, "Philemon", "Phlm", "Филимону", "Флм", []),
        Book(58, "Hebrews", "Heb", "Евреям", "Евр", []),
        Book(59, "James", "Jas", "Иакова", "Иак", []),
        Book(60, "1 Peter", "1 Pet", "1 Петра", "1 Пет", []),
        Book(61, "2 Peter", "2 Pet", "2 Петра", "2 Пет", []),
        Book(62, "1 John", "1 John", "1 Иоанна", "1 Ин", ["1 Jn"]),
        Book(63, "2 John", "2 John", "2 Иоанна", "2 Ин", ["2 Jn"]),
        Book(64, "3 John", "3 John", "3 Иоанна", "3 Ин", ["3 Jn"]),
        Book(65, "Jude", "Jude", "Иуды", "Иуд", []),
        Book(66, "Revelation", "Rev", "Откровение", "Откр", ["Revelation of John", "Апокалипсис"]),
    ]
}
