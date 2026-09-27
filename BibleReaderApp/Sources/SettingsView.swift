import BibleCore
import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: PreferencesStore

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
            Button("Скинути до стандартних") { preferences.reset() }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .navigationTitle("Налаштування")
    }
}
