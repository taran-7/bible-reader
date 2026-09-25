# Handoff: де ми зараз

> Для AI-агента: прочитай цей файл першим, коротко перекажи користувачу стан і скажи наступний крок. Після кожного завершеного кроку онови цей файл.

Оновлено: 2026-09-25.

## Стан
- Гілка: `feature/01-bible-reader-mvp` (запушена, PR ще немає).
- OpenSpec change: `bible-reader-mvp`, прогрес 22/27 (`openspec instructions apply --change bible-reader-mvp --json`).
- `swift test`: 56 тестів зелені. `BibleCore` (імпорт, репозиторій, посилання, пошук, `ReaderViewModel`) готовий.
- Додаток `BibleReaderApp` збирається (`xcodebuild -project BibleReaderApp/BibleReader.xcodeproj -scheme BibleReader build`), але UI ще ніхто не перевіряв очима.
- Xcode 27.0 встановлено; XcodeGen встановлено (`brew install xcodegen`).

## Зараз: ручна перевірка UI (робить користувач)
Відкрити `BibleReaderApp/BibleReader.xcodeproj` у Xcode, ⌘R. Відмічати, що працює:

**7.3 Навігація**
- [ ] Бічна панель: книги в секціях «Старий Заповіт» / «Новий Заповіт».
- [ ] Genesis 50 → ▶ відкриває Exodus 1.
- [ ] На Genesis 1 кнопка ◀ неактивна.
- [ ] Вибір розділу в тулбарі працює.
- [ ] Перемикач KJV → Синодальний: та сама книга й розділ, назви книг російською.

**7.4 Пошук**
- [ ] `love` у KJV: є результати, слово підсвічене.
- [ ] `любовь` у Синодальному: є результати.
- [ ] `любовь` у KJV: «Нічого не знайдено».
- [ ] `Ин 3:16`: відкривається Иоанна 3, вірш 16 виділено і видно.
- [ ] Клік по результату відкриває цей вірш.

**7.5 Копіювання**
- [ ] Виділити Ин 3:16–18 (Shift-клік), ⌘C → у буфері `«…» (Ин. 3:16-18)`.
- [ ] Те саме через правий клік → «Копіювати».

**7.6 Помилка бази**
- [ ] У зібраному `.app` (`Show in Finder` → Show Package Contents → Contents/Resources) перейменувати `bible.sqlite`, запустити `.app`: екран «Не вдалося відкрити базу», без падіння.

## Що далі (для агента)
1. Спитати користувача результати перевірки вище.
2. Якщо щось не працює: виправити в `BibleReaderApp/Sources/` або `Sources/BibleCore/` (логіка тільки в `BibleCore`, спершу червоний тест), перезібрати, попросити перевірити ще раз.
3. Коли все ок: відмітити 7.3–7.6 у `openspec/changes/bible-reader-mvp/tasks.md` (`/opsx:apply`).
4. Задача 8.2: `swift test`, рецензія diff гілки відносно `main`, виправлення.
5. Коміт, пуш, PR у `main`; потім `/opsx:archive`, план `docs/exec-plans/active/bible-reader-mvp.md` перенести в `completed/`.
6. Далі за планом: крок 8 (харнес: `.claude/agents/reviewer.md`, `make check`) і крок 9 (README сабмішену, відео робить користувач).

## Корисне знати
- База `bible.sqlite` не комітиться; генерується `make db` або pre-build скриптом Xcode.
- `.xcodeproj` генерується з `BibleReaderApp/project.yml` (`cd BibleReaderApp && xcodegen generate`), руками не правити.
- Відомі обмеження: `docs/exec-plans/tech-debt-tracker.md`.
- Користувач спілкується українською.
