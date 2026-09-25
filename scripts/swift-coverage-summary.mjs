// Swift adaptation for check-coverage-ratchet: converts the llvm-cov export
// of `swift test --enable-code-coverage` into the Istanbul-style
// coverage/coverage-summary.json that the ratchet reads.
// Scope: Sources/ only (tests and .build are excluded).
//
// Wire as: "test:coverage": "make coverage"
import { execFileSync } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";

const path = execFileSync("swift", ["test", "--show-codecov-path"], { encoding: "utf8" }).trim();
const report = JSON.parse(readFileSync(path, "utf8"));
const files = report.data.flatMap((d) => d.files).filter((f) => f.filename.includes("/Sources/"));
if (files.length === 0) {
  console.error(`swift-coverage-summary: no Sources/ files in ${path}`);
  process.exit(1);
}

const sum = (key) => {
  const count = files.reduce((n, f) => n + f.summary[key].count, 0);
  const covered = files.reduce((n, f) => n + f.summary[key].covered, 0);
  const pct = count === 0 ? 100 : Math.round((covered / count) * 10000) / 100;
  return { total: count, covered, pct };
};
// llvm-cov has no statements metric; regions are the closest equivalent.
const total = {
  lines: sum("lines"),
  statements: sum("regions"),
  functions: sum("functions"),
  branches: sum("branches"),
};
mkdirSync("coverage", { recursive: true });
writeFileSync("coverage/coverage-summary.json", `${JSON.stringify({ total }, null, 2)}\n`);
console.log(`coverage: lines ${total.lines.pct}% · regions ${total.statements.pct}% · functions ${total.functions.pct}% · branches ${total.branches.pct}% (${files.length} files)`);
