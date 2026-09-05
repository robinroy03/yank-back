# yank-back

macOS hooks that **yank you back into the app** the moment your coding agent needs you.

The built-in notification tells you the agent is done. This one also brings the right window to the front, so you don't have to hunt for it.

Works with [Claude Code](#claude-code) and [Cursor](#cursor).

## Install

Each tool has its own one-liner. Want both? Run both.

Claude Code:

```sh
curl -fsSL https://raw.githubusercontent.com/robinroy03/yank-back/main/claude/install.sh | bash
```

Cursor:

```sh
curl -fsSL https://raw.githubusercontent.com/robinroy03/yank-back/main/cursor/install.sh | bash
```

Or from a clone:

```sh
git clone https://github.com/robinroy03/yank-back.git && cd yank-back
./claude/install.sh     # Claude Code
./cursor/install.sh     # Cursor
```

That's it. Hooks install at the user level, so they work in every project.

## Uninstall

Delete the yank-back entries from the config file and remove the script:

- Claude Code: `~/.claude/settings.json` and `~/.claude/hooks/yank-back.sh`
- Cursor: `~/.cursor/hooks.json` and `~/.cursor/hooks/yank-back.sh`

Each installer also leaves a `*.yank-back.bak` backup of the config next to the original, if you'd rather restore that.

---

## Claude Code

Yanks you back into the **terminal window** running that session when:

- Claude **finishes** a turn
- Claude is **waiting on a permission prompt**
- Claude **asks you a question**

If Claude Code is already running, type `/hooks` once so it reloads the config.

The first time it fires, macOS may ask you to grant your terminal **Accessibility** access (System Settings → Privacy & Security → Accessibility). That's what lets it raise a specific window.

### How it works

Claude Code runs the hook with the session's working directory on stdin and the terminal's bundle id in the environment. The script:

1. Posts a macOS notification with a sound.
2. Asks System Events for the terminal's windows and picks the one whose working directory (the `AXDocument` accessibility attribute) matches the session.
3. Un-minimizes and raises that window, then brings the terminal app to the front.

If no window matches, it still brings the terminal to the front.

### What it adds to `~/.claude/settings.json`

```jsonc
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/yank-back.sh \"Task done — ready for your next prompt\"",
          },
        ],
      },
    ],
    "Notification": [
      {
        "matcher": "permission_prompt|elicitation_dialog",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/yank-back.sh \"Claude Code is waiting for your input\"",
          },
        ],
      },
    ],
    "PreToolUse": [
      {
        "matcher": "AskUserQuestion",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/yank-back.sh \"Claude Code has a question for you\"",
          },
        ],
      },
    ],
  },
}
```

Existing hooks are kept. Re-running the installer replaces the yank-back entries instead of duplicating them. A backup is written to `settings.json.yank-back.bak`.

### Caveats

- **macOS only.** Uses `osascript` and System Events.
- **Tabs.** Tested with [Ghostty](https://ghostty.org), which exposes each window's working directory to the accessibility API. Window-level matching is reliable; a background _tab_ inside a multi-tab window may not be switched to, in which case you land in that app on the last active tab.
- **Other terminals.** iTerm2, Terminal.app, Kitty, WezTerm, etc. will be brought to the front. Whether the exact window is raised depends on whether the app exposes a working directory via accessibility.
- Multiple sessions in the same directory: the first matching window wins.
- The Stop hook also fires on `/clear`, resume, and compact.

---

## Cursor

Yanks you back into the **Cursor window** when an agent turn ends — the answer is ready, or it asked you a question.

Cursor reloads `hooks.json` on save. If it does not pick the hook up, restart Cursor.

The first time it fires, macOS may ask you to grant Cursor **Automation** / **Accessibility** access. Allow that, or focus restore will fail.

### How it works

Cursor runs a user-level [`stop` hook](https://cursor.com/docs/agent/hooks) when the agent loop ends. The script:

1. Posts a macOS notification with a sound.
2. Un-minimizes Cursor and brings it to the front.
3. If the hook payload includes `workspace_roots`, tries to raise the window whose title contains that folder name.

If no window matches, Cursor is still brought to the front. Cancelled runs (`aborted`) do not steal focus.

Cursor does not expose a hook for in-chat tool-permission prompts, so those will not yank you back — only a finished turn will.

### What it adds to `~/.cursor/hooks.json`

```jsonc
{
  "version": 1,
  "hooks": {
    "stop": [
      {
        "command": "~/.cursor/hooks/yank-back.sh \"Task done — ready for your next prompt\"",
        "timeout": 10,
      },
    ],
  },
}
```

Existing hooks are kept. Re-running the installer replaces the yank-back entries instead of duplicating them. A backup is written to `hooks.json.yank-back.bak`.

### Caveats

- **macOS only.** Uses `osascript` and System Events.
- **Multiple windows.** Matching is by workspace folder name in the window title. Two windows for folders with the same name: the first match wins.
- Cloud agents do not run user-level hooks, so this is local Cursor only.

---

## Options

Environment variables read by the hook:

| Variable                | Effect                                                                                            |
| ----------------------- | ------------------------------------------------------------------------------------------------- |
| `YANK_BACK_NO_NOTIFY=1` | Skip the macOS notification, only focus the window                                                |
| `YANK_BACK_BUNDLE_ID`   | Claude Code only: override the terminal app to focus (default: the app that launched Claude Code) |
| `YANK_BACK_DEBUG=1`     | Print which window matched to stderr                                                              |

For Claude Code, set them in `~/.claude/settings.json` under `"env"`. For Cursor, export them in your shell profile so the Cursor app inherits them, or wrap the hook command.

## Disclaimer

Code written by AI. I have not done any manual audit. But I do use it daily. So probably is safe :)

## License

MIT
