#!/usr/bin/env bash
# .claude/hooks/protect-alignment.sh
#
# PreToolUse hook: blocks Edit / Write / NotebookEdit calls that target a
# forecast-alignment verification file (see CLAUDE.md §"Forecast alignment
# invariant") unless the HEAD commit message or the current commit draft at
# .git/COMMIT_EDITMSG contains the literal token `[unlock-alignment]`.
#
# Exit 0  → edit allowed (not protected, or unlock token present)
# Exit 2  → edit blocked (output shown to Claude)

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

PAYLOAD=$(cat)

FILE_PATH=$(echo "$PAYLOAD" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null) || true

# No file_path → not an Edit/Write/NotebookEdit call we care about.
[ -n "$FILE_PATH" ] || exit 0

# Normalise to a path relative to REPO_ROOT (hook only cares about this repo).
case "$FILE_PATH" in
  "$REPO_ROOT"/*) REL="${FILE_PATH#"$REPO_ROOT"/}" ;;
  /*) exit 0 ;;
  *) REL="$FILE_PATH" ;;
esac

PROTECTED_EXACT=(
  "features/forecast_alignment.feature"
  "spec/predictability_engine/forecast_alignment_spec.rb"
)

# Files that are only conditionally protected: visualization_steps.rb is
# protected only when the edit touches one of the protected step phrases.
STEP_DEF_FILE="features/step_definitions/visualization_steps.rb"
PROTECTED_STEP_PHRASES=(
  "should have confidence rules hit the local surface"
  "should have confidence rules hit the forecast plateau"
  "should have confidence rules aligned with the rightmost part of forecast areas"
  "compute_plateau"
)

is_protected=0
for p in "${PROTECTED_EXACT[@]}"; do
  [ "$REL" = "$p" ] && is_protected=1 && break
done

if [ "$is_protected" -eq 0 ] && [ "$REL" = "$STEP_DEF_FILE" ]; then
  # Inspect old_string / new_string for any protected phrase.
  STRINGS=$(echo "$PAYLOAD" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin).get('tool_input', {})
    parts = []
    for k in ('old_string', 'new_string', 'content'):
        v = d.get(k)
        if isinstance(v, str):
            parts.append(v)
    for edit in d.get('edits', []) or []:
        for k in ('old_string', 'new_string'):
            v = edit.get(k)
            if isinstance(v, str):
                parts.append(v)
    print('\n'.join(parts))
except Exception:
    pass
" 2>/dev/null) || true
  for phrase in "${PROTECTED_STEP_PHRASES[@]}"; do
    if echo "$STRINGS" | grep -qF -- "$phrase"; then
      is_protected=1
      break
    fi
  done
fi

[ "$is_protected" -eq 1 ] || exit 0

# Check for the unlock token in the last commit message or the in-flight draft.
TOKEN='[unlock-alignment]'

HEAD_MSG=$(git -C "$REPO_ROOT" log -1 --format=%B 2>/dev/null || true)
DRAFT_MSG=$(cat "$REPO_ROOT/.git/COMMIT_EDITMSG" 2>/dev/null || true)

if echo "$HEAD_MSG$DRAFT_MSG" | grep -qF -- "$TOKEN"; then
  echo "🔓 Forecast alignment file edit allowed — '$TOKEN' found in commit message." >&2
  exit 0
fi

cat >&2 <<MSG
❌ BLOCKED: edit to $REL

This file is protected by the forecast-alignment invariant.
See CLAUDE.md §"Forecast alignment invariant".

To authorize a change:
  1. Ensure the modification is truly required (the rule is load-bearing —
     every refactor to date has re-broken CFD confidence-line alignment).
  2. Add the token '$TOKEN' to your next commit message, e.g.:
       git commit --allow-empty -m "chore: unlock forecast alignment $TOKEN"
     OR write it into .git/COMMIT_EDITMSG before retrying.
  3. Retry the edit.

This guard exists to prevent silent regressions in
  lib/predictability_engine/vega_visualizer/cfd_layout.rb.
MSG
exit 2
