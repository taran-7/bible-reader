import AppKit
import BibleCore
import Security
import SwiftUI
#if canImport(Translation)
@preconcurrency import Translation
#endif
#if canImport(FoundationModels)
import FoundationModels
#endif

/// The "Illustrations" panel to the right of the text (FR-33): up to 7 stories for the selected verses, "Get more",
/// "Translate" and "Copy" on the card. Nothing is stored: close the panel and the stories are gone.
struct IllustrationsView: View {
    let request: IllustrationRequest
    let close: () -> Void
    @State private var model = IllustrationsModel()
    @Environment(\.theme) private var theme
    @Environment(\.interfaceScale) private var scale

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Ілюстрації до \(request.reference)")
                        .font(.system(size: scale.systemFontSize * 1.4, weight: .semibold))
                        .accessibilityIdentifier("illustrations-title")
                    Spacer()
                    Button("Закрити ілюстрації", systemImage: "xmark", action: close)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("illustrations-close")
                }
                ForEach(model.stories) { IllustrationCard(story: $0, targetLanguage: request.translationTarget) }
                footer
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(ThemeBackground())
        .foregroundStyle(Color(theme.text))
        .task { await model.start(request) }
    }

    @ViewBuilder private var footer: some View {
        switch model.state {
        case .loading:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Шукаю історії…").foregroundStyle(Color(theme.secondaryText))
            }
            .accessibilityIdentifier("illustrations-loading")
        case .offline:
            failure("Немає підключення до мережі", detail: "Ілюстрації шукаються на сайтах в інтернеті.")
        case .failed(let message):
            failure("Не вдалося знайти ілюстрації", detail: message)
        case .idle:
            if model.stories.isEmpty {
                // The model rejected all reviewed candidates, but there is more to search.
                Text(model.hasMore ? "Поки нічого доречного — «Отримати ще» шукає далі" : "Нічого не знайдено").foregroundStyle(Color(theme.secondaryText))
                    .accessibilityIdentifier("illustrations-empty")
            }
            if model.hasMore {
                Button("Отримати ще") { Task { await model.loadMore() } }
                    .accessibilityIdentifier("illustrations-more")
            }
            if let name = model.curatorName, !model.stories.isEmpty {
                Label("Відібрано моделлю: \(name)", systemImage: "sparkles")
                    .font(.system(size: scale.systemFontSize * 0.9))
                    .foregroundStyle(Color(theme.secondaryText))
                    .accessibilityIdentifier("illustrations-curator")
            }
            if let problem = model.curatorProblem {
                Label("Без відбору моделлю — \(problem)", systemImage: "exclamationmark.triangle")
                    .font(.system(size: scale.systemFontSize * 0.9))
                    .foregroundStyle(.orange)
                    .textSelection(.enabled)
            }
            if !model.hasBraveKey {
                Text("Більше сайтів — з ключем Brave Search у Налаштуваннях.")
                    .font(.system(size: scale.systemFontSize * 0.9))
                    .foregroundStyle(Color(theme.secondaryText))
            }
        }
    }

    private func failure(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: "wifi.exclamationmark").font(.headline)
            Text(detail).foregroundStyle(Color(theme.secondaryText)).textSelection(.enabled)
            Button("Повторити") { Task { await model.retry() } }
                .accessibilityIdentifier("illustrations-retry")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("illustrations-error")
    }
}

/// A story card: title, source and date, text, "Read on site" for an excerpt, "Translate", "Copy".
/// "Translate" into the on-screen Bible's language via Apple's system translator (offline, macOS 15+); "Copy" takes what
/// is currently on the card.
struct IllustrationCard: View {
    let story: Illustration
    /// The on-screen Bible translation's language; `nil` means English, no button.
    let targetLanguage: String?
    @State private var copied = false
    @State private var translated: (title: String, text: String)?
    @State private var showsTranslation = false
    @State private var translating = false
    @State private var translationError: String?
    @State private var request = 0
    @State private var addedToDraft = false
    @Environment(DraftStore.self) private var drafts
    @Environment(\.theme) private var theme
    @Environment(\.interfaceScale) private var scale

