# PRD: Bible Reader for macOS

Status: draft, 2026-09-25. Owner: Oleksandr Taraniuk.
The formal requirements of each stage live as an OpenSpec change (`openspec/changes/`); this document describes the product for humans and sets priorities.

## 1. Problem
A person who reads and studies the Bible on a Mac has two bad options. Websites need internet, are full of ads and are slow. BibleQuote and similar tools are outdated or do not work on macOS. What is missing is a lightweight native reader where you can find a passage in seconds, read it in several translations and quote it with a correct reference.

## 2. Users
- **Reader.** Reads a chapter a day; a comfortable font and quickly returning to where they stopped matter.
- **Student and preacher preparing sermons or lessons.** Searches for words and topics, compares translations, takes notes, copies quotes into documents.
- **Quoter.** Writes texts or posts; needs a quote with an exact reference in one click.

Interface language: Ukrainian. Texts: English (KJV), Russian (Synodal); later Ukrainian (Ohienko) and Czech (Bible kralická 1613).

## 3. Goals and metrics
| Goal | How we measure |
|---|---|
| Find a passage fast | from opening the app to the verse ≤ 5 s (reference in search) |
| Quote without errors | a quote always has the correct full book name and numbers; 0 manual fixes |
| Work offline | 100 % of features without network |
| Be fast | launch < 1 s, search < 200 ms over the whole Bible |
| Quality | `swift test` green; every feature has an OpenSpec change with tests |

## 4. Principles
- Native macOS, no accounts and no network. User data stays on their Mac. The only exception: illustrations (6.17), allowlisted sites only.
- Text comes first: minimal chrome, readable typography.
- Only public domain texts or texts with an explicit license.
- Logic lives in `BibleCore` and is covered by tests; the UI only renders state (see [core-beliefs](../design-docs/core-beliefs.md)).

## 5. What exists (v1.0, MVP)
Details: [bible-reader-mvp.md](bible-reader-mvp.md).
- KJV and Synodal, one translation on screen, a switcher in the toolbar.
- Navigation book → chapter, ◀ ▶ crossing between books.
- Search: a reference (`Ин 3:16`, `John 3`) leads to the passage, otherwise full-text search with highlighting (up to 200 results).
- Copying selected verses: ⌘C and a context menu, format `«текст» (От Иоанна 3:16-18)`.
- v1.1: font scale (6.1), interface scale (6.2), copy button (6.3), themes (6.18).
- v2.1 (partly): Ohienko (6.14; source bolls.life `UBIO`, 1962 edition, numbering aligned with KJV verse by verse) and Bible kralická (6.15); module format (6.16) not yet.

## 6. Roadmap
Priority: cheap things that improve daily reading first, then big features with new data.

### v1.1 Reading comfort
**6.1 Font scale.** Separate sizes for verse text and the book list. ⌘+ / ⌘− / ⌘0 for verse text; settings in Settings (⌘,). Values persist between launches.
Criterion: after a restart the sizes are the same; ⌘0 restores the default; long verses wrap without clipping.

**6.2 Interface scale.** An overall scale (toolbar, sidebar, search results) in Settings: "Small / Standard / Large / Extra large". Must respect the macOS system text size.
Criterion: all elements are readable at every level, nothing is clipped at a window width of 800 pt.

**6.3 Copy button.** When one or more verses are selected, a semi-transparent copy button appears in the top right corner of the selection (above the first selected verse). A click copies the quote in the same format as ⌘C; for ~1.5 s the button is replaced by a "Copied" label, then it comes back. The button does not cover verse text and becomes opaque on hover. "Copy reference only" is not done for now.
Criterion: no button without a selection; with a selection one click gives the same text as ⌘C.

**6.18 Themes.** Theme choice in Settings (⌘,) and the View menu; a theme changes the whole interface (verse text, sidebar, toolbar, search, 6.17 windows) and persists between launches. "System" switches Light/Dark following macOS. Five themes:

