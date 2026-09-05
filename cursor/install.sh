#!/bin/bash
# yank-back installer (Cursor)
#   curl -fsSL https://raw.githubusercontent.com/robinroy03/yank-back/main/cursor/install.sh | bash
#
# Installs ~/.cursor/hooks/yank-back.sh and merges a `stop` hook into
# ~/.cursor/hooks.json (user-level, so it applies to every project).
# The stop event fires when an agent turn ends — answer ready, or it
# asked you a question.
#
# Safe to re-run: existing hooks are preserved, and yank-back entries
# are replaced rather than duplicated.
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/robinroy03/yank-back/main"
CURSOR_DIR="${CURSOR_CONFIG_DIR:-$HOME/.cursor}"
HOOK_DIR="$CURSOR_DIR/hooks"
HOOK_PATH="$HOOK_DIR/yank-back.sh"
SETTINGS="$CURSOR_DIR/hooks.json"
HOOK_CMD="~/.cursor/hooks/yank-back.sh"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "yank-back only supports macOS (it uses osascript / System Events)." >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required. Install it with: brew install jq" >&2
  exit 1
fi

mkdir -p "$HOOK_DIR"

# Prefer a local copy when run from a checkout, otherwise download.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -n "$script_dir" ] && [ -f "$script_dir/yank-back.sh" ]; then
  cp "$script_dir/yank-back.sh" "$HOOK_PATH"
else
  curl -fsSL "$REPO_RAW/cursor/yank-back.sh" -o "$HOOK_PATH"
fi
chmod +x "$HOOK_PATH"

[ -f "$SETTINGS" ] || echo '{"version":1,"hooks":{}}' > "$SETTINGS"
if ! jq -e . "$SETTINGS" >/dev/null 2>&1; then
  echo "$SETTINGS is not valid JSON. Fix it first, then re-run." >&2
  exit 1
fi

cp "$SETTINGS" "$SETTINGS.yank-back.bak"

tmp="$(mktemp)"
jq --arg cmd "$HOOK_CMD" '
  def strip: map(select(
    (.command? // "")
    | (contains("yank-back.sh") or contains("focus-on-stop.sh"))
    | not
  ));
  .version //= 1
  | .hooks //= {}
  | .hooks.stop = ((.hooks.stop // []) | strip) + [{
      command: ($cmd + " \"Task done — ready for your next prompt\""),
      timeout: 10
    }]
' "$SETTINGS.yank-back.bak" > "$tmp"
mv "$tmp" "$SETTINGS"

# Drop the earlier one-off script if it is still sitting around.
rm -f "$HOOK_DIR/focus-on-stop.sh"

echo "✓ Installed $HOOK_PATH"
echo "✓ Hooks merged into $SETTINGS (backup: $SETTINGS.yank-back.bak)"
echo
echo "Cursor reloads hooks.json on save. If it does not pick this up, restart Cursor."
echo "macOS may ask to grant Cursor Automation / Accessibility access the first time it fires."
