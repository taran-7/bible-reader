import AppKit
import BibleCore
import Security
import SwiftUI
#if canImport(Translation)
@preconcurrency import Translation
#endif

/// Панель «Ілюстрації» праворуч від тексту (FR-33): до 7 історій до виділених віршів, «Отримати ще»,
/// «Перекласти» і «Скопіювати» на картці. Нічого не зберігається: закрили панель — історії зникли.
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
                Text("Нічого не знайдено").foregroundStyle(Color(theme.secondaryText))
                    .accessibilityIdentifier("illustrations-empty")
            }
            if model.hasMore {
                Button("Отримати ще") { Task { await model.loadMore() } }
                    .accessibilityIdentifier("illustrations-more")
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

/// Картка історії: заголовок, джерело й дата, текст, «Читати на сайті» для уривка, «Перекласти», «Скопіювати».
/// «Перекласти» — мовою Біблії на екрані системним перекладачем Apple (офлайн, macOS 15+); «Скопіювати» бере те,
/// що зараз на картці.
struct IllustrationCard: View {
    let story: Illustration
    /// Мова перекладу Біблії на екрані; `nil` — англійська, кнопки немає.
    let targetLanguage: String?
    @State private var copied = false
    @State private var translated: (title: String, text: String)?
    @State private var showsTranslation = false
    @State private var translating = false
    @State private var translationError: String?
    @State private var request = 0
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
            Text(shown.text).font(.system(size: scale.systemFontSize)).textSelection(.enabled)
            if let translationError {
                Text(translationError).font(.system(size: scale.systemFontSize * 0.9)).foregroundStyle(.orange)
            }
            HStack {
                if let url = IllustrationNetwork.link(for: story) {
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
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: CopyButtonModel.feedbackDuration)
            copied = false
        }
    }
}

/// Системний перекладач Apple (Translation, macOS 15+): англійська → мова Біблії на екрані, на пристрої.
/// Мовний пакет система завантажує сама при першому перекладі; на macOS 14 кнопки немає.
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

        /// Сесія перекладу не `Sendable`: працюємо з нею на тому самому акторі, що й `translationTask`.
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

/// Стан вікна: історії, «Шукаю…», помилки. Пошук і фільтри — у `IllustrationSearch` (BibleCore).
@MainActor @Observable
final class IllustrationsModel {
    enum State: Equatable { case idle, loading, offline, failed(String) }

    private(set) var stories: [Illustration] = []
    private(set) var state: State = .idle
    private(set) var hasMore = false
    private(set) var hasBraveKey = false
    @ObservationIgnored private var search: IllustrationSearch?
    @ObservationIgnored private var request: IllustrationRequest?

    func start(_ request: IllustrationRequest) async {
        self.request = request
        stories = []
        do {
            let sources = try IllustrationSources.bundled
            let key = BraveKey.load()
            hasBraveKey = key != nil
            search = IllustrationSearch(request: request, sources: sources,
                                        providers: IllustrationSearch.providers(sources: sources, braveKey: key),
                                        http: IllustrationNetwork())
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
            state = .idle
        } catch IllustrationError.offline {
            state = .offline
        } catch IllustrationError.failed(let message) {
            state = .failed(message)
        } catch {
            state = .failed("\(error)")
        }
    }

    /// «Повторити»: з нуля, якщо ще нічого не показано, інакше — та сама партія ще раз.
    func retry() async {
        if stories.isEmpty, let request { await start(request) } else { await loadMore() }
    }
}

/// Ключ Brave Search API користувача в Keychain: у `.app` ключа немає (його витягнув би будь-хто).
enum BraveKey {
    private static let service = "dev.taraniuk.BibleReader.brave-search"

    static func load() -> String? {
        var item: CFTypeRef?
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data,
              let key = String(data: data, encoding: .utf8), !key.isEmpty else { return nil }
        return key
    }

    /// Порожній рядок видаляє ключ.
    static func save(_ key: String) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
        SecItemDelete(base as CFDictionary)
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var item = base
        item[kSecValueData as String] = Data(trimmed.utf8)
        SecItemAdd(item as CFDictionary, nil)
    }
}

/// «Ілюстрації» поруч із «Порівняти» на виділенні (FR-33).
struct IllustrationsButton: View {
    let action: () -> Void

    var body: some View {
        SelectionButton(title: "Ілюстрації", systemImage: "text.book.closed", help: "Пошук ілюстрацій",
                        identifier: "illustrations-button", action: action)
    }
}
