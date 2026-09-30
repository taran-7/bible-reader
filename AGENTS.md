# AGENTS.md

Bible Reader: a native macOS app (SwiftUI) for reading the Bible (KJV, Synodal and other translations). Capstone of the fwdays course "Agentic Engineering".

This file is a map, not an encyclopedia. Details live in `docs/`.

## Where to look
- **Start with [docs/exec-plans/active/HANDOFF.md](docs/exec-plans/active/HANDOFF.md)**: current state and next step.
- [ARCHITECTURE.md](ARCHITECTURE.md): modules, boundaries, data flow.
- [docs/design-docs/core-beliefs.md](docs/design-docs/core-beliefs.md): principles we hold to.
- [docs/product-specs/](docs/product-specs/index.md): what we build (user-facing behavior).
- [docs/exec-plans/active/](docs/exec-plans/active/): the current execution plan. Finished plans move to `completed/`.
- [docs/exec-plans/tech-debt-tracker.md](docs/exec-plans/tech-debt-tracker.md): known limitations and debt.
- [docs/generated/db-schema.md](docs/generated/db-schema.md): DB schema (generated, do not edit by hand).
- `openspec/`: changes in OpenSpec format (`/opsx:propose`, `/opsx:apply`, `/opsx:archive`).

## Rules
- Documentation, specs, code comments, commit messages and PR descriptions are written in English. The app UI and Bible texts keep their own languages.
- TDD: a red test in `BibleCoreTests` first, then the implementation.
- `swift test` must be green before committing.
- Logic lives in `BibleCore`; the SwiftUI layer only renders state and calls `BibleRepository`.

## Commands
- `make test`: `swift test` (adds Swift Testing paths when only Command Line Tools are active). Tests use Swift Testing (`import Testing`).
- `make db`: `swift run bible-import data/raw BibleReaderApp/Resources/bible.sqlite`.
- `python3 scripts/convert_synodal.py RusSynodal.json data/raw/ru_synodal.json`: regenerate the Synodal translation (see `data/raw/SOURCE.md`).
- `cd BibleReaderApp && xcodegen generate`: regenerate `BibleReader.xcodeproj` from `project.yml` (never edit `.xcodeproj` by hand).
- `xcodebuild -project BibleReaderApp/BibleReader.xcodeproj -scheme BibleReader build`: build the app; a pre-build script generates the database if it is missing.

## Project Factory

The agent factory loop (gates, agents in `.claude/agents/`, `scripts/check-*.mjs`) is described in [docs/project-factory.md](docs/project-factory.md). `npm run qa:verify` runs the full check battery, and `npm run gate:status` shows gate status.

<!-- BEGIN-FACTORY-LESSONS -->
<!-- BEGIN-LESSON-vacuous-pass-not-earned -->
### Lesson: a PASS over zero evidence is NOT-EARNED (vacuous-pass-not-earned, v1)

- Never report a gate or check as PASS when its evidence scope is 0 ("Scope: 0
  clip(s)", empty archive, no eval results) while product code exists under
  `app/`, `src/`, `lib/`, `server/`, or `packages/`. Render it **NOT-EARNED**
  and exit non-zero.
- Before product code exists, an empty scope is **SKIP-pending**: print it
  explicitly; it is visible and never counted as PASS.
- Never fold SKIP / 0-scope results into an overall "Pass" summary
  (`qa-verify`, `gate-status`). Field evidence: `worst()` folded SKIP into
  PASS and G4–G8 rendered green over literally nothing
  (2026-07-02-pixel-perfect-forensics.md, RC2).
<!-- END-LESSON-vacuous-pass-not-earned -->

<!-- BEGIN-LESSON-declared-method-needs-mechanism -->
### Lesson: a declared acceptance method needs an executable mechanism (declared-method-needs-mechanism, v1)

- Every FR/NFR that declares a verification method (pixel-diff, e2e,
  recording, a11y, eval, ...) must resolve to a real, executable, non-stub
  mechanism BEFORE the build phase starts: an installed check script, or a
  package.json script whose body does not match
  `/^echo |^true$|not yet configured/i`.
- A spec file that restates the requirement is NOT a mechanism. Field
  evidence: NFR-19 encoded "≥ 99% pixel match" while no pixel-diff tool
  existed anywhere and `test:e2e` was an echo stub exiting 0
  (2026-07-02-pixel-perfect-forensics.md, RC1).
- If a declared method has no mechanism, do not proceed: implement the check,
  or record an explicit human waiver — never let the declaration float
  unverifiable into the build.
<!-- END-LESSON-declared-method-needs-mechanism -->

<!-- BEGIN-LESSON-done-claims-need-evidence -->
### Lesson: done-claims need evidence pointers (done-claims-need-evidence, v1)

- Never write strong completion language ("Convergence reached", "all gates
  pass", "verification-only", "Overall result: Pass", "ready for release /
  sign-off", "done", "complete") into current-state.md, PR bodies, or handoff
  docs unless the same line carries a resolvable evidence pointer — a path
  that exists on disk (e.g. `docs/qa/automated-verification-latest.md`) and
  is fresh — or an explicit "Scope NOT delivered" section.
- The verdict belongs to exit-coded checks, not narrative. Field evidence:
  "Convergence reached … verification-only" was written while the same file
  admitted the formal acceptance was never run
  (2026-07-02-pixel-perfect-forensics.md, RC6).
- When you catch an unbacked claim, treat it as a correction event: file it,
  do not silently rewrite it.
<!-- END-LESSON-done-claims-need-evidence -->

<!-- END-FACTORY-LESSONS -->
