# ADR-0001: Keep the existing Swift stack and adapt Project Factory to it

- **Status:** accepted
- **Date:** 2026-09-25

## Context

Project Factory is installed onto an existing project (`/project-factory:onboard`). The factory
targets Node/Next.js (Vitest, Playwright, ESLint, tsc), while Bible Reader
is a Swift package `BibleCore` + a SwiftUI app (XcodeGen), tests in Swift Testing,
SQLite FTS5, no network.

## Decision

We do not migrate the stack. Node is needed only for the deterministic `scripts/*.mjs`;
`package.json` has no runtime dependencies. Adaptations (all recorded in `factory-lock.json`):

- Product code: `Sources/`, `BibleReaderApp/`, `.swift` extension; tests: `Tests/**/*Tests.swift`.
  Without this, the checks would not see Swift code and would report empty "PASS" results.
- Modules for `check-trajectory`: `Sources/<Module>/`.
- pre-commit: `swift build` instead of ESLint/tsc; commit-msg requires a trailer for changes in `Sources/`, `BibleReaderApp/`.
- The `qa-verify` set: `make test`, coverage via llvm-cov (`scripts/swift-coverage-summary.mjs`),
  build via `xcodebuild`; no Playwright, video recordings, a11y scanner or pixel parity.
- CI on `macos-15`.
- Not installed: `check-recordings`, `record-demos`, `check-a11y`, `check-visual-fidelity`
  (web-specific), the Claude Code ESLint PostToolUse hook, Cursor/Codex/Copilot adapters.
  The lessons `block-conquest-doctrine`, `capture-determinism`, `sampling-blindness` are not
  inserted into AGENTS.md: they are about web page pixel parity.

## Consequences

- UI evidence (FR-10, FR-14, NFR-4) was manual at first; automating it needs XCUITest,
  which is a separate slice.
- Updating scripts from upstream requires re-adaptation and a commit with `Refs: PD-x`.
