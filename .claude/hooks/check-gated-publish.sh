#!/usr/bin/env bash
# check-gated-publish.sh — advisory hook: warns when publish.yml is being written
# in a way that would lose the artifact-upload markers.
#
# Fires on Edit/Write targeting any publish.yml.
# Advisory only — exits 0 always (never blocks the edit).
# Reads the tool input JSON from stdin (Claude Code hook protocol).

set -euo pipefail

# shellcheck source=hook-lib.sh
. "$(dirname "$0")/hook-lib.sh"
hook_parse_input

[[ "$hook_file_path" =~ publish\.yml$ ]] || exit 0

new_content=$(printf '%s' "$hook_input" | python3 -c "
import sys, json
d = json.load(sys.stdin)
ti = d.get('tool_input', {})
print(ti.get('new_string', ti.get('content', '')))" 2>/dev/null || true)

missing=()
[[ "$new_content" =~ "upload-gem-artifact" ]]  || missing+=("upload-gem-artifact.sh call (artifact upload phase missing)")
[[ "$new_content" =~ "CI_PIPELINE_EVENT" ]]    || missing+=("CI_PIPELINE_EVENT guard (auto-bump runs on all events)")

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "⚠️  gated-publish: publish.yml may be losing artifact-upload markers:" >&2
  for m in "${missing[@]}"; do
    echo "   • $m" >&2
  done
  echo "   Run /gem-ci to check full compliance." >&2
fi

exit 0
