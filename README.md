# Bible Reader

Нативний macOS-додаток (SwiftUI) для читання Біблії офлайн. Capstone курсу fwdays «Crash Course: Agentic Engineering» (2026).

## Що вміє

- **Чотири переклади:** KJV, Kralická, Огієнко, Синодальний. Меню й ⌘⌥1…4 працюють на будь-якій розкладці. Новий переклад додається рядком маніфесту, без змін коду.
- **Паралельний перегляд і «Порівняти»:** вірш поруч в іншому перекладі; «Порівняти» показує весь розділ колонками по вибраних перекладах, рядки вирівняні за віршами. Таблиця відповідностей нумерації KJV ↔ Синодальний підтримує й інші системи через маніфест.
- **Навігація:** клік по книзі або назві розділу відкриває сітку номерів розділів; ◀ ▶ і ⌘[ ⌘] переходять між розділами.
- **Пошук:** слова в будь-якій формі (стемінг en/ru/uk/cs), точна фраза в лапках, область (Біблія, СЗ, НЗ, книга), лічильник «Знайдено: N» з довантаженням. Посилання (`Ин 3:16`, `Ів 3:16`, `John 3:16`) відкриває місце.
- **Цитати:** ⌘C або кнопка на виділенні копіює вірші з посиланням мовою перекладу.
- **Закладки, підсвітки, нотатки** з пошуком і експортом.
- **Ілюстрації до проповіді:** живий пошук історій до виділених віршів (WordPress-сайти з allowlist, Вікіпедія, Brave Search з власним ключем), «Перекласти» мовою Біблії на екрані. Єдина мережева функція, лише після кліку.
- **Чорнетки проповідей:** редактор Markdown праворуч від тексту, «В чорнетку» для віршів та ілюстрацій, живі посилання на місця, шаблон проповіді, позначки біля віршів, режим «Проповідь» на все вікно, експорт у Markdown, друк / PDF.
- **Оформлення:** колонка тексту ~75 знаків по центру, п'ять тем (Світла, Темна, Скло, Пастельна, Манускрипт), розмір шрифтів і масштаб інтерфейсу, доступність з VoiceOver і клавіатури.

Вимоги: macOS 14+, Apple Silicon.

## Збірка

```bash
make db
cd BibleReaderApp && xcodegen generate
xcodebuild -project BibleReaderApp/BibleReader.xcodeproj -scheme BibleReader build
```

Тести: `make test` (Swift Testing), UI-тести і всі гейти — у CI.

## Як тут застосовано Agentic Engineering

| Практика | Де подивитися |
|---|---|
| Контекст-інженерія | [AGENTS.md](AGENTS.md) — карта, а не енциклопедія. Статичний контекст: [ARCHITECTURE.md](ARCHITECTURE.md), [core-beliefs.md](docs/design-docs/core-beliefs.md). Динамічний: [HANDOFF.md](docs/exec-plans/active/HANDOFF.md) — стан і наступний крок, оновлюється після кожного слайсу |
| Специфікації наперед (SDD) | [OpenSpec](openspec/specs/): кожен слайс — `proposal` / `tasks` / delta-спека, `openspec validate --strict` у CI, архів у [openspec/changes/archive](openspec/changes/archive/). Вимоги FR/NFR — [docs/requirements.md](docs/requirements.md) |
| Верифікація | 235 unit-тестів (Swift Testing) і UI-тести (XCUITest) у CI; ratchet покриття (не падає нижче бази); трасування вимога → тест ([traceability-report.md](docs/qa/traceability-report.md)); перевірка ізоляції мережі (NFR-2) |
| Maker ≠ checker | Окремі агенти-рецензенти в [.claude/agents](.claude/agents/) (code-reviewer, security-reviewer, spec-compliance-auditor, vision-judge…). Знахідки кожного слайсу — `review-findings.json` в архіві OpenSpec |
| Цикли (loop engineering) | CI + Auto-fix: падіння перевірки будить агента, він виправляє й пушить сам, людина лише вирішує про мерж. Гейти фабрики `npm run qa:verify` / `npm run gate:status` |
| Project Factory | [docs/project-factory.md](docs/project-factory.md): гейти, траєкторія слайсів ([trajectory-report.md](docs/qa/trajectory-report.md)) |

## Документація

- Для агентів і розробників: [AGENTS.md](AGENTS.md), поточний стан — [HANDOFF.md](docs/exec-plans/active/HANDOFF.md)
- Архітектура: [ARCHITECTURE.md](ARCHITECTURE.md)
- Продукт: [PRD](docs/product-specs/prd.md), [вимоги](docs/requirements.md)
- Процес (Project Factory): [docs/project-factory.md](docs/project-factory.md)
