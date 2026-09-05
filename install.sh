#!/bin/bash
# yank-back installer
#   curl -fsSL https://raw.githubusercontent.com/robinroy03/yank-back/main/install.sh | bash
#
# Installs Claude Code and/or Cursor hooks. Default is both.
#   ./install.sh           # both
#   ./install.sh claude
#   ./install.sh cursor
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/robinroy03/yank-back/main"
target="${1:-all}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"

run_installer() {
  local name="$1"
  if [ -n "$script_dir" ] && [ -f "$script_dir/$name/install.sh" ]; then
    bash "$script_dir/$name/install.sh"
  else
    curl -fsSL "$REPO_RAW/$name/install.sh" | bash
  fi
}

case "$target" in
  all)
    run_installer claude
    echo
    run_installer cursor
    ;;
  claude|cursor)
    run_installer "$target"
    ;;
  *)
    echo "usage: install.sh [all|claude|cursor]" >&2
    exit 1
    ;;
esac
