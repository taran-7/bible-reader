import BibleCore
import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: PreferencesStore
    @State private var braveKey = KeychainKey.brave.load() ?? ""
    /// What is actually in the Keychain, not what is typed in the field.
    @State private var keySaved = KeychainKey.brave.load() != nil
    @State private var keyError = false
    @State private var claudeKey = KeychainKey.claude.load() ?? ""
    @State private var claudeSaved = KeychainKey.claude.load() != nil
    @State private var claudeError = false
    /// Who will curate: re-read after saving a key, not on every render (Keychain).
    @State private var curatorName = Curators.activeName

    var body: some View {
        Form {
            Stepper(value: $preferences.preferences.verseFontSize, in: ReadingPreferences.verseFontRange, step: 1) {
                Text("Текст віршів: \(Int(preferences.preferences.verseFontSize)) pt")
            }
            Stepper(value: $preferences.preferences.bookListFontSize, in: ReadingPreferences.bookListFontRange, step: 1) {
                Text("Список книг: \(Int(preferences.preferences.bookListFontSize)) pt")
            }
            Picker("Масштаб інтерфейсу", selection: $preferences.preferences.interfaceScale) {
                ForEach(InterfaceScale.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .accessibilityIdentifier("interface-scale")
            ThemePicker(preferences: preferences)
                .accessibilityIdentifier("theme")
            Button("Скинути до стандартних") { preferences.reset() }
            Section {
                SecureField("Ключ Brave Search API", text: $braveKey)
                    .accessibilityIdentifier("brave-key")
                    .onSubmit(saveKey)
                    .onDisappear(perform: saveKey)
                HStack {
                    // Whether the key is valid shows only during search: here only that it is saved.
                    if keyError {
                        Label("Не вдалося зберегти ключ", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    } else if !keySaved {
                        Label("Ключа немає", systemImage: "key").foregroundStyle(.secondary)
                    } else {
                        Label("Ключ збережено", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                    Spacer()
                    Link("Отримати ключ", destination: IllustrationNetwork.braveKeyPage)
                        .accessibilityIdentifier("brave-key-link")
                }
                .accessibilityIdentifier("brave-key-status")
            } header: {
                Text("Ілюстрації")
            } footer: {
                Text("Без ключа історії шукаються на Christianity Today, IMB і у Вікіпедії. З ключем — ще на всіх сайтах списку через Brave Search (безкоштовний план). Ключ зберігається в Keychain (Return — зберегти). На ці сайти надсилаються лише до трьох англійських ключових слів із виділених віршів, після кліку «Ілюстрації».")
            }
            Section {
                SecureField("Ключ Claude API", text: $claudeKey)
                    .accessibilityIdentifier("claude-key")
                    .onSubmit(saveClaudeKey)
                    .onDisappear(perform: saveClaudeKey)
                HStack {
                    if claudeError {
                        Label("Не вдалося зберегти ключ", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    } else if let name = curatorName {
                        Label("Відбирає: \(name)", systemImage: "sparkles").foregroundStyle(.green)
                    } else {
                        Label("Без моделі: сортування за словами", systemImage: "key").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Link("Отримати ключ", destination: IllustrationNetwork.claudeKeyPage)
                        .accessibilityIdentifier("claude-key-link")
                }
                .accessibilityIdentifier("claude-key-status")
            } header: {
                Text("Відбір ілюстрацій моделлю")
            } footer: {
                Text("Модель формулює пошукові запити за змістом вірша, відкидає слабкі історії, сортує решту й пише «Чому ця історія» мовою перекладу. З ключем Claude (Haiku, ~0,5 цента за пошук) на api.anthropic.com ідуть посилання й текст виділених віршів KJV, мова перекладу, а також назви, сайти й перші 600 знаків знайдених історій — два запити на пошук. Без ключа — модель Apple на цьому Mac (macOS 26+ з Apple Intelligence), нічого не йде в мережу.")
            }

        }
        .formStyle(.grouped)
        // The form background is the theme, not the system gray (tech debt #18).
        .scrollContentBackground(.hidden)
        .background(ThemeBackground())
        .frame(width: 420)
        .navigationTitle("Налаштування")
    }

    private func saveClaudeKey() {
        claudeError = !KeychainKey.claude.save(claudeKey)
        claudeSaved = KeychainKey.claude.load() != nil
        curatorName = Curators.activeName
    }

    private func saveKey() {
        keyError = !KeychainKey.brave.save(braveKey)
        keySaved = KeychainKey.brave.load() != nil
    }
}
