#!/bin/sh
# Stop-хук Claude Code: якщо в робочому дереві змінено .swift-файли, `swift build`
# має пройти, перш ніж агент завершить хід. Закомічені зміни перевіряє pre-commit.
input=$(cat)
cd "$(git rev-parse --show-toplevel)" || exit 0
git status --porcelain -- '*.swift' | grep -q . || exit 0
if output=$(swift build 2>&1); then
  exit 0
fi
# Повторна зупинка після блокування: не зациклюємось, але лишаємо видимий слід.
if printf '%s' "$input" | grep -q '"stop_hook_active": *true'; then
  echo "swift build досі падає; хід завершено без виправлення." >&2
  exit 0
fi
printf 'swift build падає після змін у .swift — виправ перед завершенням:\n%s\n' \
  "$(printf '%s\n' "$output" | perl -pe 's/\e\[[0-9;]*m//g' | grep -E 'error:' | head -20)" >&2
exit 2
