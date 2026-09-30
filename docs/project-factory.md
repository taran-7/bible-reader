# Project Factory

The agent factory loop from [taran-7/project-factory](https://github.com/taran-7/project-factory)
(a fork of koldovsky/project-factory), installed via `onboard`. The Swift
adaptations are described in [ADR-0001](adr/0001-adopt-swift-stack.md).

## What is where

| What | Where |
|---|---|
| Agents (requirements-analyst, spec-writer, test-engineer, capability-implementer, code-reviewer, security-reviewer, spec-compliance-auditor, qa-documenter, process-auditor…) | `.claude/agents/` |
| Workflows (spec-pipeline, review-gate, trajectory-eval, eval-suite, uat-triage) | `.claude/workflows/` |
| Deterministic checks | `scripts/check-*.mjs`, `scripts/qa-verify.mjs`, `scripts/gate-status.mjs` |
| Requirements with IDs | [requirements.md](requirements.md) |
| Slice plan | [mvp-capability-plan.md](mvp-capability-plan.md) |
| Machine-readable phase state | [current-state.md](current-state.md) |
| Generated reports (do not edit by hand) | `docs/qa/traceability-report.md`, `docs/qa/trajectory-report.md`, `trace/` |
| Hash lock of gate scripts | `factory-lock.json` |

## Chain rules

- A spec cites its FRs (`FR-n`), a test is tagged `// @trace FR-n`.
- A commit that changes `Sources/` or `BibleReaderApp/` has a `Slice: <change>` or `Refs: FR-n` trailer.
- Changing a gate script requires a commit with `Refs: PD-x`, otherwise `check:integrity` is red.

## Commands

- `npm run qa:verify`: the full check battery, report in `docs/qa/automated-verification-latest.md`.
- `npm run gate:status`: computed status of gates G0–G8.
- `npm run check:trace`: the FR → spec → plan → test chain.
- `make coverage && npm run check:coverage`: coverage ratchet.

## Open questions after onboarding (2026-09-26)

1. ~~**Baseline sign-off.**~~ Closed 2026-09-27: FR-1…FR-14 and the plan confirmed, v1.3 before v2.0. Was: the owner had not yet confirmed [requirements.md](requirements.md) (FR-1…FR-14 as ASSUMPTION) and the [slice plan](mvp-capability-plan.md). Until then G1 and G3 stand as "needs sign-off".
2. ~~**New PRD items not in the chain.**~~ Closed 2026-09-27: FR-31…FR-35, slice `add-illustrations`, NFR-2 refined. Was: 6.17 "Illustrations" (v1.4) and 6.18 "Themes" (v1.1) appeared in the PRD after onboarding. They need to be added to `requirements.md` as Future rows and assigned to plan slices.
3. ~~**Waivers for the baseline.**~~ Closed 2026-09-27 (PD-8): MVP FR-1…14 already had tests, only Future rows were red. `check-acceptance-methods --mode=artifact` now prints them as SKIP-pending and does not count them in the verdict; waivers are not needed. Was: onboarding step 2b was not done: MVP requirements have no `docs/qa/waivers/*-baseline-*.md`, so `check-acceptance-methods --mode=artifact` is red. The owner confirms the waiver set together with the baseline.
4. ~~**Red G6/G7 due to web-specific gates.**~~ Closed 2026-09-27 (PD-9): recordings and visual removed from G6/G7 and `--strict-recordings` from release traceability; evals deferred until `add-illustrations`. Was: `gate-status` still requires recordings and visual fidelity, which a native app does not have. Decide: adapt `gate-status` (a commit with `Refs: PD-x`, since the script is locked) or close them with waivers.
5. **UI evidence.** Decision 2026-09-27: the `add-ui-tests` slice, an XCUITest target (`@trace FR-10`, `FR-14`), closes tech debt #7; a separate task after going through the questions. FR-10 (⌘C, context menu) and FR-14 (click on a result) were verified only at the `ReaderViewModel` level. XCUITest or an explicit waiver is needed; this is tied to tech debt #7.
6. ~~**Diacritics test (FR-2).**~~ Closed 2026-09-27: a new test found a bug (the Cyrillic "ё" was not folded, 69 occurrences in the Synodal); fixed with `ё → е` folding in `BibleCore`. Was: the test checked only the index entry count, not diacritic insensitivity.
7. ~~**NFRs without a mechanism.**~~ Closed 2026-09-27: mechanisms and slices (`add-platform-checks`, `add-ui-tests`) in the [plan](mvp-capability-plan.md). Was: NFR-1…NFR-5 (platform, offline, performance, accessibility, size) stand as Future because there are no checks for them. Each needs a mechanism and a slice.
8. ~~**Coverage ratchet not enabled.**~~ Closed 2026-09-27 (PD-10): baseline lines 96.15 %, regions 91.97 %, functions 92.86 %; branches excluded because Swift does not collect them (it was a fictitious 100 % over 0/0). Was: `quality/coverage-baseline.json` not yet created. Run `make coverage` and `check-coverage-ratchet --update`, then commit the baseline.
9. ~~**Process ratchet and telemetry.**~~ Closed 2026-09-27: `trace/ledger.jsonl` is local (in `.gitignore`), git has only the digest `trace/process-health.json` + `docs/qa/process-health.md` (`npm run retro:digest`); `quality/process-baseline.json` earned after a green `qa:verify` (acceptance coverage 14/40, vacuousPasses 0). Was: `quality/process-baseline.json` is still a template and `trace/process-health.json` does not exist. Run `npm run retro:digest` and `check:process --update` after an honest green run. Also decide whether to commit `trace/ledger.jsonl`: hooks change it after every commit.
10. ~~**Claude Code hook.**~~ Closed 2026-09-27: the Stop hook `.claude/hooks/swift-build-on-stop.sh` runs `swift build` if `.swift` files changed and blocks ending the turn on an error. Was: `check:integrity` warns that `.claude/settings.json` has no `hooks`. The ESLint hook does not fit us; a possible replacement is `swift build` after editing `.swift`, but it is slow.
11. **CI not verified.** `.github/workflows/ci.yml` has never run on GitHub yet (runner `macos-15`, `CODE_SIGNING_ALLOWED=NO`, database generated in pre-build). Also `check-traceability --check-fresh` in CI may fail if a stale report is committed.
12. ~~**Other tools.**~~ Closed 2026-09-27 as "not needed": we work only in Claude Code; the pixel-parity lessons are irrelevant after PD-9. Revisit if a second tool or visual mockups appear (e.g. for the 6.18 themes). Was: the Cursor, Codex and Copilot adapters are not installed. Three pixel-parity lessons are not inserted into AGENTS.md. Install them if needed.
13. ~~**Updating from upstream.**~~ Closed 2026-09-27: edits stay local, the procedure is in the "Updating from upstream" section. A fork with a path config only if updates become regular. Was: the adapted scripts diverge from `project-factory`. Every update means re-adapting and regenerating the lock with `Refs: PD-x`. Perhaps move the Swift adaptation into the factory fork (a path config instead of code edits).
14. ~~**Release trajectory and retrofit.**~~ Closed 2026-09-27: a real retrofit review (code, security, spec), 5 confirmed defects fixed (R1–R4, trace FR-9), the rest in tech debt #8–#14; `review-findings.json` in the slice archive. Was: `check-trajectory --release --check-fresh` is red for `bible-reader-mvp`: no `review-findings.json`, no commit with `Slice: bible-reader-mvp`, and the report is "stale" in release mode. Options: a real baseline review (`code-reviewer`, `security-reviewer`) or a release mode that respects `.project-factory/retrofit.json`.

## Updating from upstream

The factory scripts are adapted to Swift by code edits. The list of adaptations is in `factory-lock.json` → `adaptations`; project rules are marked in code as `PD-8`, `PD-9`, `PD-10` (see below). Updating a script:

1. `diff` our copy against the new upstream version.
2. Take the new version and reapply the Swift adaptations and `PD-n` edits (search with `grep -n "PD-" scripts/*.mjs`).
3. `npm run qa:verify` must stay Pass.
4. `node scripts/check-factory-integrity.mjs --init-lock --adaptation "<what changed>"` and a commit with `Refs: PD-<n>`.

## Factory rule changes

- **PD-8 (2026-09-27).** `check-acceptance-methods --mode=artifact`: `Future` rows without an artifact print as SKIP-pending and are not part of the verdict; only MVP rows decide PASS/FAIL. Reason: a roadmap without code kept the check permanently red (26 FAIL), and a waiver for every future row mixed "not built yet" with "knowingly accepting a risk". The slice that turns a row into MVP makes the check strict again.
- **PD-9 (2026-09-27).** `gate-status`: `recordings` and `visual-fidelity` (Playwright, pixel comparison) are not part of G6/G7, and release traceability runs without `--strict-recordings`. A native macOS app without web mockups has no such artifacts, so the gates would be red forever. `evals` is deferred until the `add-illustrations` slice (v1.4): in G6 it is visible as `deferred` and does not count as PASS. The rows for these checks are still printed in the table.
- **PD-10 (2026-09-27).** `check-coverage-ratchet` and `swift-coverage-summary`: a metric with an empty scope (0 of 0) has `pct: null`, prints as SKIP-pending and is not part of the baseline. Reason: Swift does not collect branch coverage, and 0/0 counted as 100 % and became a bar over nothing. If a metric is in the baseline but its scope is gone, that is a FAIL.

- **PD-11 (2026-09-27).** `qa-verify`: UI tests (XCUITest) drive the real mouse, keyboard and clipboard, so locally they run only with `QA_UI_TESTS=1`, and in CI always; without them the `app-ui-tests` member is in the DEFERRED list. Reason: the `add-ui-tests` slice.
- **PD-12 (2026-09-27).** `qa-verify` and CI: the `app-build` member is now `scripts/check-platform.mjs`, a Release build instead of Debug, which checks minimum macOS 14.0, `arm64` architecture, `.app` < 100 MB (WARN from 80). Reason: NFR-1 and NFR-5 had no verification mechanism (the `add-platform-checks` slice); the owner narrowed NFR-1 to Apple Silicon and raised the NFR-5 limit to 100 MB.
- **PD-13 (2026-09-28).** `check-trajectory`: commits with `Slice:` count only when reachable from `HEAD` (was `git log --all`). Reason: `--all` depended on local branches and old SHAs after a rebase, so a report generated on a developer machine was "stale" in CI (PR #12), and regenerating it fixed nothing.
- **PD-14 (2026-09-28).** CI: the launch time UI test (NFR-3) on a shared GitHub VM has a 2000 ms limit (`TEST_RUNNER_BIBLE_LAUNCH_BUDGET_MS`), locally on a Mac 1000 ms. Reason: on CI the warm launch of a Debug build varied 800–1800 ms even on docs-only PRs; the measurement stays and is recorded as an attachment, and the 1 s limit is checked on a real Mac (`QA_UI_TESTS=1`). Since 2026-09-30 the test takes the best of three warm launches: a single stalled launch on the VM (2053 ms) failed docs-only PRs.
- **PD-15 (2026-09-28).** The pre-commit hook reads staged files via `execFileSync("git", [...])` instead of a shell string (a file name with `$(...)` no longer executes, tech debt #8); CI has `permissions: contents: read`, actions are pinned to SHAs, `@fission-ai/openspec` to version 1.13.2 (tech debt #9).

## Correction events

- **2026-09-27, vacuous passes in the ledger.** `trace/process-health.json` had 2 vacuous passes: `qa-verify` on 2026-09-26 ran `eval-ratchet` on an empty scope (`scope_n: 0`, exit 0), because evals were not deferred then. The cause was removed by PD-9 (`eval-ratchet` in `qa-verify` as DEFERRED). The ledger before the fix was archived locally as `trace/ledger-2026-09-26.jsonl`; the process baseline was earned on the new ledger.
- **PD-16 (2026-09-28).** The main branch was renamed `main` → `master` (owner request): CI runs on push to `master`, and `--release` for traceability and trajectory on `master`.
- **PD-17 (2026-09-28).** CI keeps `build/ui-tests.xcresult` (screenshots, log) as an artifact when UI tests fail: tests that failed only in CI (Esc, drafts) had no evidence for diagnosis.
- **PD-18 (2026-09-29).** The secret scanner `scripts/check-secrets.mjs` (Anthropic, Brave, GitHub, AWS, Google keys, private keys, `.env`/`.pem`/`.key` files): pre-commit (`--staged`) and the CI step "Secrets scan" over all files in git, so a commit that bypassed the hook does not pass either; scanner tests: `node --test scripts/check-secrets.test.mjs`. The old hook pattern did not catch `sk-ant-…` keys (hyphen). Owner request: the Claude key is never committed or pushed.
- **PD-19 (2026-09-29).** Hooks: git `pre-push` (`scripts/hooks-pre-push.mjs`) scans secrets in commits not yet on GitHub (a commit with `--no-verify`, cherry-pick, rebase); Claude Code hooks in `.claude/settings.json` via `scripts/claude-hooks.mjs`: PreToolUse Write/Edit blocks a key in text and hand edits of generated files (`BibleReader.xcodeproj`, `docs/generated/`, `trace/*.json`, traceability and trajectory reports), PostToolUse after `project.yml` reminds about `xcodegen generate`. Tests: `node --test scripts/claude-hooks.test.mjs` (in the CI step "Secrets scan"). Limit: Claude hooks do not see writes via Bash; pre-commit, pre-push and CI catch those.
- **PD-20 (2026-09-30).** `HANDOFF.md` freshness: the "Recent changes" block between the `BEGIN/END GENERATED` markers is generated by `scripts/handoff.mjs` from git (merged PRs with `Refs:` trailers, branch commits, active openspec changes); pre-commit refreshes it when HANDOFF is in the commit. CI (`--check <base>`) fails if a PR changes `Sources/`, `Tests/` or `BibleReaderApp/` (except `.xcodeproj`), but not the manual part of HANDOFF; the exception is a `Handoff: skip` trailer.
- **PD-21 (2026-09-30).** Documentation, specs, code comments, test names, script messages, commit messages and PR descriptions are in English. The app UI, Bible texts and test data in Ukrainian/Russian/Czech stay as they are (owner decision).
