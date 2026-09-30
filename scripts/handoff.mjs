// HANDOFF.md без застарівання (PD-20). Файл має дві частини:
//   - ручну («Стан», «Що далі», «Корисне знати») — її пише людина або агент;
//   - згенерований блок між маркерами — факти з git, їх пише лише цей скрипт.
//
//   node scripts/handoff.mjs              — переписати згенерований блок
//   node scripts/handoff.mjs --check <base> — CI для PR: код змінено → ручна частина теж має змінитись
//                                           (або трейлер `Handoff: skip` у будь-якому коміті PR)
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, readdirSync, writeFileSync } from "node:fs";

export const HANDOFF = "docs/exec-plans/active/HANDOFF.md";
export const BEGIN = "<!-- BEGIN GENERATED: не редагувати вручну, оновлює `node scripts/handoff.mjs` -->";
export const END = "<!-- END GENERATED -->";

/** Шляхи, зміна яких означає нову поведінку продукту. */
const PRODUCT = /^(Sources|Tests|BibleReaderApp)\//;
const IGNORED = /^BibleReaderApp\/BibleReader\.xcodeproj\//;

export function replaceBlock(text, block) {
  const start = text.indexOf(BEGIN), end = text.indexOf(END);
  const wrapped = `${BEGIN}\n${block.trim()}\n${END}`;
  if (start === -1 || end === -1) return `${text.trimEnd()}\n\n${wrapped}\n`;
  return text.slice(0, start) + wrapped + text.slice(end + END.length);
}

/** Текст без згенерованого блоку й без рядка «Оновлено…» не рахується як ручна правка. */
export function manualPart(text) {
  const start = text.indexOf(BEGIN), end = text.indexOf(END);
  const body = start === -1 || end === -1 ? text : text.slice(0, start) + text.slice(end + END.length);
  return body.trim();
}

export function touchesProduct(files) {
  return files.some((file) => PRODUCT.test(file) && !IGNORED.test(file));
}

/** Причина падіння або null. */
export function checkPr({ files, before, after, messages }) {
  if (!touchesProduct(files)) return null;
  if (messages.some((message) => /^Handoff:\s*skip\b/im.test(message))) return null;
  if (manualPart(before) !== manualPart(after)) return null;
  return `PR змінює код продукту, але ручна частина ${HANDOFF} не оновлена.\n` +
    "Онови «Стан» / «Що далі», або додай трейлер `Handoff: skip` у коміт, якщо стан для наступного агента не змінився.";
}

export function renderBlock({ merges, branch, changes }) {
  const lines = ["## Останні зміни (з git)"];
  for (const merge of merges) {
    const refs = merge.refs.length ? ` (${merge.refs.join(", ")})` : "";
    lines.push(`- ${merge.date} PR #${merge.pr}: ${merge.title}${refs}`);
  }
  if (branch.length) {
    lines.push("", "Ще не в master (поточна гілка):");
    for (const commit of branch) lines.push(`- ${commit.date} ${commit.subject}`);
  }
  lines.push("", `Активні зміни openspec: ${changes.length ? changes.map((c) => `\`${c}\``).join(", ") : "немає"}.`);
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
  console.log(`handoff: згенерований блок ${next !== text ? "оновлено" : "актуальний"}`);
}

if (import.meta.url === `file://${process.argv[1]}`) main(process.argv.slice(2));