| Theme | Background | Text | Secondary text | Accent (selection, links) | Verse text font |
|---|---|---|---|---|---|
| Light | `#FFFFFF` | `#1C1C1E` (17:1) | `#6E6E73` (5.1:1) | `#0A66C2` (5.7:1) | New York (system serif) |
| Dark | `#121214` (not pure black, less "halo" around letters) | `#E8E6E3` (15:1) | `#9A9AA0` (6.7:1) | `#6CB4FF` (8.6:1) | New York |
| Glass (Liquid Glass style from iOS 26/27, macOS 26) | semi-transparent panels over blurred wallpaper; the backing under text `#F2F4F8` with ≥ 90 % opacity | `#101218` (17:1) | `#5A5F6B` (5.8:1) | `#1F57C8` (5.9:1) | SF Pro Text |
| Pastel | `#FFE9F3` (Lavender Blush); panels: `#F4BFDB` (Pastel Petal), results `#FFF5F9`, mint search highlight `#D6EDDD`; palette coolors.co/512d38-b27092-f4bfdb-ffe9f3 | `#512D38` (≥ 7.4:1) | `#7A3E5E` (≥ 4.9:1) | `#8C4A6E` (≥ 5.4:1) | New York |
| Manuscript | parchment `#EFE4CC` with texture: fine fibers, faint cracks and darkening at the edges | ink `#3B2A1A` (10.9:1) | `#6B5238` (5.8:1) | "cinnabar" `#8B2E1F` (6.6:1) for verse numbers and headings, like rubrics in manuscripts | an old-style serif with Cyrillic (candidate EB Garamond, OFL license, bundled with the app) |

Parentheses show WCAG contrast against the background; for all themes body text ≥ 7:1 (AAA), secondary and accent ≥ 4.5:1 (AA).
Readability rules:
- Transparency and blur only for "chrome" (toolbar, sidebar, 6.3/6.17 pop-up buttons); verse text sits on an almost opaque backing so the wallpaper does not reduce contrast.
- The manuscript texture is very faint (opacity ~5–10 %), with no fine detail under lines; menus and lists have no texture. A drop cap (a large decorative letter at the start of a chapter) is optional.
- Pastel colors only for backgrounds and panels; text is always dark, never pastel.
- Line height 1.4–1.6, text column width 60–80 characters; font scale (6.1) works in all themes.
- Search highlight and verse selection have their own color in every theme and stay visible.
- System accessibility settings: "Reduce transparency" makes Glass opaque, "Increase contrast" strengthens colors in all themes.
Logic: a theme is a set of tokens (colors, fonts, transparency, texture) in `BibleCore`; SwiftUI only applies the tokens. A test checks the contrast of every text/background pair of every theme.
Criterion: switching the theme changes the whole interface without a restart; the choice survives a restart; all color pairs pass the contrast test; VoiceOver and keyboard work the same in all themes.

### v1.2 Better search
**6.4 Morphology.** Searching `любовь` finds `любви`, `любовью`; `love` finds `loved`, `loveth`. A stemmer in `BibleCore`: Snowball for en/ru (KJV forms `-eth`/`-est` too), light stemmers for uk/cs (Snowball has none); a stem index.
**6.5 Filters.** Search scope: whole Bible / OT / NT / current book.
**6.6 All results.** Instead of the 200 limit, show the total count and load more on scroll; the label "Found: N".
**6.7 Phrase.** A quoted query searches for the exact phrase.
Stage criterion: tech debt #3 closed; search < 200 ms over the whole Bible.

### v1.3 Bookmarks, highlights, notes
**6.8 Bookmarks.** Save a verse or chapter; a bookmark list in the sidebar; jump in one click.
**6.9 Verse highlights.** Several colors, visible in the text.
**6.10 Notes.** A text note on a verse; an icon next to the verse; search over notes.
**6.11 Last position.** The app opens where the user stopped.
User data is stored in a separate local database (not in the read-only `bible.sqlite`), tied to book/chapter/verse so it survives text updates. Export to JSON/Markdown.
Criterion: bookmarks and notes survive a restart and a rebuild of `bible.sqlite`.

