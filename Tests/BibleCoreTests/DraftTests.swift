import Foundation
import Testing
@testable import BibleCore

@MainActor @Suite struct DraftStoreTests {
    final class Clock { var now = Date(timeIntervalSince1970: 1_800_000_000) }

    func makeStore(_ database: UserDatabase?, clock: Clock = Clock()) -> DraftStore {
        var next = 0
        return DraftStore(database: database, now: { clock.now }, makeID: { next += 1; return "d\(next)" })
    }

    // @trace FR-38
    @Test func testCreateUpdateSurviveRestart() throws {
        let url = try TestSupport.tempDirectory().appendingPathComponent("userdata.sqlite")
        let clock = Clock()
        let store = makeStore(try UserDatabase(path: url), clock: clock)
        let first = store.create(title: "Про любов")
        #expect(store.activeID == first.id)
        clock.now += 60
        let second = store.create()
        #expect(store.drafts.map(\.id) == [second.id, first.id])
        #expect(second.displayTitle == "Без назви")
        // Зміна піднімає чорнетку нагору; та сама — нічого не пише.
        clock.now += 60
        store.update(first.id, text: "Бог є любов")
        store.update(first.id, text: "Бог є любов")
        store.update("немає", text: "x")
        #expect(store.drafts.map(\.id) == [first.id, second.id])
        #expect(store.drafts[0].updated == clock.now)
        store.update(second.id, title: "Друга")
        #expect(store.drafts[0].title == "Друга" && store.drafts[0].text == "")
        #expect(store.drafts[1].preview == "Бог є любов")

        let reopened = makeStore(try UserDatabase(path: url))
        #expect(reopened.drafts.map(\.text) == ["Бог є любов", ""])
        #expect(reopened.drafts[0].title == "Про любов")
        #expect(reopened.activeID == nil)
    }

    // @trace FR-38
    @Test func testSearchAndDelete() throws {
        let store = makeStore(try UserDatabase.inMemory())
        let love = store.create(title: "Про любов", text: "1 Кор 13")
        store.create(title: "Віра", text: "Євр 11:1 — вірою ЛЮБОВ'ю")
        store.create(title: "Надія", text: "Рим 5:5")
        // Шукаємо в назві й тексті, без регістру: «ЛЮБОВ'ю» теж містить «любов».
        #expect(Set(store.list(matching: " любов ").map(\.title)) == ["Про любов", "Віра"])
        #expect(store.list(matching: "").count == 3)
        store.activeID = love.id
        store.delete(love.id)
        #expect(store.activeID == nil)
        #expect(store.drafts.map(\.title) == ["Надія", "Віра"])
    }

    // @trace FR-38
    @Test func testAppendQuoteToActiveOrNewDraft() throws {
        let store = makeStore(try UserDatabase.inMemory())
        store.append("  ")
        #expect(store.drafts.isEmpty)
        store.append("«For God so loved the world…» (John 3:16)")
        #expect(store.drafts.count == 1)
        #expect(store.active?.text == "«For God so loved the world…» (John 3:16)\n")
        store.append("Друга думка")
        #expect(store.active?.text == "«For God so loved the world…» (John 3:16)\n\nДруга думка\n")
        let empty = store.create()
        store.append("Перша")
        #expect(store.active?.id == empty.id && store.active?.text == "Перша\n")
    }

    // @trace FR-39
    @Test func testSermonTemplate() throws {
        let store = makeStore(try UserDatabase.inMemory())
        let sermon = store.createSermon()
        for part in ["Тема", "Основний текст", "Вступ", "1.", "2.", "3.", "Ілюстрація", "Застосування", "Заклик"] {
            #expect(sermon.text.contains("## \(part)"), "\(part)")
        }
    }

    // @trace FR-39
    @Test func testVerseMentionsAndFilter() throws {
        let store = makeStore(try UserDatabase.inMemory())
        let love = store.create(title: "Любов", text: "Див. 1 Кор 13:4-7")
        let other = store.create(title: "Інша", text: "без посилань")
        let key = { VerseKey(book: 46, chapter: 13, verse: $0) }
        #expect((4...7).allSatisfy { store.isMentioned([key($0)]) })
        #expect(!store.isMentioned([key(8)]))
        store.showMentions(of: [key(8), key(5)])
        #expect(store.isOpen && store.mentionFilter == key(5) && store.activeID == nil)
        #expect(store.list(matching: "").map(\.id) == [love.id])
        store.mentionFilter = VerseKey(book: 1, chapter: 1, verse: 1)
        #expect(store.list(matching: "").isEmpty)
        store.mentionFilter = nil
        // Посилання прибрали — позначки зникають; видалена чорнетка теж не лишає позначок.
        store.update(love.id, text: "текст")
        #expect(!store.isMentioned([key(5)]))
        store.update(other.id, text: "Ин 3:16")
        store.delete(other.id)
        #expect(!store.isMentioned([VerseKey(book: 43, chapter: 3, verse: 16)]))
    }

