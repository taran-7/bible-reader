// Git pre-commit hook (deterministic inner loop) — install per hooks/README.md.
// Fast, staged-scope checks only; the full battery runs at gates and in CI.
//
//   1. block committing real env files / obvious secrets
//   2. swift build when Swift sources are staged (Swift adaptation)
//   4. traceability validator (fast, pure file parsing)
import { execFileSync, execSync, spawnSync } from "node:child_process";
import { existsSync } from "node:fs";

// Fail-open process-health telemetry (reflection design, mechanism 1): append
// a hook-run event with the final exit code to trace/ledger.jsonl. Ledger
// errors are swallowed — telemetry must NEVER block a commit.
process.on("exit", (code) => {
  try {
    if (!existsSync("scripts/ledger.mjs")) return;
    spawnSync(
      process.execPath,
      ["scripts/ledger.mjs", "emit", JSON.stringify({ event: "hook-run", check: "pre-commit", exitCode: code ?? 0 })],
      { stdio: "ignore" },
    );
  } catch {
    /* fail-open */
  }
});

const run = (cmd, opts = {}) => execSync(cmd, { stdio: "inherit", ...opts });
const capture = (cmd) => execSync(cmd, { encoding: "utf8" }).trim();

const staged = capture("git diff --cached --name-only --diff-filter=ACM")
  .split("\n")
  .filter(Boolean);

// 1 — secret hygiene: спільний сканер (scripts/check-secrets.mjs) — той самий, що в CI.
{
  const secrets = spawnSync(process.execPath, ["scripts/check-secrets.mjs", "--staged"], { stdio: "inherit" });
  if (secrets.status !== 0) {
    console.error("pre-commit: possible secret staged — ключі API лише в Keychain, не в git.");
    process.exit(1);
  }
}

// 2+3 — Swift adaptation: the compiler is the linter/typechecker. Build only
// when Swift sources are staged (the full `make test` runs at gates and in CI).
if (staged.some((f) => f.endsWith(".swift") || f === "Package.swift")) {
  run("swift build");
}

// 4 — traceability (fails on broken FR chain / archived-but-unchecked tasks).
// The validator regenerates the report + trace graph; stage them so the
// commit always contains the fresh versions (otherwise the worktree is left
// dirty and CI --check-fresh fails on staleness).
run("node scripts/check-traceability.mjs");
run('git add docs/qa/traceability-report.md trace/trace.json');

// 5 — trajectory (process audit: review evidence, Slice: trailers, scope).
// Warns only by default, so it won't block a commit; regenerates + stages its
// report so CI --check-fresh stays green.
run("node scripts/check-trajectory.mjs");
run('git add docs/qa/trajectory-report.md trace/trajectory.json');

// 6 — HANDOFF (PD-20): якщо ручну частину оновлено, освіжити згенерований блок з git.
if (staged.includes("docs/exec-plans/active/HANDOFF.md")) {
  run("node scripts/handoff.mjs");
  run("git add docs/exec-plans/active/HANDOFF.md");
}

console.log("pre-commit: all deterministic checks passed");
