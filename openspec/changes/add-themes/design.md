## Контекст

Після `add-reading-comfort` розміри шрифтів і масштаб живуть у `ReadingPreferences`/`PreferencesStore`. Кольори зараз системні.

## Рішення

- **Колір.** `ThemeColor` (hex → компоненти 0…1): відносна яскравість і контраст за WCAG 2.x; `composited(over:opacity:)` для напівпрозорих підкладок.
- **Токени.** `ThemeTokens`: `background` (під віршами), `sidebar`, `results`, `text`, `secondaryText`, `accent`, `verseNumber`, `searchHighlight`, `selection`, `copyButton`, `font` (`newYork`/`sfPro`/`ebGaramond`), `colorScheme` (light/dark), `plateOpacity` (1 або 0,92 для Скла), `usesGlass`, `textureOpacity` (0 або 0,07), `lineSpacing` (0,5 рядка → висота 1,5). Значення — з таблиці PRD 6.18.
- **Вибір.** `ThemeChoice`: `system` + п'ять тем; зберігається в `ReadingPreferences.theme` (стара збережена версія без поля → `system`). `ThemeChoice.resolve(systemIsDark:)` дає тему.
- **Доступність.** `Theme.tokens(for:reduceTransparency:increaseContrast:)`: зменшена прозорість → `plateOpacity` 1, `usesGlass` false, текстура 0; збільшений контраст → текст чисто чорний/білий, другорядний = основний, акцент затемнюється/висвітлюється до ≥ 7:1.
- **Тест контрасту.** Для кожної теми і кожної комбінації прапорців доступності: текст і номери віршів на фоні (для Скла — підкладка, накладена на чорне і на біле тло з її непрозорістю, береться гірший випадок), текст на панелях (бічна, результати), текст на підсвітці пошуку і на виділенні, акцент на фоні, кнопка копіювання (іконка з непрозорістю 0,6 на її підкладці).
- **SwiftUI.** `@Entry var theme: ThemeTokens` у середовищі; `ContentView` бере тему з `PreferencesStore` і `@Environment(\.colorScheme)` / `accessibilityReduceTransparency` / `colorSchemeContrast`; `.preferredColorScheme(tokens.colorScheme)` (крім `system`); `List` з `.scrollContentBackground(.hidden)` і фоном теми; `.tint(accent)`.
- **Скло.** Бічна панель і тулбар: `glassEffect` на macOS 26+, інакше `.ultraThinMaterial`; під віршами підкладка `#F2F4F8` × 0,92.
- **Манускрипт.** Шрифт реєструється через `ATSApplicationFontsPath = Fonts`. Текстура — `Canvas` з детермінованим генератором (seed): короткі волокна, кілька плям, радіальне потемніння по краях; `allowsHitTesting(false)`; лише під віршами, не в меню й списках.
- **Меню.** «Вигляд → Тема» з шістьма пунктами-перемикачами.
- **UI-тест.** Вибір теми в Settings змінює колір фону списку віршів (піксель правого поля рядка на скриншоті вікна) і переживає перезапуск.

## Ризики

- Колір виділення рядка `List` на macOS малює AppKit; `.tint` впливає не скрізь — виділення позначаємо власним фоном рядка.
- Точність пікселя на скриншоті: порівняння з допуском.