    // @trace FR-40
    @Test func testMarkdownAndPreview() {
        let draft = Draft(id: "x", title: "Про любов", text: "Бог є любов\n\n", created: .now, updated: .now)
        #expect(draft.markdown == "# Про любов\n\nБог є любов\n")
        let long = Draft(id: "y", title: " ", text: "## Тема\n\n" + String(repeating: "а", count: 200), created: .now, updated: .now)
        #expect(long.preview.hasPrefix("## Тема а") && long.preview.hasSuffix("…") && long.preview.count == 121)
        #expect(long.markdown.hasPrefix("# Без назви\n"))
    }

    // @trace FR-38
    @Test func testWriteAndLoadErrorsKeepMemoryState() throws {
        let database = try UserDatabase.inMemory()
        let store = makeStore(database)
        let draft = store.create(title: "A")
        try database.queue.write { try $0.execute(sql: "DROP TABLE draft") }
        store.create(title: "B")
        store.update(draft.id, text: "змінено")
        store.delete(draft.id)
        #expect(store.drafts.map(\.title) == ["A"] && store.drafts[0].text == "")
        #expect(store.lastError != nil)
        store.dismissError()
        #expect(store.lastError == nil)
        #expect(makeStore(database).lastError != nil)
        // Без бази — лише пам'ять; стандартні годинник та ідентифікатори.
        let plain = DraftStore(database: nil)
        let made = plain.create()
        #expect(!made.id.isEmpty && abs(made.created.timeIntervalSinceNow) < 60)
        let memory = makeStore(nil)
        memory.create(title: "M")
        #expect(memory.drafts.count == 1 && memory.lastError == nil)
    }
}

@Suite struct DraftReferenceTests {
    func found(_ text: String) -> [String] {
        DraftReferences.find(in: text).map { found in
            let r = found.reference
            return "\(r.book) \(r.chapter):\(r.verseStart ?? 0)" + (r.verseEnd.map { "-\($0)" } ?? "")
        }
    }

    // @trace FR-38
    @Test func testRecognisesReferencesInText() {
        #expect(found("див. Ин 3:16 і 1 Кор 13:4-7, а також John 3:16–18") == ["43 3:16", "46 13:4-7", "43 3:16-18"])
        #expect(found("Song of Solomon 2:1 і Пісня над піснями 2:4") == ["22 2:1", "22 2:4"])
        #expect(found("Бог так полюбив світ Ів. 3:16") == ["43 3:16"])
        let text = "читай 2 Тим 3:16"
        let reference = DraftReferences.find(in: text)[0]
        #expect(text[reference.range] == "2 Тим 3:16")
        #expect(reference.keys.map(\.verse) == [16])
    }

    // @trace FR-38
    @Test func testNoFalsePositives() {
        #expect(found("о 10:30 зустріч, 3:1 — рахунок матчу").isEmpty)
        #expect(found("Ин 3 без вірша, Ин 0:1 теж ні").isEmpty)
    }
}

@MainActor @Suite struct DraftRenderingTests {
    // @trace FR-38
    @Test func testBlocksAndLinks() {
        let blocks = DraftRendering.blocks("# Про любов\n\n\n## 1. Ин 3:16\n- пункт\n* ще\n#хештег\nтекст 1 Кор 13:4-7 кінець\n\n")
        #expect(blocks == [
            .heading(level: 1, inline: "Про любов"), .spacer,
            .heading(level: 2, inline: "1. [Ин 3:16](biblereader:43/3/16-16)"),
            .bullet(inline: "пункт"), .bullet(inline: "ще"), .paragraph(inline: "#хештег"),
            .paragraph(inline: "текст [1 Кор 13:4-7](biblereader:46/13/4-7) кінець"),
        ])
        #expect(DraftRendering.blocks("#### Глибоко") == [.heading(level: 3, inline: "Глибоко")])
        #expect(DraftRendering.blocks("") == [])
    }

    // @trace FR-38
    @Test func testLinkBackToReference() {
        #expect(DraftRendering.reference(fromLink: "biblereader:46/13/4-7") == Reference(book: 46, chapter: 13, verseStart: 4, verseEnd: 7))
        #expect(DraftRendering.reference(fromLink: "biblereader:43/3/16-16") == Reference(book: 43, chapter: 3, verseStart: 16))
        for bad in ["mailto:x", "biblereader:43/3", "biblereader:99/1/1-1", "biblereader:a/b/c-d"] {
            #expect(DraftRendering.reference(fromLink: bad) == nil, "\(bad)")
        }
    }

    // @trace FR-38
    @Test func testVerseTextForLinkTooltip() {
        let model = ReaderViewModel { try SQLiteBibleRepository(path: TestSupport.realDatabase) }
        #expect(model.text(of: Reference(book: 43, chapter: 3, verseStart: 16))?.hasPrefix("For God so loved") == true)
        model.translation = .synodal
        // Пс 23:1 KJV — Пс 22:1 Синодального.
        #expect(model.text(of: Reference(book: 19, chapter: 23, verseStart: 1, verseEnd: 2))?.hasPrefix("псалом Давида. Господь - Пастырь мой") == true)
        #expect(model.text(of: Reference(book: 43, chapter: 3)) == nil)
        #expect(model.text(of: Reference(book: 43, chapter: 99, verseStart: 1)) == nil)
        #expect(ReaderViewModel { throw FakeRepository.Boom() }.text(of: Reference(book: 43, chapter: 3, verseStart: 16)) == nil)
    }
}
