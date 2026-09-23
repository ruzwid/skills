# Raycast Script Command metadata reference

Source: [manual.raycast.com/script-commands](https://manual.raycast.com/script-commands) and the
[raycast/script-commands](https://github.com/raycast/script-commands) repo (README, `documentation/ARGUMENTS.md`,
`documentation/OUTPUTMODES.md`).

Metadata is a block of `@raycast.<field> <value>` comments, one per line, using either `#` or `//`
comments (match whatever the language's comment style is). Order doesn't matter, but this user's
existing scripts group them under `# Required parameters:`, `# Optional parameters:`, and
`# Documentation:` headers — keep doing that.

## Field table

| Field | Required | Description |
|---|---|---|
| `schemaVersion` | **Yes** | Always `1`. |
| `title` | **Yes** | Display name shown in Raycast's root search. |
| `mode` | **Yes** | `silent` \| `compact` \| `fullOutput` \| `inline`. See [Modes](#modes). |
| `packageName` | No | Subtitle shown under the title. Defaults to the script's directory name if omitted. |
| `icon` | No | Emoji, a file path (relative or absolute), or a remote `https` URL. PNG/JPEG, ~64px recommended. |
| `iconDark` | No | Same as `icon` but used in dark theme. Falls back to `icon` if unset. |
| `currentDirectoryPath` | No | Working directory the script runs from. Absolute, relative, or `~`. Defaults to the script's own folder. |
| `needsConfirmation` | No | `true`/`false` (default `false`). Shows a confirm dialog first — use for destructive actions. |
| `refreshTime` | No | **Required for `inline` mode.** Interval like `10s`, `1m`, `12h`, `1d`. Minimum 10s. Only the first 10 inline commands auto-refresh; the rest need manual refresh. |
| `argument1` / `argument2` / `argument3` | No | Up to 3 input fields. JSON value — see [Arguments](#arguments). |
| `author` | No | Author name. |
| `authorURL` | No | Link/contact for the author. |
| `description` | No | One-line summary of what the command does. |
| `platform` | No | `macos` (default) or `windows`. |

## Arguments

`argumentN`'s value must be valid JSON:

| JSON field | Required | Notes |
|---|---|---|
| `type` | **Yes** | `"text"`, `"password"` (masked input, e.g. secrets), or `"dropdown"`. |
| `placeholder` | **Yes** | Placeholder text in the input field. |
| `optional` | No | `true` to make it optional. Default: required — Raycast won't let the user run the script with an empty required argument. |
| `percentEncoded` | No | `true` to have Raycast percent-encode the value before it's passed to the script. Handy when the argument feeds straight into a URL query string. |
| `data` | Required when `type` is `dropdown` | Array of `{"title": "...", "value": "..."}` objects. |

Max 3 arguments total. Arguments are passed positionally as `$1`, `$2`, `$3` (bash) /
`process.argv[2..]` (node) / `ARGV`/`sys.argv` etc depending on language.

Example (two arguments, one optional, both percent-encoded into a URL):

```bash
#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Search Flights
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🛩
# @raycast.packageName Web Searches
# @raycast.argument1 { "type": "text", "placeholder": "from city", "percentEncoded": true }
# @raycast.argument2 { "type": "text", "placeholder": "to city", "optional": true, "percentEncoded": true }

open "https://www.google.com/search?q=flights%20from%20$1%20to%20$2"
```

Dropdown example:

```bash
# @raycast.argument1 { "type": "dropdown", "placeholder": "Environment", "data": [{"title": "Production", "value": "prod"}, {"title": "Staging", "value": "staging"}] }
```

A script whose first argument is optional text (and any other arguments are also optional) can act
as a Raycast **Fallback Command**, capturing whatever the user typed that didn't match anything else.

## Modes

- **`fullOutput`** — the entire stdout is shown in a scrollable, terminal-like view. Best for output
  worth reading in full (multi-line listings, logs). Supports ANSI colors.
- **`compact`** — Raycast closes and shows the *last line* of stdout in a toast. Best for short
  confirmations ("Copied to clipboard", "Deployed ✅").
- **`silent`** — no window at all; if there *is* output, the last line briefly appears in an
  overlaying HUD toast after Raycast's own window has closed. Best for fire-and-forget actions.
- **`inline`** — the *first line* of stdout is shown directly inline in the root search results and
  auto-refreshes on `refreshTime`. Requires `refreshTime`; if omitted, Raycast silently falls back to
  `compact`. Supports ANSI colors. Best for live dashboard-style values.

Long-running scripts that emit lots of partial/streamed output (e.g. `zip` without `-q`) don't work
well in `compact`, `silent`, or `inline` — use `fullOutput` for those, or make the underlying command
quiet (e.g. `zip -q`).

## Error handling

A non-zero exit code = failure. Raycast shows a "script failed to run" toast. In `compact`/`silent`/
`inline` modes, the **last line of output** becomes the error message shown to the user — so print a
clear, human-readable message right before exiting non-zero:

```bash
if ! [[ $value =~ $regex ]]; then
  echo "Invalid value provided"
  exit 1
fi
```

## ANSI colors (`inline` and `fullOutput` only)

Escape code `0x1B`, standard ANSI codes. Colors adapt to the user's current light/dark appearance.

| Color | Foreground | Background |
|---|---|---|
| Black | 30 | 40 |
| Red | 31 | 41 |
| Green | 32 | 42 |
| Yellow | 33 | 43 |
| Blue | 34 | 44 |
| Magenta | 35 | 45 |
| Cyan | 36 | 46 |
| White | 97 | 107 |

Also supports 8-bit/24-bit color codes, `0` reset, `4` underline, `9` crossed out. Unsupported codes
are stripped silently.

```bash
echo -e '\033[31;42mred text on green background\033[0m'
```

## File / discovery requirements

- Script must be **executable** (`chmod +x`) — a shebang alone isn't enough.
- Filename must **not** contain the literal string `.template.` (Raycast explicitly excludes those —
  it's the convention the community repo uses to mark scaffolds that need editing first).
- File extension should match the language (`.sh`, `.py`, `.js`, `.applescript`, `.rb`, `.swift`,
  `.php`) so Raycast/the OS pick the right interpreter; a shebang line is still required.
- Metadata comments must use `#` or `//` matching the language.
- Scripts run in a **non-login, non-interactive shell**. If a script depends on things normally set
  up by `.bash_profile`/`.zshrc` (custom `$PATH` entries, aliases, nvm/rbenv shims), either add
  `export PATH="/some/extra/path:$PATH"` explicitly near the top, or use a login shebang like
  `#!/bin/bash -l`. Raycast does append `/usr/local/bin` to `$PATH` automatically.
  - **Concretely, for nvm-managed node/npm** (the common case — `command not found: npm` when
    the same script works fine in a terminal): sourcing `nvm.sh` isn't reliable non-interactively,
    so just resolve and prepend the newest installed version's bin dir directly:
    ```bash
    NODE_BIN_DIR="$(ls -d "$HOME"/.nvm/versions/node/*/bin 2>/dev/null | sort -V | tail -1)"
    [ -n "$NODE_BIN_DIR" ] && PATH="$NODE_BIN_DIR:$PATH"
    export PATH
    ```
    Put this before anything in the script (or a script it calls) shells out to `npm`/`node`.
- macOS permission prompts (Accessibility, Automation, Full Disk Access) triggered by a script must be
  granted to **Raycast**, not Terminal — Raycast is the actual process running the script.

## Built-in interpreters

macOS: bash/zsh, Python, Node.js, Ruby, PHP, Swift, `osascript`/AppleScript (`.applescript` preferred
over compiled `.scpt`), .NET/C#.
Windows: PowerShell (`.ps1`, note default execution policy `Restricted` blocks scripts — needs
`RemoteSigned` or similar), C#, Python, Node.js, Bash via WSL/Git Bash.
