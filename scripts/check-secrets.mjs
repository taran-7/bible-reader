#!/usr/bin/env node
// Сканер секретів (запит власника 2026-09-29): ключі API (Claude, Brave, GitHub, AWS…) не мають потрапити в git.
// Ключі користувача живуть лише в Keychain (`KeychainKey` у додатку); у тестах — вигадані `sk-test`.
//
//   node scripts/check-secrets.mjs            — усі файли в git (CI: навіть коміт з --no-verify не пройде)
//   node scripts/check-secrets.mjs --staged   — лише проіндексоване (pre-commit)
//   node scripts/check-secrets.mjs --history <base>..<head> — додані рядки кожного коміту діапазону (CI для PR):
//                                               ключ, доданий і потім видалений, лишається в історії
import { execFileSync } from "node:child_process";
import { pathToFileURL } from "node:url";

export const SECRET_PATTERNS = [
  ["private key", /-----BEGIN (?:RSA |EC |OPENSSH |DSA |ENCRYPTED |PGP )?PRIVATE KEY(?: BLOCK)?-----/],
  ["Anthropic API key", /\bsk-ant-[A-Za-z0-9_-]{20,}/],
  ["OpenAI-style key", /\bsk-(?:proj-)?[A-Za-z0-9_-]{32,}/],
  ["Brave Search key", /\bBSA[A-Za-z0-9_-]{20,}/],
  ["GitHub token", /\b(?:ghp|gho|ghu|ghs|ghr|github_pat)_[A-Za-z0-9_]{20,}/],
  ["Slack token", /\bxox[abprs]-[A-Za-z0-9-]{10,}/],
  ["AWS access key", /\bAKIA[0-9A-Z]{16}\b/],
  ["Google API key", /\bAIza[0-9A-Za-z_-]{35}\b/],
  ["DB URL with password", /\b(?:postgres(?:ql)?|mysql|mongodb(?:\+srv)?|redis|amqp):\/\/[^\s'"/]+:[^\s'"@]+@/],
  // Будь-який ключ без відомого префікса, присвоєний змінній з назвою ключа (напр. braveKey = "…").
  ["key assignment", /(?:api[_-]?key|apikey|secret|token|password|braveKey|claudeKey)["']?\s*[:=]\s*["'][A-Za-z0-9_\-.]{24,}["']/i],
];

/** Файли, які ніколи не комітимо: env, ключі, сертифікати. */
export const FORBIDDEN_FILES = /(^|\/)(\.env(\.[^/]*)?|[^/]*\.(pem|p12|key|mobileprovision)|credentials\.json|secrets?\.(json|plist))$/i;

const BINARY = /\.(png|jpe?g|gif|webp|pdf|ico|woff2?|sqlite|mp4|zip|dmg|xcresult)$/i;

export function scan(files, read) {
  const findings = [];
  for (const file of files) {
    if (FORBIDDEN_FILES.test(file) && !/\.example$/.test(file)) findings.push(`${file}: файл із секретами не комітиться`);
    if (BINARY.test(file)) continue;
    let content;
    try { content = read(file); } catch { continue; }
    content.split("\n").forEach((line, index) => {
      // Одна знахідка на рядок: ключ Claude схожий і на ключ у стилі OpenAI.
      const hit = SECRET_PATTERNS.find(([, pattern]) => pattern.test(line));
      if (hit) findings.push(`${file}:${index + 1}: схоже на ${hit[0]}`);
    });
  }
  return findings;
}

function main() {
  const history = process.argv.indexOf("--history");
  if (history !== -1) return scanHistory(process.argv[history + 1]);
  const staged = process.argv.includes("--staged");
  const git = (args) => execFileSync("git", args, { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
  // R — перейменування: файл з ключем, перейменований у тому самому коміті, теж перевіряємо.
  const files = (staged ? git(["diff", "--cached", "--name-only", "--diff-filter=ACMR"]) : git(["ls-files"]))
    .split("\n").filter(Boolean);
  // argv, не рядок оболонки: файл з назвою `$(cmd)` не виконається (tech debt #8).
  const findings = scan(files, (file) => (staged ? git(["show", `:${file}`]) : git(["show", `HEAD:${file}`])));
  console.log(`Scope: ${files.length} file(s) ${staged ? "staged" : "tracked"}`);
  if (findings.length) {
    for (const finding of findings) console.error(`FAIL  ${finding}`);
    console.error("Result: FAIL — приберіть секрет (ключі — лише в Keychain) і змініть його у постачальника, якщо він уже потрапив у git.");
    process.exit(1);
  }
  console.log("Result: PASS");
}

/** Додані рядки патча (`+…`, без `+++`) з назвою файлу — для перевірки історії. */
export function addedLines(patch) {
  const lines = [];
  let file = "";
  for (const line of patch.split("\n")) {
    if (line.startsWith("+++ ")) file = line.replace(/^\+\+\+ (b\/)?/, "");
    else if (line.startsWith("+") && !BINARY.test(file)) lines.push([file, line.slice(1)]);
  }
  return lines;
}

function scanHistory(range) {
  const patch = execFileSync("git", ["log", "-p", "--no-color", "--format=commit %H", range], { encoding: "utf8", maxBuffer: 256 * 1024 * 1024 });
  const findings = [];
  for (const [file, line] of addedLines(patch)) {
    const hit = SECRET_PATTERNS.find(([, pattern]) => pattern.test(line));
    if (hit) findings.push(`${file}: у історії ${range} схоже на ${hit[0]}`);
  }
  console.log(`Scope: history ${range}`);
  if (findings.length) {
    for (const finding of findings) console.error(`FAIL  ${finding}`);
    console.error("Result: FAIL — ключ є в історії комітів: змініть його у постачальника і перепишіть історію гілки.");
    process.exit(1);
  }
  console.log("Result: PASS");
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) main();
