#!/usr/bin/env bash
# Enforces BDD/TDD: warn when an implementation file is being written or edited
# without a corresponding spec or feature file being touched in the same session.
#
# Fires on Edit/Write targeting lib/**/*.rb.
# Reads the tool input JSON from stdin (Claude Code hook protocol).
# Exits 0 (allow) always — this is a warning hook, not a blocker — but prints
# a visible reminder so the human and model see it.

set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || true)

[[ -z "$file_path" ]] && exit 0

# Only care about lib/ Ruby files
[[ "$file_path" =~ /lib/.*\.rb$ ]] || exit 0

# Derive expected spec path: lib/foo/bar.rb -> spec/foo/bar_spec.rb
relative="${file_path##*/lib/}"
spec_path="$(dirname "$file_path")/../spec/${relative%.rb}_spec.rb"
spec_path=$(python3 -c "import os; print(os.path.normpath('$spec_path'))" 2>/dev/null || echo "$spec_path")

# Also check for a feature file anywhere under features/
base_name=$(basename "${file_path%.rb}")
feature_exists=$(find "$(dirname "$file_path")/../features" -name "*.feature" -exec grep -l "$base_name" {} \; 2>/dev/null | head -1)

if [[ ! -f "$spec_path" ]] && [[ -z "$feature_exists" ]]; then
  echo "⚠️  BDD/TDD: no spec or feature found for $(basename "$file_path")" >&2
  echo "   Expected spec : $spec_path" >&2
  echo "   Write the test first, or add coverage before committing." >&2
fi

exit 0
