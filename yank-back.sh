#!/bin/bash
# yank-back — Claude Code hook that notifies you AND pulls you back into the
# terminal window running the session when Claude finishes, needs permission,
# or asks a question.
#
# Reads the hook JSON on stdin (uses .cwd and .message). $1 is the fallback
# message for events that carry none (e.g. Stop).
#
# How the window is found:
#   * The terminal app is taken from $__CFBundleIdentifier, which every macOS
#     app passes to the processes it spawns (Claude Code -> this hook).
#   * Ghostty (and some other terminals) expose each window's working
#     directory via the AX "AXDocument" attribute as a file:// URL. We match
#     that against the session cwd, un-minimize + raise that window.
#   * If nothing matches, we still bring the terminal app to the front.
#
# macOS only. Requires jq (bundled with macOS 15+, else `brew install jq`).

input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
msg=$(printf '%s' "$input" | jq -r '.message // empty' 2>/dev/null)
[ -z "$msg" ] && msg="${1:-Claude Code needs you}"
[ -z "$cwd" ] && cwd="$PWD"

bundle_id="${YANK_BACK_BUNDLE_ID:-${__CFBundleIdentifier:-com.mitchellh.ghostty}}"

# file:// URLs percent-encode each path segment (spaces -> %20 etc.)
cwd_url="file://$(jq -rn --arg p "$cwd" '$p | split("/") | map(@uri) | join("/")')"

if [ -z "$YANK_BACK_NO_NOTIFY" ]; then
  osascript -e 'on run argv' \
    -e 'display notification (item 1 of argv) with title "Claude Code" sound name "Glass"' \
    -e 'end run' "$msg" >/dev/null 2>&1
fi

# The accessibility tree is occasionally stale for a moment; retry briefly.
for attempt in 1 2 3; do
result=$(osascript - "$cwd_url" "$bundle_id" <<'APPLESCRIPT' 2>&1
on trimSlash(s)
  if s ends with "/" then return text 1 thru -2 of s
  return s
end trimSlash

on run argv
  set target to my trimSlash(item 1 of argv)
  set bid to item 2 of argv
  set matched to "none"
  tell application "System Events"
    set procs to (every application process whose bundle identifier is bid)
    if (count of procs) is 0 then return "no-process"
    tell first item of procs
      repeat with w in windows
        try
          set d to value of attribute "AXDocument" of w
          if d is not missing value then
            if my trimSlash(d) is equal to target then
              if (value of attribute "AXMinimized" of w) then
                set value of attribute "AXMinimized" of w to false
              end if
              perform action "AXRaise" of w
              set matched to (name of w) as text
              exit repeat
            end if
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

# Last resort if System Events could not see the app at all.
if [ "$result" = "no-process" ]; then
  open -b "$bundle_id" >/dev/null 2>&1
fi

[ -n "$YANK_BACK_DEBUG" ] && echo "yank-back: app=$bundle_id cwd=$cwd_url matched=$result" >&2
exit 0
