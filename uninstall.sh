#!/bin/bash
# Removes yank-back hooks from ~/.claude/settings.json and deletes the script.
set -euo pipefail
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"
HOOK_PATH="$CLAUDE_DIR/hooks/yank-back.sh"

if [ -f "$SETTINGS" ]; then
  tmp="$(mktemp)"
  jq '
    def strip: map(select(
      (.hooks // []) | any(.command? // "" | contains("yank-back.sh")) | not
    ));
    if .hooks then
      .hooks |= with_entries(.value |= strip)
      | .hooks |= with_entries(select(.value | length > 0))
      | if (.hooks | length) == 0 then del(.hooks) else . end
    else . end
  ' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
  echo "✓ Removed yank-back hooks from $SETTINGS"
fi
rm -f "$HOOK_PATH" && echo "✓ Removed $HOOK_PATH"
