// node --test scripts/claude-hooks.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { checkEdit, afterEdit, writtenText } from "./claude-hooks.mjs";
import { pushRanges } from "./hooks-pre-push.mjs";

const root = "/repo";
const key = "sk-ant-api03-" + "A".repeat(40);

test("pre-edit blocks a key in Write, Edit and MultiEdit", () => {
  assert.match(checkEdit({ file_path: "/repo/a.swift", content: `let k = "${key}"` }, root), /Anthropic API key/);
  assert.match(checkEdit({ file_path: "/repo/a.md", old_string: "x", new_string: key }, root), /Keychain/);
  assert.match(checkEdit({ file_path: "/repo/a.md", edits: [{ new_string: "ok" }, { new_string: key }] }, root), /a\.md/);
  assert.equal(checkEdit({ file_path: "/repo/a.swift", content: 'ClaudeCurator(key: "sk-test")' }, root), null);
});

test("pre-edit blocks generated files, lets the rest through", () => {
  for (const path of ["BibleReaderApp/BibleReader.xcodeproj/project.pbxproj", "docs/generated/db-schema.md",
                      "trace/trace.json", "docs/qa/traceability-report.md"]) {
    assert.match(checkEdit({ file_path: `/repo/${path}`, content: "x" }, root), /is generated/, path);
  }
  assert.equal(checkEdit({ file_path: "/repo/BibleReaderApp/project.yml", content: "x" }, root), null);
  assert.equal(checkEdit({ file_path: "/repo/docs/qa/manual-test-plan.md", content: "x" }, root), null);
});

test("post-edit reminds about xcodegen only for project.yml", () => {
  assert.match(afterEdit({ file_path: "/repo/BibleReaderApp/project.yml" }, root), /xcodegen generate/);
  assert.equal(afterEdit({ file_path: "/repo/Sources/BibleCore/Theme.swift" }, root), null);
  assert.equal(writtenText({}), "");
});

test("pre-push: ranges for an update, a new branch and a delete", () => {
  const zero = "0".repeat(40), a = "a".repeat(40), b = "b".repeat(40);
  assert.deepEqual(pushRanges(`refs/heads/x ${a} refs/heads/x ${b}\n`, "origin"), [[`${b}..${a}`]]);
  assert.deepEqual(pushRanges(`refs/heads/x ${a} refs/heads/x ${zero}\n`, "origin"), [[a, "--not", "--remotes=origin"]]);
  assert.deepEqual(pushRanges(`(delete) ${zero} refs/heads/x ${b}\n`, "origin"), []);
});
