#!/bin/bash
# Removes yank-back hooks from ~/.cursor/hooks.json and deletes the script.
set -euo pipefail
CURSOR_DIR="${CURSOR_CONFIG_DIR:-$HOME/.cursor}"
SETTINGS="$CURSOR_DIR/hooks.json"
HOOK_DIR="$CURSOR_DIR/hooks"
HOOK_PATH="$HOOK_DIR/yank-back.sh"

if [ -f "$SETTINGS" ]; then
  tmp="$(mktemp)"
  jq '
    def strip: map(select(
      (.command? // "")
      | (contains("yank-back.sh") or contains("focus-on-stop.sh"))
      | not
    ));
    if .hooks then
      .hooks |= with_entries(.value |= strip)
      | .hooks |= with_entries(select(.value | length > 0))
      | if (.hooks | length) == 0 then del(.hooks) else . end
    else . end
  ' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
  echo "✓ Removed yank-back hooks from $SETTINGS"
fi
rm -f "$HOOK_PATH" "$HOOK_DIR/focus-on-stop.sh"
echo "✓ Removed $HOOK_PATH"