### v2.2 Illustrations (last)
**6.17 "Find illustrations" button.** "Illustration" here means a sermon illustration: a short true story (a biography, a historical event, a testimony) that explains or supports the point of the selected verses. Not pictures.
Next to the copy button (6.3), a second semi-transparent "Find illustrations" button appears on a selection of one or more verses. A click opens a separate window with stories for these verses: up to 7, most relevant first.
Under the hood: search is free, with no paid APIs and no control of third-party browsers. From the verse text and reference (`Ин 3:16-18`) we build English search queries (keywords, theme, people). Selection criteria: only documented events with real people, place and time; no invented parables or anecdotes; every story links to its source; duplicates are dropped.
Search (owner decision 2026-09-28):
- **Live search on click, no local index.** Stories are not stored: close the window and they are gone; to keep one, "Copy" and paste it into a note. Offline: the message "No network connection" and "Retry".
- **Sources:** WordPress REST (`/wp-json/wp/v2/search`) where it is open (Christianity Today, IMB); Wikipedia (MediaWiki API, biographies only: categories "… births/deaths", no Catholic or Orthodox categories); with the user's key, the Brave Search API (free plan) with `site:` over the whole allowlist, including sites closed to bots (Cloudflare). The Brave key is entered in Settings and stored in the Keychain; the `.app` does not contain it.
- Batches of 7, most relevant first; "Get more" continues the search (further pages, sources, broader queries).
- Card text: for copyrighted articles the first ≤ 1500 characters and "Read on site"; Wikipedia (CC BY-SA): the article intro; Brave: the search engine snippet.
- Rejected: scraping Google and DuckDuckGo pages (terms of use, bot protection), bypassing Cloudflare, controlling browsers, a hidden `WKWebView`; a local index (owner: no storage).
- No model-based selection or retelling of stories (owner decision 2026-09-28): a story is text from the page. Selection by "real people, place, time" only as far as the sources allow (Wikipedia: biographies).
Source rules:
- Search only English-language Baptist or Protestant (evangelical) resources: sites of churches, seminaries, missions, publishers, sermon illustration collections, missionary biographies.
- Orthodox and Catholic resources are forbidden: we do not search them or cite them as a source.
- Implementation: a domain allowlist in configuration (`Resources/illustration-sources.json`) plus a blocklist of Orthodox and Catholic domains as a fallback check ([illustration-sources.md](illustration-sources.md)); `BibleCore` drops any story with an address outside the allowlist. Wikipedia is neutral, so it additionally gets a category filter.
- Search in English by keywords from the KJV text of the same verses (for the Synodal, via the mapping table); stories are in English.
A panel to the right of the text in the same window (text 35 %, illustrations 65 %, draggable divider; owner decision 2026-09-28): a list of cards. A card has a title, site and date, text, a source link ("Read on site" for an excerpt). The "Copy" button on a card copies the story together with its source. During search an indicator; offline "No network connection", on error "Could not find illustrations", both with "Retry". "Get more" at the bottom.
The stories' language is English (the sources are English). The card has "Translate" into the on-screen Bible's language via Apple's system translator (Translation, on-device, macOS 15+, owner decision 2026-09-28); no retelling.
The logic (query building, parsing source responses, allowlist, Wikipedia filter, deduplication, batches of 7) lives in `BibleCore` behind the `IllustrationProvider` / `IllustrationHTTP` protocols and is tested without network on fixtures; network only in `IllustrationNetwork.swift`.
Criterion: no button without a selection; for John 3:16 and Rom 8:28 at most 7 stories, each with real people, a date or period and at least one working source link from the allowlist; no Orthodox or Catholic source; no invented stories in the check sample; no network requests before the click except index updates; offline, search over the already built index works.

### v1.5 Verse comparison
**6.19 "Compare".** Next to the copy button on a selection: a "Compare" button: a window with the selected verse (or verses) in all translations, each translation a separate panel side by side with the translation name and a reference in its language; clicking a translation opens that passage in it. An unneeded panel can be closed (×) and brought back via "+ Translation"; panels can be reordered left / right (by dragging or ◀ ▶). The set and order of panels persist between launches. KJV, Kralická and Ohienko share numbering, so they are matched by number; the Synodal gets a "numbering may differ" mark until the mapping table exists (6.13).
Criterion: for John 3:16 the window shows 4 translations; for Ps 23:1, KJV, Kralická, Ohienko with the same verse and the Synodal with the mark; a closed or reordered panel stays so after a restart.

### v2.0 Parallel view
**6.12 Two translations side by side.** Columns with verse-synchronized scrolling.
**6.13 Numbering mapping table.** KJV ↔ Synodal (Psalms, Job, Malachi, Romans 16 etc.), so parallel rows and translation switching lead to the same verse. Closes tech debt #1 and #4.
Criterion: KJV Ps 22:1 stands next to Synodal Ps 21:2; switching translation keeps the verse.

