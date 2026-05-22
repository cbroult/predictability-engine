#!/usr/bin/env bash
# Shared helpers for Claude Code PreToolUse hooks.

# Reads stdin JSON; sets hook_input and hook_file_path.
# Exits 0 immediately when no file_path is present (nothing to guard against).
hook_parse_input() {
  hook_input=$(cat)
  hook_file_path=$(printf '%s' "$hook_input" | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" \
    2>/dev/null || true)
  [[ -z "$hook_file_path" ]] && exit 0
}
