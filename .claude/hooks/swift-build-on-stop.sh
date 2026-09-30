#!/bin/sh
# Claude Code Stop hook: if .swift files changed in the working tree, `swift build`
# must pass before the agent ends its turn. Committed changes are checked by pre-commit.
input=$(cat)
cd "$(git rev-parse --show-toplevel)" || exit 0
git status --porcelain -- '*.swift' | grep -q . || exit 0
if output=$(swift build 2>&1); then
  exit 0
fi
# A repeated stop after blocking: do not loop, but leave a visible trace.
if printf '%s' "$input" | grep -q '"stop_hook_active": *true'; then
  echo "swift build still fails; the turn ended without a fix." >&2
  exit 0
fi
printf 'swift build fails after .swift changes; fix it before finishing:\n%s\n' \
  "$(printf '%s\n' "$output" | perl -pe 's/\e\[[0-9;]*m//g' | grep -E 'error:' | head -20)" >&2
exit 2
