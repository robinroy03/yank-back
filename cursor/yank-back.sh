#!/bin/bash
# yank-back — Cursor hook that notifies you AND pulls the Cursor window to
# the front when an agent turn finishes (answer ready, or it asked you
# something).
#
# Reads the hook JSON on stdin (uses .status and .workspace_roots). $1 is
# the fallback notification message.
#
# How the window is found:
#   * `tell application "Cursor" to activate` brings the app forward.
#   * If the hook payload includes workspace_roots, we try to raise the
#     Cursor window whose title contains that folder name.
#   * If nothing matches, Cursor is still brought to the front.
#
# macOS only. Requires jq (bundled with macOS 15+, else `brew install jq`).

input=$(cat)
status=$(printf '%s' "$input" | jq -r '.status // empty' 2>/dev/null)
workspace=$(printf '%s' "$input" | jq -r '.workspace_roots[0] // empty' 2>/dev/null)
msg="${1:-Cursor needs you}"

# User cancelled — don't yank focus back.
if [ "$status" = "aborted" ]; then
  exit 0
fi

needle=""
if [ -n "$workspace" ]; then
  needle="${workspace%/}"
  needle="${needle##*/}"
fi

if [ -z "$YANK_BACK_NO_NOTIFY" ]; then
  osascript -e 'on run argv' \
    -e 'display notification (item 1 of argv) with title "Cursor" sound name "Glass"' \
    -e 'end run' "$msg" >/dev/null 2>&1
fi

osascript >/dev/null 2>&1 <<'EOF' || open -a Cursor
tell application "Cursor"
  reopen
  activate
end tell
EOF

# Best-effort: raise the window for this workspace (needs Accessibility).
if [ -n "$needle" ]; then
  for attempt in 1 2 3; do
    result=$(osascript - "$needle" <<'APPLESCRIPT' 2>&1
on run argv
  set needle to item 1 of argv
  set matched to "none"
  tell application "System Events"
    set procs to (every application process whose name is "Cursor")
    if (count of procs) is 0 then return "no-process"
    tell first item of procs
      repeat with w in windows
        try
          set n to (name of w) as text
          if n contains needle then
            if (value of attribute "AXMinimized" of w) then
              set value of attribute "AXMinimized" of w to false
            end if
            perform action "AXRaise" of w
            set matched to n
            exit repeat
          end if
        end try
      end repeat
      set frontmost to true
    end tell
  end tell
  return matched
end run
APPLESCRIPT
)
    [ "$result" != "none" ] && break
    [ "$attempt" -lt 3 ] && sleep 0.25
  done
  [ -n "$YANK_BACK_DEBUG" ] && echo "yank-back: workspace=$workspace needle=$needle matched=$result" >&2
fi

exit 0