    private var shown: (title: String, text: String) {
        showsTranslation ? translated ?? (story.title, story.text) : (story.title, story.text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(shown.title).font(.system(size: scale.systemFontSize * 1.15, weight: .semibold))
            Text([story.siteName, story.date].compactMap { $0 }.joined(separator: " · "))
                .font(.system(size: scale.systemFontSize * 0.9))
                .foregroundStyle(Color(theme.secondaryText))
            if let reason = story.reason {
                // The model's explanation is already in the on-screen translation's language (FR-41).
                (Text("Чому ця історія: ").bold() + Text(reason))
                    .font(.system(size: scale.systemFontSize * 0.95))
                    .foregroundStyle(Color(theme.accent))
                    .textSelection(.enabled)
                    .accessibilityIdentifier("illustration-reason")
            }
            Text(shown.text).font(.system(size: scale.systemFontSize)).textSelection(.enabled)
            if let translationError {
                Text(translationError).font(.system(size: scale.systemFontSize * 0.9)).foregroundStyle(.orange)
            }
            HStack {
                if let sources = try? IllustrationSources.bundled, let url = IllustrationNetwork.link(for: story, sources: sources) {
                    Link(story.isExcerpt ? "Читати на сайті" : "Джерело", destination: url)
                }
                Spacer()
                if targetLanguage != nil, TranslationSupport.isAvailable {
                    Button {
                        if translated == nil { request += 1 } else { showsTranslation.toggle() }
                    } label: {
                        if translating { ProgressView().controlSize(.small) } else { Text(showsTranslation ? "Оригінал" : "Перекласти") }
                    }
                    .disabled(translating)
                    .accessibilityIdentifier("illustration-translate")
                }
                Button {
                    // What is currently on the card (original or translation), with the source (FR-39).
                    drafts.append("### " + story.copyText(title: shown.title, text: shown.text))
                    addedToDraft = true
                } label: {
                    Label(addedToDraft ? "Додано" : "В чорнетку", systemImage: addedToDraft ? "checkmark" : "square.and.pencil")
                }
                .accessibilityIdentifier("illustration-draft")
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(story.copyText(title: shown.title, text: shown.text), forType: .string)
                    copied = true
                } label: {
                    Label(copied ? "Скопійовано" : "Скопіювати", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .accessibilityIdentifier("illustration-copy")
            }
        }
        .padding(14)
        .background(Color(theme.results).opacity(0.9), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("illustration-card")
        .modifier(TranslationSupport(request: request, target: targetLanguage, texts: [story.title, story.text]) { result in
            translating = false
            switch result {
            case .success(let texts) where texts.count == 2:
                translated = (texts[0], texts[1])
                showsTranslation = true
                translationError = nil
            case .success:
                translationError = "Не вдалося перекласти"
            case .failure(let error):
                translationError = "Не вдалося перекласти: \(error.localizedDescription)"
            }
        } started: { translating = true })
        .task(id: addedToDraft) {
            guard addedToDraft else { return }
            try? await Task.sleep(for: CopyButtonModel.feedbackDuration)
            addedToDraft = false
        }
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: CopyButtonModel.feedbackDuration)
            copied = false
        }
    }
}

/// Apple's system translator (Translation, macOS 15+): English → the on-screen Bible's language, on-device.
/// The system downloads the language pack itself on the first translation; on macOS 14 there is no button.
struct TranslationSupport: ViewModifier {
    let request: Int
    let target: String?
    let texts: [String]
    let completion: (Result<[String], Error>) -> Void
    let started: () -> Void

    static var isAvailable: Bool {
        if #available(macOS 15.0, *) { return true }
        return false
    }

    func body(content: Content) -> some View {
        #if canImport(Translation)
        if #available(macOS 15.0, *) {
            content.modifier(Session(request: request, target: target, texts: texts, completion: completion, started: started))
        } else {
            content
        }
        #else
        content
        #endif
    }

    #if canImport(Translation)
    @available(macOS 15.0, *)
    private struct Session: ViewModifier {
        let request: Int
        let target: String?
        let texts: [String]
        let completion: (Result<[String], Error>) -> Void
        let started: () -> Void
        @State private var configuration: TranslationSession.Configuration?

        /// The translation session is not `Sendable`: work with it on the same actor as `translationTask`.
        @MainActor private static func translate(_ texts: [String], with session: TranslationSession) async -> Result<[String], Error> {
            do {
                var translated: [String] = []
                for text in texts { translated.append(try await session.translate(text).targetText) }
                return .success(translated)
            } catch {
                return .failure(error)
            }
        }

        func body(content: Content) -> some View {
            content
                .onChange(of: request) { _, _ in
                    guard let target else { return }
                    started()
                    if configuration == nil {
                        configuration = .init(source: Locale.Language(identifier: "en"), target: Locale.Language(identifier: target))
                    } else {
                        configuration?.invalidate()
                    }
                }
                .translationTask(configuration) { session in
                    let result = await Self.translate(texts, with: session)
                    completion(result)
                }
        }
    }
    #endif
}

