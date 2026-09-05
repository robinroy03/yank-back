#!/bin/bash
# yank-back installer (Claude Code)
#   curl -fsSL https://raw.githubusercontent.com/robinroy03/yank-back/main/claude/install.sh | bash
#
# Installs ~/.claude/hooks/yank-back.sh and merges three hooks into
# ~/.claude/settings.json (user-level, so it applies to every project):
#   Stop                          -> Claude finished a turn
#   Notification (permission /
#                 elicitation)    -> Claude is waiting on you
#   PreToolUse (AskUserQuestion)  -> Claude is asking you a question
#
# Safe to re-run: existing settings and other hooks are preserved, and
# yank-back entries are replaced rather than duplicated.
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/robinroy03/yank-back/main"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
HOOK_DIR="$CLAUDE_DIR/hooks"
HOOK_PATH="$HOOK_DIR/yank-back.sh"
SETTINGS="$CLAUDE_DIR/settings.json"
HOOK_CMD="~/.claude/hooks/yank-back.sh"

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
  curl -fsSL "$REPO_RAW/claude/yank-back.sh" -o "$HOOK_PATH"
fi
chmod +x "$HOOK_PATH"

[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
if ! jq -e . "$SETTINGS" >/dev/null 2>&1; then
  echo "$SETTINGS is not valid JSON. Fix it first, then re-run." >&2
  exit 1
fi

cp "$SETTINGS" "$SETTINGS.yank-back.bak"

tmp="$(mktemp)"
jq --arg cmd "$HOOK_CMD" '
  # Drop any previously installed yank-back entries so re-running is idempotent.
  def strip: map(select(
    (.hooks // []) | any(.command? // "" | contains("yank-back.sh")) | not
  ));
  def entry($matcher; $msg): {
    matcher: $matcher,
    hooks: [{type: "command", command: ($cmd + " \"" + $msg + "\""), timeout: 10}]
  };
  .hooks //= {}
  | .hooks.Stop         = ((.hooks.Stop         // []) | strip) + [entry("";                                       "Task done — ready for your next prompt")]
  | .hooks.Notification = ((.hooks.Notification // []) | strip) + [entry("permission_prompt|elicitation_dialog";   "Claude Code is waiting for your input")]
  | .hooks.PreToolUse   = ((.hooks.PreToolUse   // []) | strip) + [entry("AskUserQuestion";                        "Claude Code has a question for you")]
' "$SETTINGS.yank-back.bak" > "$tmp"
mv "$tmp" "$SETTINGS"

echo "✓ Installed $HOOK_PATH"
echo "✓ Hooks merged into $SETTINGS (backup: $SETTINGS.yank-back.bak)"
echo
echo "If Claude Code is already running, open /hooks once (or restart) to reload."
echo "macOS may ask to grant your terminal Accessibility access the first time it fires."
