// Хуки Claude Code для агента (.claude/settings.json). Git-хуки ловлять те, що комітиться;
// ці — те, що агент пише у файли, ще до коміту (PD-19).
//
//   node scripts/claude-hooks.mjs pre-edit    — PreToolUse Write|Edit|MultiEdit: секрет у тексті
//                                                або ручна правка згенерованого файлу → блок (exit 2)
//   node scripts/claude-hooks.mjs post-edit   — PostToolUse: після project.yml нагадати про xcodegen
import { readFileSync } from "node:fs";
import { relative } from "node:path";
import { SECRET_PATTERNS } from "./check-secrets.mjs";

/** Генеруються скриптами; правити — через генератор (AGENTS.md). */
export const GENERATED = [
  [/^BibleReaderApp\/BibleReader\.xcodeproj\//, "cd BibleReaderApp && xcodegen generate (з project.yml)"],
  [/^docs\/generated\//, "генератор схеми БД"],
  [/^trace\/[^/]+\.json$/, "node scripts/check-traceability.mjs / check-trajectory.mjs"],
  [/^docs\/qa\/(traceability|trajectory)-report\.md$/, "node scripts/check-traceability.mjs / check-trajectory.mjs"],
];

/** Новий текст, який інструмент запише у файл. */
export function writtenText(input) {
  if (typeof input.content === "string") return input.content;
  if (Array.isArray(input.edits)) return input.edits.map((edit) => edit.new_string ?? "").join("\n");
  return input.new_string ?? "";
}

/** Причина блокування або null. */
export function checkEdit(input, root) {
  const path = relative(root, input.file_path ?? "");
  const generated = GENERATED.find(([pattern]) => pattern.test(path));
  if (generated) return `${path} генерується — не правити вручну, а запустити: ${generated[1]}.`;
  const hit = writtenText(input).split("\n").map((line) => SECRET_PATTERNS.find(([, pattern]) => pattern.test(line))).find(Boolean);
  if (hit) return `${path}: текст схожий на ${hit[0]}. Ключі API — лише в Keychain, не у файлах проєкту.`;
  return null;
}

/** Нагадування після правки або null. */
export function afterEdit(input, root) {
  return relative(root, input.file_path ?? "") === "BibleReaderApp/project.yml"
    ? "Змінено project.yml: запусти `cd BibleReaderApp && xcodegen generate`, інакше Xcode збирає старий BibleReader.xcodeproj."
    : null;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const event = JSON.parse(readFileSync(0, "utf8"));
  const root = process.env.CLAUDE_PROJECT_DIR ?? event.cwd ?? process.cwd();
  const input = event.tool_input ?? {};
  if (process.argv[2] === "pre-edit") {
    const reason = checkEdit(input, root);
    if (reason) {
      console.error(reason);
      process.exit(2);
    }
  } else if (process.argv[2] === "post-edit") {
    const note = afterEdit(input, root);
    if (note) console.log(JSON.stringify({ hookSpecificOutput: { hookEventName: "PostToolUse", additionalContext: note } }));
  }
}
