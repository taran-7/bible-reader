## ADDED Requirements

### Requirement: Шлях до бази для тестів
Додаток SHALL відкривати базу за шляхом зі змінної середовища `BIBLE_READER_DB`, якщо вона задана й непорожня; інакше SHALL відкривати `bible.sqlite` з бандла.

#### Scenario: Змінна середовища вказує на відсутній файл
- **WHEN** додаток запущено з `BIBLE_READER_DB=/nonexistent/bible.sqlite`
- **THEN** показано екран помилки бази

#### Scenario: Змінна не задана
- **WHEN** `BIBLE_READER_DB` не задана
- **THEN** відкривається база з бандла
