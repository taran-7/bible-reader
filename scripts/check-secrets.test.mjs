// node --test scripts/check-secrets.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { scan, addedLines } from "./check-secrets.mjs";

const read = (files) => (file) => files[file];

test("знаходить ключі Claude, Brave, GitHub і файли з секретами", () => {
  const files = {
    "a.swift": 'let k = "sk-ant-api03-' + "A".repeat(40) + '"',
    "b.md": "BSA" + "x".repeat(25),
    "c.yml": "token: ghp_" + "a".repeat(36),
    ".env": "X=1",
    "d.txt": "-----BEGIN OPENSSH " + "PRIVATE KEY-----",
  };
  const found = scan(Object.keys(files), read(files));
  assert.equal(found.length, 5);
  assert.match(found[0], /a\.swift:1: схоже на Anthropic API key/);
  assert.ok(found.some((f) => f.startsWith(".env: файл")));
});

test("вигадані тестові ключі й звичайний код — чисто", () => {
  const files = {
    "t.swift": 'ClaudeCurator(key: "sk-test", http: http)\nlet header = "x-api-key"',
    ".env.example": "CLAUDE_KEY=",
    "img.png": "sk-ant-api03-" + "A".repeat(40),
  };
  assert.deepEqual(scan(Object.keys(files), read(files)), []);
});

test("ключ без префікса в присвоєнні, інші БД, зашифрований ключ", () => {
  const files = {
    "a.swift": 'let braveKey = "' + "Q".repeat(30) + '"',
    "b.env.txt": "mongodb+srv://user" + ":pa55@cluster0.example.net/db",
    "c.txt": "-----BEGIN ENCRYPTED " + "PRIVATE KEY-----",
    "d.swift": 'let header = "x-api-key"; let key = KeychainKey.claude.load()',
  };
  const found = scan(Object.keys(files), read(files));
  assert.equal(found.length, 3);
  assert.ok(!found.some((f) => f.startsWith("d.swift")));
});

test("історія: додані рядки з назвою файлу", () => {
  const patch = "commit 1\n+++ b/k.swift\n+let k = 1\n-removed\n+++ b/i.png\n+binary";
  assert.deepEqual(addedLines(patch), [["k.swift", "let k = 1"]]);
});
