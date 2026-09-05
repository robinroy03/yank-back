#!/bin/bash
# Removes yank-back from Claude Code and/or Cursor.
#   ./uninstall.sh           # both
#   ./uninstall.sh claude
#   ./uninstall.sh cursor
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/robinroy03/yank-back/main"
target="${1:-all}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"

run_uninstaller() {
  local name="$1"
  if [ -n "$script_dir" ] && [ -f "$script_dir/$name/uninstall.sh" ]; then
    bash "$script_dir/$name/uninstall.sh"
  else
    curl -fsSL "$REPO_RAW/$name/uninstall.sh" | bash
  fi
}

case "$target" in
  all)
    run_uninstaller claude
    run_uninstaller cursor
    ;;
  claude|cursor)
    run_uninstaller "$target"
    ;;
  *)
    echo "usage: uninstall.sh [all|claude|cursor]" >&2
    exit 1
    ;;
esac
