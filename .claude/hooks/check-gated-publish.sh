#!/usr/bin/env bash
# check-gated-publish.sh — advisory hook: warns when publish.yml is being written
# in a way that would lose the RC-gate markers.
#
# Fires on Edit/Write targeting any publish.yml.
# Advisory only — exits 0 always (never blocks the edit).
# Reads the tool input JSON from stdin (Claude Code hook protocol).

set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" \
  2>/dev/null || true)

[[ -z "$file_path" ]] && exit 0
[[ "$file_path" =~ publish\.yml$ ]] || exit 0

new_content=$(echo "$input" | python3 -c "
import sys, json
d = json.load(sys.stdin)
ti = d.get('tool_input', {})
print(ti.get('new_string', ti.get('content', '')))" 2>/dev/null || true)

missing=()
[[ "$new_content" =~ "build-rc-gem" ]]       || missing+=("build-rc-gem.sh call (RC build phase missing)")
[[ "$new_content" =~ "CI_PIPELINE_EVENT" ]]  || missing+=("CI_PIPELINE_EVENT guard (auto-bump runs on all events)")

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "⚠️  gated-publish: publish.yml may be losing RC-gate markers:" >&2
  for m in "${missing[@]}"; do
    echo "   • $m" >&2
  done
  echo "   Run /gem-ci to check full compliance." >&2
fi

exit 0
