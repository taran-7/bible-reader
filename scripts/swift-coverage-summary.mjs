// Swift adaptation for check-coverage-ratchet: converts the llvm-cov export
// of `swift test --enable-code-coverage` into the Istanbul-style
// coverage/coverage-summary.json that the ratchet reads.
// Scope: Sources/ only (tests and .build are excluded); vendored third-party
// code (Sources/CSnowball: generated Snowball C, see THIRD_PARTY.md) is excluded too.
//
// Wire as: "test:coverage": "make coverage"
import { execFileSync } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";

const path = execFileSync("swift", ["test", "--show-codecov-path"], { encoding: "utf8" }).trim();
const report = JSON.parse(readFileSync(path, "utf8"));
const files = report.data.flatMap((d) => d.files).filter((f) => f.filename.includes("/Sources/") && !f.filename.includes("/Sources/CSnowball/"));
if (files.length === 0) {
  console.error(`swift-coverage-summary: no Sources/ files in ${path}`);
  process.exit(1);
}

const sum = (key) => {
  const count = files.reduce((n, f) => n + f.summary[key].count, 0);
  const covered = files.reduce((n, f) => n + f.summary[key].covered, 0);
  // 0 of 0 is not 100%: Swift collects no branch coverage, so an empty metric stays null.
  const pct = count === 0 ? null : Math.round((covered / count) * 10000) / 100;
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
console.log(`coverage: lines ${total.lines.pct}% · regions ${total.statements.pct}% · functions ${total.functions.pct}% · branches ${total.branches.pct ?? "n/a"}% (${files.length} files)`);
// Файли з непокритими функціями — щоб падіння ratchet у CI було видно без локального прогону.
for (const f of files) {
  const fn = f.summary.functions;
  if (fn.covered < fn.count) {
    console.log(`  uncovered: ${f.filename.replace(/^.*\/Sources\//, "Sources/")} — functions ${fn.covered}/${fn.count}, lines ${f.summary.lines.covered}/${f.summary.lines.count}`);
  }
}
const ours = new Set(files.map((f) => f.filename));
for (const fn of report.data.flatMap((d) => d.functions ?? [])) {
  if (fn.count === 0 && fn.filenames.some((name) => ours.has(name))) {
    let name = fn.name;
    try { name = execFileSync("xcrun", ["swift-demangle", "-compact", fn.name], { encoding: "utf8" }).trim(); } catch {}
    console.log(`    never called: ${fn.filenames[0].replace(/^.*\/Sources\//, "Sources/")}:${fn.regions?.[0]?.[0] ?? "?"} ${name}`);
  }
}
// Непокриті регіони (гілки всередині функцій): файл і рядки початку.
for (const f of files) {
  const lines = f.segments.filter((s) => s[3] && s[4] && s[2] === 0 && !s[5]).map((s) => s[0]);
  if (lines.length) console.log(`    uncovered regions: ${f.filename.replace(/^.*\/Sources\//, "Sources/")} lines ${[...new Set(lines)].join(", ")}`);
}
