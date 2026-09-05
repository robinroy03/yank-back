# yank-back

A [Claude Code](https://claude.com/claude-code) hook for macOS that **yanks you back into your terminal** the moment Claude needs you.

The built-in notification tells you Claude is done. This one also brings the terminal window running that session to the front, so you don't have to hunt for it. It fires when:

- Claude **finishes** a turn
- Claude is **waiting on a permission prompt**
- Claude **asks you a question**

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/robinroy03/yank-back/main/install.sh | bash
```

Or from a clone:

```sh
git clone https://github.com/robinroy03/yank-back.git && cd yank-back && ./install.sh
```

That's it. It installs to your user-level Claude settings, so it works in every project. If Claude Code is already running, type `/hooks` once so it reloads the config.

The first time it fires, macOS may ask you to grant your terminal **Accessibility** access (System Settings → Privacy & Security → Accessibility). That's what lets it raise a specific window.

## Uninstall

```sh
curl -fsSL https://raw.githubusercontent.com/robinroy03/yank-back/main/uninstall.sh | bash
```

## How it works

Claude Code runs the hook with the session's working directory on stdin and the terminal's bundle id in the environment. The script:

1. Posts a macOS notification with a sound.
2. Asks System Events for the terminal's windows and picks the one whose working directory (the `AXDocument` accessibility attribute) matches the session.
3. Un-minimizes and raises that window, then brings the terminal app to the front.

If no window matches, it still brings the terminal to the front.

## What it adds to `~/.claude/settings.json`

```jsonc
{
  "hooks": {
    "Stop":         [{ "matcher": "",                                     "hooks": [{ "type": "command", "command": "~/.claude/hooks/yank-back.sh \"Task done — ready for your next prompt\"" }] }],
    "Notification": [{ "matcher": "permission_prompt|elicitation_dialog", "hooks": [{ "type": "command", "command": "~/.claude/hooks/yank-back.sh \"Claude Code is waiting for your input\"" }] }],
    "PreToolUse":   [{ "matcher": "AskUserQuestion",                      "hooks": [{ "type": "command", "command": "~/.claude/hooks/yank-back.sh \"Claude Code has a question for you\"" }] }]
  }
}
```

Existing hooks are kept. Re-running the installer replaces the yank-back entries instead of duplicating them. A backup is written to `settings.json.yank-back.bak`.

## Caveats

- **macOS only.** Uses `osascript` and System Events.
- **Tabs.** Tested with [Ghostty](https://ghostty.org), which exposes each window's working directory to the accessibility API. Window-level matching is reliable; a background *tab* inside a multi-tab window may not be switched to, in which case you land in that app on the last active tab.
- **Other terminals.** iTerm2, Terminal.app, Kitty, WezTerm, etc. will be brought to the front. Whether the exact window is raised depends on whether the app exposes a working directory via accessibility.
- Multiple sessions in the same directory: the first matching window wins.
- The Stop hook also fires on `/clear`, resume, and compact.

## Options

Environment variables read by the hook (set them in `settings.json` under `"env"` if you want):

| Variable | Effect |
|---|---|
| `YANK_BACK_NO_NOTIFY=1` | Skip the macOS notification, only focus the window |
| `YANK_BACK_BUNDLE_ID` | Override the terminal app to focus (default: the app that launched Claude Code) |
| `YANK_BACK_DEBUG=1` | Print which window matched to stderr |

## License

MIT