/// Window state: stories, "Searching…", errors. Search and filters are in `IllustrationSearch` (BibleCore).
@MainActor @Observable
final class IllustrationsModel {
    enum State: Equatable { case idle, loading, offline, failed(String) }

    private(set) var stories: [Illustration] = []
    private(set) var state: State = .idle
    private(set) var hasMore = false
    private(set) var hasBraveKey = false
    /// Who curated the stories (FR-41) and why model curation did not work.
    private(set) var curatorName: String?
    private(set) var curatorProblem: String?
    @ObservationIgnored private var search: IllustrationSearch?
    @ObservationIgnored private var request: IllustrationRequest?

    func start(_ request: IllustrationRequest) async {
        self.request = request
        stories = []
        do {
            let sources = try IllustrationSources.bundled
            let key = KeychainKey.brave.load()
            hasBraveKey = key != nil
            let http = IllustrationNetwork()
            search = IllustrationSearch(request: request, sources: sources,
                                        providers: IllustrationSearch.providers(sources: sources, braveKey: key),
                                        http: http, curator: Curators.preferred(http: http))
        } catch {
            state = .failed("\(error)")
            return
        }
        await loadMore()
    }

    func loadMore() async {
        guard let search, state != .loading else { return }
        state = .loading
        do {
            stories += try await search.next()
            hasMore = await search.hasMore
            curatorName = await search.curatorName
            curatorProblem = await search.curatorProblem
            state = .idle
        } catch IllustrationError.offline {
            state = .offline
        } catch IllustrationError.failed(let message) {
            state = .failed(message)
        } catch {
            state = .failed("\(error)")
        }
    }

    /// "Retry": from scratch if nothing is shown yet, otherwise the same batch again.
    func retry() async {
        if stories.isEmpty, let request { await start(request) } else { await loadMore() }
    }
}

/// The user's API keys in the Keychain (Brave Search, Claude): the `.app` has no keys (anyone could extract them).
struct KeychainKey {
    static let brave = KeychainKey(service: "dev.taraniuk.BibleReader.brave-search")
    static let claude = KeychainKey(service: "dev.taraniuk.BibleReader.claude")

    let service: String

    func load() -> String? {
        var item: CFTypeRef?
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data,
              let key = String(data: data, encoding: .utf8), !key.isEmpty else { return nil }
        return key
    }

    /// An empty string deletes the key. `false` means the Keychain did not accept the write.
    @discardableResult
    func save(_ key: String) -> Bool {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            let status = SecItemDelete(base as CFDictionary)
            return status == errSecSuccess || status == errSecItemNotFound
        }
        let data = Data(trimmed.utf8)
        if SecItemUpdate(base as CFDictionary, [kSecValueData as String: data] as CFDictionary) == errSecSuccess { return true }
        var item = base
        item[kSecValueData as String] = data
        // Only on this Mac and only while it is unlocked: the key does not sync or migrate.
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }
}

/// The curation model (FR-41): Claude if there is a key; otherwise the Apple on-device model if available; otherwise no model.
enum Curators {
    static func preferred(http: IllustrationHTTP) -> IllustrationCurator? {
        if let key = KeychainKey.claude.load() { return ClaudeCurator(key: key, http: http) }
        return appleCurator
    }

    /// The name of the model that will curate, for Settings.
    static var activeName: String? {
        KeychainKey.claude.load() != nil ? "Claude (твій ключ)" : appleCurator.map { _ in "модель Apple на цьому Mac" }
    }

    static var appleCurator: IllustrationCurator? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *), AppleCurator.isAvailable { return AppleCurator() }
        #endif
        return nil
    }
}

#if canImport(FoundationModels)
/// The Apple on-device model (Apple Intelligence, macOS 26+): no key and no network.
@available(macOS 26.0, *)
struct AppleCurator: IllustrationCurator {
    let name = "Apple Intelligence"
    /// The on-device model context is ~4k tokens: a smaller pool and shorter excerpts than for Claude.
    let candidatePool = 7
    let excerptLength = 300

    static var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    func complete(system: String, prompt: String) async throws -> String {
        try await LanguageModelSession(instructions: system).respond(to: prompt).content
    }
}
#endif

/// "Illustrations" next to "Compare" on the selection (FR-33).
struct IllustrationsButton: View {
    let action: () -> Void

    var body: some View {
        SelectionButton(title: "Ілюстрації", systemImage: "text.book.closed", help: "Пошук ілюстрацій",
                        identifier: "illustrations-button", action: action)
    }
}
