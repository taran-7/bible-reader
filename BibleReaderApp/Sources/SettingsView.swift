import BibleCore
import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: PreferencesStore
    @State private var braveKey = BraveKey.load() ?? ""

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
                    .onSubmit { BraveKey.save(braveKey) }
                    .onChange(of: braveKey) { _, key in BraveKey.save(key) }
            } header: {
                Text("Ілюстрації")
            } footer: {
                Text("Без ключа історії шукаються на Christianity Today, IMB і у Вікіпедії. З ключем — ще на всіх сайтах списку через Brave Search (безкоштовний план). Ключ зберігається в Keychain.")
            }
        }
        .formStyle(.grouped)
        // Фон форми — тема, а не системний сірий (tech debt #18).
        .scrollContentBackground(.hidden)
        .background(ThemeBackground())
        .frame(width: 420)
        .navigationTitle("Налаштування")
    }
}