### v2.1 More translations
**6.14 Ukrainian Ohienko translation.** Source: getBible, code `ukrogienko` (https://api.getbible.net/v2/ukrogienko.json), marked Public Domain, "Ivan Ohienko translation 1930", OSIS format. Orthodox numbering (like the Synodal), so the parallel view with KJV relies on the mapping table (6.13).

**6.15 Czech Bible kralická (BKR, 1613).** Source: getBible, code `bkr` (https://api.getbible.net/v2/bkr.json), Public Domain, OSIS, KJV numbering: BKR ↔ KJV matched by book:chapter:verse key without a mapping table. Fallback: eBible.org `ces1613` (USFX/VPL). Czech names and abbreviations of the 66 books (`Gn`, `Ex`, `J`…) are needed for parsing references and quotes.

**6.16 Modules.** A format in which a new translation is added as data, without code changes: JSON + book descriptions + mapping table.
Criterion: a new translation is added with one file in `data/raw` and one configuration line; 66 books, control verses in tests (Быт 1:1 / Буття 1:1 / Genesis 1:1 / Gn 1:1, Ин 3:16 / Ів. 3:16 / J 3:16).
Order: BKR first (KJV numbering, cheapest), then Ohienko (after 6.13).

### v2.3 Sermon drafts
**6.20 Drafts.** A place for a sermon draft or a few thoughts next to the text: a list and a Markdown editor on the right, a verse into the draft in one click, live passage links, a sermon template, illustrations into the draft, markers next to verses, a "Sermon" mode and export (Markdown, print / PDF). Owner request 2026-09-28.
Criterion: a draft with John 3:16 survives a restart; "1 Кор 13:4-7" in the text marks verses 4–7 and opens the passage on click.

## 7. Non-functional requirements
- macOS 14+, Apple Silicon only. Intel is out of scope: the project is open source, whoever needs it can build it.
- Offline; no telemetry. Network only for illustrations (6.17): index updates and live search, only to allowlisted domains; the request carries only the search query text.
- Accessibility: VoiceOver reads verse numbers and texts; full keyboard operation; WCAG AA contrast in the light and dark themes.
- App size < 100 MB (60 MB had no technical reason; each translation adds ~8–10 MB of database).

## 8. Out of scope
- Sync between devices, accounts, an iOS version.
- Audio Bible, commentaries, Strong's dictionaries (maybe after v2).
- Social features.

## 9. Risks and open questions
- **Rights to Ohienko.** getBible marks the text as Public Domain, but Ohienko died in 1972, and in Ukraine copyright lasts 70 years after the author's death. Before release, check which edition (1930 or 1962) and whose text; fallback: Kulish–Puluj–Nechuy-Levytsky (1905).
- **The getBible format differs from the current one** (`thiagobodruk`): a converter in `scripts/` or an OSIS import is needed; getBible's KJV contains Strong's numbers, so we keep our KJV from `thiagobodruk`.
- **The mapping table** is complex and only partly available from open sources; disputed places may have to be assembled by hand.
- **Stemming** can add noise (extra matches); an "exact form" switch is needed.
- **Illustrations (6.17): fabrication.** If a model does the selection or retelling, it may "invent" a story or a source. Retell only from the text of the found page, always link to it; a "check the source" mark in the UI. Well-known "sermon" stories are often apocryphal; such stories are filtered out.
- **Illustrations: source allowlist.** A narrow domain list may yield few results for rare passages; then we show what was found (fewer than 7) rather than widening the search. A site's denomination is determined manually when adding it to the list, never guessed automatically.
- **Illustrations: site adapters and index.** A change in a site's layout or API breaks the adapter; caught by nightly Playwright monitoring in CI and fixtures in tests. A sitemap crawl must respect `robots.txt` and not load the sites (a pause between requests). Index size and update frequency are decided before implementation.
- **Illustrations: selection and retelling.** Apple Foundation Models needs macOS 26+ and Apple Intelligence, while the PRD requires macOS 14+; older systems show found stories without retelling (title, excerpt, link).
- **Illustrations: copyright.** We show our own short retelling and a link, not full article texts.
- **Themes (6.18): Glass.** Real Liquid Glass (`glassEffect`) exists only since macOS 26; on macOS 14–15 it is replaced with system materials (`.ultraThinMaterial`), and the look is simpler. Contrast on transparent panels depends on the wallpaper, so text sits only on almost opaque backings.
- **Themes: Manuscript.** Needs a free parchment texture (our own or CC0) and a font with Cyrillic and Latin under the OFL; check that the texture and font fit into the app size limit (< 100 MB).
- **Stage order.** v1.3 and v2.0 can be swapped if the parallel view matters more than notes.

## 10. How we work
Every roadmap item becomes a separate OpenSpec change (`/opsx:propose`), a `feature/NN-<change>` branch, TDD, a manual UI check against a checklist, a diff review before the PR.

## 11. Future process improvements
Not product features: tooling around the repository, to be installed by the owner as GitHub Apps (free for public repositories).
- **CodeRabbit (automated AI review of every PR).** A second, independent reviewer on every PR, including hand-made changes; strengthens maker ≠ checker beyond the in-repo reviewer agents (`.claude/agents/`), which use the same model and run only when a slice is closed. Setup: install the app for `taran-7/bible-reader`, add `.coderabbit.yaml` (ignore generated files: `.xcodeproj`, `trace/`, `docs/qa/*-report.md`; point it at `AGENTS.md` rules), let Auto-fix handle its comments, record as a PD entry.
- **GitGuardian (secret scanning).** A second layer over `scripts/check-secrets.mjs` (PD-18, PD-19): 400+ detectors, validity checks, alerts when a secret reaches GitHub. Our scanner knows only the patterns we wrote (Anthropic, Brave, GitHub, AWS…). Setup: install the app for the repository; no config needed.
