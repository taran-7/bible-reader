# illustrations Specification

## Purpose
Shows real illustration stories for the selected verses from allowed Protestant sources and Wikipedia: live search on click, no index and no storage.

Requirements in [docs/requirements.md](../../../docs/requirements.md): FR-33, FR-34, FR-35, NFR-2.

## Requirements

### Requirement: Illustrations window
The «Пошук ілюстрацій» (Find illustrations) button on a selection of one or more verses and the context menu item of the same name SHALL open, in the same window, a panel to the right of the text (text 35 %, panel 65 %, the divider is draggable and remembered; ✕ or Esc closes it; a new request replaces the content) with at most 7 stories for these verses: title, site and date, text and a source link. «Отримати ще» (Get more) SHALL load the next up to 7 stories without repeats while any are found. The «Скопіювати» (Copy) button on a card SHALL put the title, text and source on the clipboard. If the on-screen Bible translation is not English, the card SHALL have «Перекласти» (Translate; into that translation's language, on-device, macOS 15+) and «Оригінал» (Original); «Скопіювати» SHALL take what is currently on the card. Stories SHALL NOT be stored (FR-33).

#### Scenario: First batch and "Get more"
- **WHEN** the sources find 12 stories and the user opens the window
- **THEN** 7 cards and the «Отримати ще» button are shown
- **WHEN** the user presses «Отримати ще»
- **THEN** the remaining 5 are added without repeats, and the «Отримати ще» button is gone

#### Scenario: No network
- **WHEN** there is no network
- **THEN** the window shows «Немає підключення до мережі» (No network connection) and «Повторити» (Retry)

#### Scenario: Site error
- **WHEN** a site responds with an error
- **THEN** the window shows «Не вдалося знайти ілюстрації» (Could not find illustrations) with an explanation and «Повторити»

#### Scenario: Copying
- **WHEN** the user presses «Скопіювати» on a card
- **THEN** the clipboard contains the title, text and the line `Джерело: <site>, <address>`

#### Scenario: Translation
- **WHEN** Ohienko is on screen and the user presses «Перекласти»
- **THEN** the card title and text are in Ukrainian, the button reads «Оригінал», and «Скопіювати» takes the Ukrainian text with the English source link

### Requirement: Allowed sources only
A story SHALL be shown only from an https address in an allowlisted domain; blocklisted domains (Catholic and Orthodox) SHALL be dropped, even if they are subdomains of the allowlist. On Wikipedia only biographies (category "… births" or "… deaths") SHALL remain, without categories containing the words catholic, orthodox, pope, saint, cardinal, monk, nun, monastery, patriarch, jesuit, franciscan, dominican, benedictine, beatified, canonized, venerated (FR-34).

#### Scenario: A link outside the allowlist
- **WHEN** a post on an allowlisted site links to `catholic.com`
- **THEN** the story is dropped

#### Scenario: Wikipedia
- **WHEN** Wikipedia finds an article about the verse, a biography of a Protestant evangelist and a biography of a Catholic saint
- **THEN** only the evangelist's biography is shown

### Requirement: Live search without an index
The app SHALL NOT make network requests before the button is clicked and SHALL NOT have a local illustration index. Search SHALL run in English by keywords from the KJV text of the selected verses in the WordPress REST of the configured sites, in Wikipedia and, if the user entered a Brave Search key in Settings, in Brave Search with `site:` over the allowlist. For copyrighted articles the card SHALL show at most the first 1500 characters and a «Читати на сайті» (Read on site) link (FR-35).

#### Scenario: A query without meaningful words
- **WHEN** the selection has no words to build a query from
- **THEN** there are no network requests, the window shows «Нічого не знайдено» (Nothing found)

#### Scenario: A long article
- **WHEN** the post text is longer than 1500 characters
- **THEN** the card shows its beginning up to a paragraph or sentence boundary and «Читати на сайті»

### Requirement: Model curation of illustrations
If a model is available (Claude with the user's key in the Keychain; without a key, the Apple on-device model), illustration search SHALL: first ask the model to write up to 3 English search queries on the theme of the selected verses and search with them first; score candidates in a pool of up to 21 (0–10) and show only those scoring ≥ 6, best first, 7 at a time; show on the card the line «Чому ця історія: …» (Why this story) in the language of the Bible translation the search was opened from; under the stories, «Відібрано моделлю: <name>» (Curated by model). If the model did not respond or its response could not be parsed, search SHALL continue without it (as without a model) with the mark «Без відбору моделлю — <reason>» (Without model curation). Without a model the behavior is unchanged (FR-41).

#### Scenario: Model queries
- **WHEN** the model returns the query "loving enemies story" for Matt 5:44
- **THEN** the first query to the sites is "loving enemies story"

#### Scenario: Curation and ordering
- **WHEN** the model scored 21 candidates, some below 6
- **THEN** up to 7 stories scoring ≥ 6 are shown, highest first, each with a «Чому ця історія» line in the translation's language

#### Scenario: Model unavailable
- **WHEN** Claude responds «недійсний ключ API» (invalid API key)
- **THEN** the stories are shown without curation, and under them «Без відбору моделлю — Claude: недійсний ключ API»
