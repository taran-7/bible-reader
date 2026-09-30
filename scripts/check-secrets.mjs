#!/usr/bin/env node
// Secret scanner (owner request 2026-09-29): API keys (Claude, Brave, GitHub, AWS…) must not get into git.
// The user's keys live only in the Keychain (`KeychainKey` in the app); tests use made-up `sk-test`.
//
//   node scripts/check-secrets.mjs            — all files in git (CI: even a commit with --no-verify does not pass)
//   node scripts/check-secrets.mjs --staged   — only the staged ones (pre-commit)
//   node scripts/check-secrets.mjs --history <base>..<head> — added lines of every commit in the range (CI for PRs):
//                                               a key added and later removed stays in history
//   pre-push (scripts/hooks-pre-push.mjs) — the same for commits not yet on GitHub
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
  // Any key without a known prefix assigned to a variable named like a key (e.g. braveKey = "…").
  ["key assignment", /(?:api[_-]?key|apikey|secret|token|password|braveKey|claudeKey)["']?\s*[:=]\s*["'][A-Za-z0-9_\-.]{24,}["']/i],
];

/** Files we never commit: env, keys, certificates. */
export const FORBIDDEN_FILES = /(^|\/)(\.env(\.[^/]*)?|[^/]*\.(pem|p12|key|mobileprovision)|credentials\.json|secrets?\.(json|plist))$/i;

const BINARY = /\.(png|jpe?g|gif|webp|pdf|ico|woff2?|sqlite|mp4|zip|dmg|xcresult)$/i;

export function scan(files, read) {
  const findings = [];
  for (const file of files) {
    if (FORBIDDEN_FILES.test(file) && !/\.example$/.test(file)) findings.push(`${file}: a secrets file is never committed`);
    if (BINARY.test(file)) continue;
    let content;
    try { content = read(file); } catch { continue; }
    content.split("\n").forEach((line, index) => {
      // One finding per line: a Claude key also looks like an OpenAI-style key.
      const hit = SECRET_PATTERNS.find(([, pattern]) => pattern.test(line));
      if (hit) findings.push(`${file}:${index + 1}: looks like ${hit[0]}`);
    });
  }
  return findings;
}

function main() {
  const history = process.argv.indexOf("--history");
  if (history !== -1) return scanHistory(process.argv.slice(history + 1));
  const staged = process.argv.includes("--staged");
  const git = (args) => execFileSync("git", args, { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
  // R is a rename: a file with a key renamed in the same commit is checked too.
  const files = (staged ? git(["diff", "--cached", "--name-only", "--diff-filter=ACMR"]) : git(["ls-files"]))
    .split("\n").filter(Boolean);
  // argv, not a shell string: a file named `$(cmd)` does not execute (tech debt #8).
  const findings = scan(files, (file) => (staged ? git(["show", `:${file}`]) : git(["show", `HEAD:${file}`])));
  console.log(`Scope: ${files.length} file(s) ${staged ? "staged" : "tracked"}`);
  if (findings.length) {
    for (const finding of findings) console.error(`FAIL  ${finding}`);
    console.error("Result: FAIL — remove the secret (keys belong only in the Keychain) and rotate it with the provider if it already got into git.");
    process.exit(1);
  }
  console.log("Result: PASS");
}

/** Added patch lines (`+…`, without `+++`) with the file name, for the history check. */
export function addedLines(patch) {
  const lines = [];
  let file = "";
  for (const line of patch.split("\n")) {
    if (line.startsWith("+++ ")) file = line.replace(/^\+\+\+ (b\/)?/, "");
    else if (line.startsWith("+") && !BINARY.test(file)) lines.push([file, line.slice(1)]);
  }
  return lines;
}

/** `range` is one git log argument (`a..b`) or several (`sha --not --remotes`, pre-push of a new branch). */
export function scanHistory(range) {
  const args = Array.isArray(range) ? range : [range];
  range = args.join(" ");
  const patch = execFileSync("git", ["log", "-p", "--no-color", "--format=commit %H", ...args], { encoding: "utf8", maxBuffer: 256 * 1024 * 1024 });
  const findings = [];
  for (const [file, line] of addedLines(patch)) {
    const hit = SECRET_PATTERNS.find(([, pattern]) => pattern.test(line));
    if (hit) findings.push(`${file}: in history ${range} looks like ${hit[0]}`);
  }
  console.log(`Scope: history ${range}`);
  if (findings.length) {
    for (const finding of findings) console.error(`FAIL  ${finding}`);
    console.error("Result: FAIL — a key is in the commit history: rotate it with the provider and rewrite the branch history.");
    process.exit(1);
  }
  console.log("Result: PASS");
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) main();
