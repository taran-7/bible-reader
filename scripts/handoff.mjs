// HANDOFF.md that does not go stale (PD-20). The file has two parts:
//   - the manual part ("State", "Next", "Good to know"), written by a human or an agent;
//   - a generated block between markers: facts from git, written only by this script.
//
//   node scripts/handoff.mjs                — rewrite the generated block
//   node scripts/handoff.mjs --check <base> — CI for PRs: code changed → the manual part must change too
//                                             (or a `Handoff: skip` trailer in any PR commit)
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, readdirSync, writeFileSync } from "node:fs";

export const HANDOFF = "docs/exec-plans/active/HANDOFF.md";
export const BEGIN = "<!-- BEGIN GENERATED: do not edit by hand, updated by `node scripts/handoff.mjs` -->";
export const END = "<!-- END GENERATED -->";

/** Paths whose changes mean new product behavior. */
const PRODUCT = /^(Sources|Tests|BibleReaderApp)\//;
const IGNORED = /^BibleReaderApp\/BibleReader\.xcodeproj\//;

export function replaceBlock(text, block) {
  const start = text.indexOf(BEGIN), end = text.indexOf(END);
  const wrapped = `${BEGIN}\n${block.trim()}\n${END}`;
  if (start === -1 || end === -1) return `${text.trimEnd()}\n\n${wrapped}\n`;
  return text.slice(0, start) + wrapped + text.slice(end + END.length);
}

/** The text without the generated block: changes inside the block do not count as a manual edit. */
export function manualPart(text) {
  const start = text.indexOf(BEGIN), end = text.indexOf(END);
  const body = start === -1 || end === -1 ? text : text.slice(0, start) + text.slice(end + END.length);
  return body.trim();
}

export function touchesProduct(files) {
  return files.some((file) => PRODUCT.test(file) && !IGNORED.test(file));
}

/** The failure reason or null. */
export function checkPr({ files, before, after, messages }) {
  if (!touchesProduct(files)) return null;
  if (messages.some((message) => /^Handoff:\s*skip\b/im.test(message))) return null;
  if (manualPart(before) !== manualPart(after)) return null;
  return `the PR changes product code, but the manual part of ${HANDOFF} is not updated.\n` +
    "Update \"State\" / \"Next\", or add a `Handoff: skip` trailer to a commit if the state for the next agent did not change.";
}

export function renderBlock({ merges, branch, changes }) {
  const lines = ["## Recent changes (from git)"];
  for (const merge of merges) {
    const refs = merge.refs.length ? ` (${merge.refs.join(", ")})` : "";
    lines.push(`- ${merge.date} PR #${merge.pr}: ${merge.title}${refs}`);
  }
  if (branch.length) {
    lines.push("", "Not in master yet (current branch):");
    for (const commit of branch) lines.push(`- ${commit.date} ${commit.subject}`);
  }
  lines.push("", `Active openspec changes: ${changes.length ? changes.map((c) => `\`${c}\``).join(", ") : "none"}.`);
  return lines.join("\n");
}

const git = (...args) => execFileSync("git", args, { encoding: "utf8" }).trim();
const list = (out) => out.split("\n").map((s) => s.trim()).filter(Boolean);
const refsOf = (range) => [...new Set(list(git("log", range, "--format=%(trailers:key=Refs,valueonly,separator=%x2C)"))
  .flatMap((line) => line.split(",")).map((s) => s.trim()).filter(Boolean))].sort();

function collect() {
  const master = git("rev-parse", "--verify", "--quiet", "origin/master") ? "origin/master" : "master";
  const merges = list(git("log", "--first-parent", "--merges", "-8", "--format=%H%x09%ad%x09%s%x09%b", "--date=short", master))
    .map((line) => {
      const [sha, date, subject, body] = line.split("\t");
      return { date, pr: subject.match(/#(\d+)/)?.[1] ?? "?", title: (body || subject).trim(), refs: refsOf(`${sha}^1..${sha}^2`) };
    });
  const branch = list(git("log", "--no-merges", "--format=%ad%x09%s", "--date=short", `${master}..HEAD`))
    .map((line) => { const [date, subject] = line.split("\t"); return { date, subject }; });
  const dir = "openspec/changes";
  const changes = existsSync(dir) ? readdirSync(dir, { withFileTypes: true }).filter((e) => e.isDirectory() && e.name !== "archive").map((e) => e.name) : [];
  return { merges, branch, changes };
}

function main(argv) {
  const check = argv.indexOf("--check");
  if (check !== -1) {
    const base = argv[check + 1];
    const files = list(git("diff", "--name-only", `${base}...HEAD`));
    const before = (() => { try { return git("show", `${base}:${HANDOFF}`); } catch { return ""; } })();
    const messages = git("log", "--format=%B%x00", `${base}..HEAD`).split("\0");
    const error = checkPr({ files, before, after: readFileSync(HANDOFF, "utf8"), messages });
    if (error) { console.error(`handoff: ${error}`); process.exit(1); }
    console.log("handoff: OK");
    return;
  }
  const text = readFileSync(HANDOFF, "utf8");
  const next = replaceBlock(text, renderBlock(collect()));
  if (next !== text) writeFileSync(HANDOFF, next);
  console.log(`handoff: generated block ${next !== text ? "updated" : "up to date"}`);
}

if (import.meta.url === `file://${process.argv[1]}`) main(process.argv.slice(2));
