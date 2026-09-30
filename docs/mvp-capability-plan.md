# Capability plan

Every requirement has exactly one owner. The baseline (v1.0) was built before the factory
onboarding, so its slice is marked as retrofitted in `.project-factory/retrofit.json`.

## Baseline (v1.0, retrofitted)

| Slice | Capability (spec) | Requirements | Status |
|---|---|---|---|
| `bible-reader-mvp` | `bible-text-import` | FR-1, FR-2, FR-3 | archived 2026-09-25 |
| `bible-reader-mvp` | `bible-reading` | FR-4, FR-5, FR-6, FR-7 | archived 2026-09-25 |
| `bible-reader-mvp` | `scripture-reference` | FR-8, FR-9, FR-10 | archived 2026-09-25 |
| `bible-reader-mvp` | `bible-search` | FR-11, FR-12, FR-13, FR-14 | archived 2026-09-25 |

## New work (every slice goes through the full G4 loop)

Order per [PRD](product-specs/prd.md) §6. The owner approved the plan on 2026-09-27: v1.3 goes before v2.0; v1.1 is split into three slices (1, 1a, 1b).

| # | Slice (OpenSpec change) | Requirements | Dependency | Parallelism |
|---|---|---|---|---|
| 0 | `add-platform-checks` | NFR-1, NFR-2, NFR-5 | — | done 2026-09-27 (archive `2026-09-27-add-platform-checks`) |
| 0a | `add-ui-tests` (XCUITest) | FR-7, FR-10, FR-13, FR-14 (UI evidence) | — | done 2026-09-27 (archive `2026-09-27-add-ui-tests`) |
| 0b | `add-a11y-launch-checks` | NFR-3 (launch < 1 s), NFR-4 (VoiceOver, keyboard) | 0a | done 2026-09-28 (archive `2026-09-28-add-a11y-launch-checks`) |
| 1 | `add-reading-comfort` (v1.1) | FR-15, FR-16 | — | done 2026-09-27 (archive `2026-09-27-add-reading-comfort`) |
| 1a | `add-copy-button` (v1.1) | FR-17 | 1 | done 2026-09-27 (archive `2026-09-27-add-copy-button`) |
| 1b | `add-themes` (v1.1) | FR-31, FR-32, NFR-4 (contrast, including the copy button at 0.6) | 1 (font scale in all themes) | done 2026-09-27 (archive `2026-09-27-add-themes`; the a11y part of NFR-4 is in 0b) |
| 2 | `improve-search` (v1.2) | FR-18, FR-19, FR-20, FR-21, NFR-3 (search < 200 ms) | — | done 2026-09-28 (archive `2026-09-28-improve-search`) |
| 3 | `add-user-notes` (v1.3) | FR-22, FR-23, FR-24, FR-25 | — | done 2026-09-28 (archive `2026-09-28-add-user-notes`) |
| 3a | `add-verse-compare` (v1.5) | FR-36 | 1a (button next to copy) | done 2026-09-28 (archive `2026-09-28-add-verse-compare`) |
| 5 | `add-parallel-view` (v2.0) | FR-26, FR-27 | — | done 2026-09-28 (archive `2026-09-28-add-parallel-view`) |
| 6 | `add-translations` (v2.1) | FR-28, FR-29 | — (Ohienko numbering = Synodal; only the parallel view needs the table) | done 2026-09-27 (archive `2026-09-27-add-translations`) |
| 6a | `add-translation-modules` (v2.1) | FR-30 | 6 | done 2026-09-28 (archive `2026-09-28-add-translation-modules`) |
| 6b | `chapter-picker-popover` (v2.1) | FR-37 | — | done 2026-09-28 (archive `2026-09-28-chapter-picker-popover`) |
| 4 | `add-illustrations` (v2.2) | FR-33, FR-34, FR-35 | 1a (button next to 6.3) | done 2026-09-28 (archive `2026-09-28-add-illustrations`) |
| 7 | `add-sermon-drafts` (v2.3) | FR-38, FR-39, FR-40 | 1a (button on the selection), 4 (illustration card) | done 2026-09-28 (archive `2026-09-28-add-sermon-drafts`) |
| 4b | `add-illustration-curation` (v2.4) | FR-41 | 4 | done 2026-09-29 (archive `2026-09-29-add-illustration-curation`) |

NFR mechanisms (approved 2026-09-27):

| NFR | Mechanism |
|---|---|
| NFR-1 | `check-platform` script: `MACOSX_DEPLOYMENT_TARGET` = 14.0 and the binary's `lipo -archs` is exactly arm64 (Apple Silicon, owner decision 2026-09-27) |
| NFR-2 | `@trace NFR-2` test: no `URLSession`/`Network` in `Sources/` except the illustrations module (FR-33…35) |
| NFR-3 | Search: a timed test on the real database (`improve-search`); launch: measured in XCUITest (`add-a11y-launch-checks`) |
| NFR-4 | XCUITest (`add-a11y-launch-checks`): accessibility labels and keyboard operation; contrast: theme token test (FR-32) |
| NFR-5 | `check-platform` script: `.app` size after a Release build < 100 MB |

An NFR becomes an MVP row together with the slice that adds its mechanism.
