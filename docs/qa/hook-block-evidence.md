# Hook block evidence (PD-19)

A real run of the Claude Code `PreToolUse` hook (`scripts/claude-hooks.mjs pre-edit`, wired in
`.claude/settings.json` for `Write|Edit|MultiEdit`). Exit code 2 means Claude Code blocks the tool call
and shows the message to the agent. Recorded on 2026-10-01 on `master` after PR #31.

The fake key is built at run time, so this file does not contain a key and passes the secret scanner.

## 1. The agent tries to write an API key into code

```bash
K="sk-ant-api03-$(printf 'A%.0s' {1..40})"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s/Sources/BibleCore/Demo.swift","content":"let key = \\"%s\\""}}' "$PWD" "$K" \
  | node scripts/claude-hooks.mjs pre-edit; echo "exit=$?"
```

```
Sources/BibleCore/Demo.swift: the text looks like Anthropic API key. API keys belong only in the Keychain, not in project files.
exit=2
```

## 2. The agent tries to edit a generated file by hand

```bash
printf '{"tool_name":"Edit","tool_input":{"file_path":"%s/BibleReaderApp/BibleReader.xcodeproj/project.pbxproj","old_string":"a","new_string":"b"}}' "$PWD" \
  | node scripts/claude-hooks.mjs pre-edit; echo "exit=$?"
```

```
BibleReaderApp/BibleReader.xcodeproj/project.pbxproj is generated: do not edit it by hand, run: cd BibleReaderApp && xcodegen generate (from project.yml).
exit=2
```

The same cases are covered by `node --test scripts/claude-hooks.test.mjs` in the CI step "Secrets scan".
