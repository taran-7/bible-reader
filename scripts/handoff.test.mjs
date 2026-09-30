// node --test scripts/handoff.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { BEGIN, END, replaceBlock, manualPart, checkPr, renderBlock } from "./handoff.mjs";

const doc = (manual, generated = "old") => `${manual}\n\n${BEGIN}\n${generated}\n${END}\n`;

test("replaceBlock changes only the block between markers, or appends it", () => {
  assert.equal(replaceBlock(doc("# H"), "new"), doc("# H", "new"));
  assert.equal(replaceBlock("# H\n", "new"), doc("# H", "new"));
});

test("manualPart ignores the generated block", () => {
  assert.equal(manualPart(doc("# H", "a")), manualPart(doc("# H", "b")));
  assert.notEqual(manualPart(doc("# H")), manualPart(doc("# H2")));
});

test("checkPr: code without a manual HANDOFF edit fails", () => {
  const base = { files: ["Sources/BibleCore/Theme.swift"], before: doc("# H", "a"), after: doc("# H", "b"), messages: ["x"] };
  assert.match(checkPr(base), /Handoff: skip/);
  assert.equal(checkPr({ ...base, after: doc("# H updated") }), null);
  assert.equal(checkPr({ ...base, messages: ["fix\n\nHandoff: skip"] }), null);
});

test("checkPr: docs, scripts or xcodeproj only do not require HANDOFF", () => {
  const same = doc("# H");
  for (const files of [["docs/a.md", "scripts/x.mjs"], ["BibleReaderApp/BibleReader.xcodeproj/project.pbxproj"]]) {
    assert.equal(checkPr({ files, before: same, after: same, messages: [] }), null);
  }
});

test("renderBlock: PR with FRs, branch, openspec", () => {
  const out = renderBlock({
    merges: [{ date: "2026-09-29", pr: "24", title: "Pastel theme", refs: ["FR-31", "FR-32"] }],
    branch: [{ date: "2026-09-30", subject: "WIP" }], changes: [],
  });
  assert.match(out, /PR #24: Pastel theme \(FR-31, FR-32\)/);
  assert.match(out, /Not in master yet[\s\S]*WIP/);
  assert.match(out, /openspec changes: none/);
});
