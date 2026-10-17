#!/usr/bin/env bash
# Downloads Yuriy Popchenko's New Testament (bolls.life `PPCH`) and converts it into the local, git-ignored
# data/raw/uk_popchenko.json (FR-43, PRD 6.22). The text is under copyright: personal use only, never commit it.
# Then `make db` picks the file up; without it `make db` skips the translation.
#
# Print fixes: scripts/ppch_print_fixes.json lists the verses taken whole from the owner's printed edition
# because the source has a defect there (a typo, or the verse is missing, e.g. Rev 22:21).
set -euo pipefail
cd "$(dirname "$0")/.."

url="https://bolls.life/static/translations/PPCH.zip"
out="data/raw/uk_popchenko.json"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

curl -fsSL "$url" -o "$work/PPCH.zip"
unzip -q "$work/PPCH.zip" -d "$work/unzipped"
source_json="$(find "$work/unzipped" -name '*.json' | head -n 1)"
[ -n "$source_json" ] || { echo "no .json inside $url" >&2; exit 1; }

python3 -I scripts/convert_getbible.py "$source_json" "$out" --nt \
  --align-to data/raw/en_kjv.json --fixes scripts/ppch_print_fixes.json
echo "Next: make db"
