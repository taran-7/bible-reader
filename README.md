# Bible Reader

A native macOS app (SwiftUI) for reading the Bible offline. Capstone of the fwdays course "Crash Course: Agentic Engineering" (2026).

## Features

- **Four translations:** KJV, Kralická, Ohienko (Огієнко), Synodal (Синодальний). The menu and ⌘⌥1…4 work on any keyboard layout. A new translation is added with one manifest line, no code changes.
- **Parallel view and "Compare":** a verse side by side in another translation; "Compare" shows the whole chapter in columns for the chosen translations, rows aligned by verse. The KJV ↔ Synodal numbering map also supports other systems via the manifest.
- **Navigation:** clicking a book or chapter title opens a grid of chapter numbers; ◀ ▶ and ⌘[ ⌘] move between chapters.
- **Search:** words in any form (stemming en/ru/uk/cs), exact phrase in quotes, scope (Bible, OT, NT, book), a "Found: N" counter with incremental loading. A reference (`Ин 3:16`, `Ів 3:16`, `John 3:16`) opens the passage.
- **Quotes:** ⌘C or the button on a selection copies verses with a reference in the translation's language.
- **Bookmarks, highlights, notes** with search and export.
- **Sermon illustrations:** live search for stories matching the selected verses (allowlisted WordPress sites, Wikipedia, Brave Search with your own key), "Translate" into the Bible's language on screen. Model curation: Claude with your own key, or the Apple on-device model, writes queries from the verse meaning, drops weak stories and explains "Why this story". The only network feature, and only after a click.
- **Sermon drafts:** a Markdown editor to the right of the text, "To draft" for verses and illustrations, live passage links, a sermon template, markers next to verses, a full-window "Sermon" mode, Markdown export, print / PDF.
- **Appearance:** a centered ~75-character text column, five themes (Light, Dark, Glass, Pastel, Manuscript), font size and interface scale, accessibility via VoiceOver and keyboard.

Requirements: macOS 14+, Apple Silicon.

## Build

```bash
make db
cd BibleReaderApp && xcodegen generate
xcodebuild -project BibleReaderApp/BibleReader.xcodeproj -scheme BibleReader build
```

Tests: `make test` (Swift Testing); UI tests and all gates run in CI.

## How Agentic Engineering is applied here

| Practice | Where to look |
|---|---|
| Context engineering | [AGENTS.md](AGENTS.md) is a map, not an encyclopedia. Static context: [ARCHITECTURE.md](ARCHITECTURE.md), [core-beliefs.md](docs/design-docs/core-beliefs.md). Dynamic: [HANDOFF.md](docs/exec-plans/active/HANDOFF.md), the state and next step, updated after every slice |
| Spec-driven development (SDD) | [OpenSpec](openspec/specs/): every slice is a `proposal` / `tasks` / delta spec, `openspec validate --strict` in CI, archive in [openspec/changes/archive](openspec/changes/archive/). FR/NFR requirements: [docs/requirements.md](docs/requirements.md) |
| Verification | 235 unit tests (Swift Testing) and UI tests (XCUITest) in CI; a coverage ratchet (never drops below baseline); requirement → test traceability ([traceability-report.md](docs/qa/traceability-report.md)); a network isolation check (NFR-2) |
| Maker ≠ checker | Separate reviewer agents in [.claude/agents](.claude/agents/) (code-reviewer, security-reviewer, spec-compliance-auditor, vision-judge…). Each slice's findings are in `review-findings.json` in the OpenSpec archive |
| Loops (loop engineering) | CI + Auto-fix: a failing check wakes the agent, it fixes and pushes on its own, the human only decides on merging. Factory gates: `npm run qa:verify` / `npm run gate:status` |
| Project Factory | [docs/project-factory.md](docs/project-factory.md): gates, slice trajectory ([trajectory-report.md](docs/qa/trajectory-report.md)) |

## Documentation

- For agents and developers: [AGENTS.md](AGENTS.md); current state: [HANDOFF.md](docs/exec-plans/active/HANDOFF.md)
- Architecture: [ARCHITECTURE.md](ARCHITECTURE.md)
- Product: [PRD](docs/product-specs/prd.md), [requirements](docs/requirements.md)
- Process (Project Factory): [docs/project-factory.md](docs/project-factory.md)
