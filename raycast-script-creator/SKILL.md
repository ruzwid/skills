---
name: raycast-script-creator
description: |
  Create, edit, or validate Raycast Script Commands — the scripts that show up as
  commands in Raycast's search results (schemaVersion/title/mode metadata comments,
  argument1-3, icons, modes). Use this whenever the user wants a new Raycast script,
  wants to add/tweak a command in their Raycast scripts folder (~/scripts), asks
  "make this a Raycast command", or is debugging why a script isn't showing up in
  Raycast or is failing when run from it. Not for building full Raycast extensions
  (that's the separate Extensions API/React toolkit) — this is specifically for the
  lightweight shebang-script style of Script Commands.
metadata:
  version: "1.0.0"
---

# Raycast Script Command Creator

Raycast Script Commands are ordinary executable scripts with a block of `@raycast.*`
metadata comments at the top. Raycast scans a watched folder, parses that metadata,
and turns each valid script into a searchable command. There's no compilation step
and no SDK — the script itself *is* the command.

This user's Script Commands live in **`/Users/ruzzelwidjaja/scripts`**. That folder
is (or should be) added in Raycast under Settings → Extensions → Script Commands →
Add Script Directory. New scripts dropped into that folder are picked up automatically
(no restart needed); Raycast just needs the folder added once.

## Workflow

1. **Understand the task.** What should running this command actually do? That
   determines the language, the arguments, and — most importantly — the `mode`
   (see below). If the user's request is ambiguous about what feedback they want,
   default to `compact` for anything that produces a short result, and ask if it's
   genuinely unclear.

2. **Pick a language.** Default to bash (`#!/bin/bash`) unless the task clearly
   wants something else (JSON/HTTP work → node or python; native macOS UI dialogs
   or app scripting → osascript/AppleScript; matches an existing script's stack).
   Templates for every supported language are in `templates/`.

3. **Pick a `mode`.** This is the one field people get wrong most often — read
   `references/metadata-reference.md#modes` before guessing. Quick summary:
   - `silent` — no visible window; last line of output (if any) briefly shows in a
     HUD toast after Raycast closes. Good for fire-and-forget actions (toggle
     something, copy to clipboard, open an app).
   - `compact` — Raycast closes and shows the *last line* of stdout in a toast.
     Good for short confirmations/results.
   - `fullOutput` — output renders in a terminal-like view inside Raycast. Good
     when the output is multi-line and worth reading (logs, `git status`, listings).
   - `inline` — output appears directly in the Raycast root search results and
     auto-refreshes. Requires `refreshTime`. Good for dashboard-style live values
     (battery %, unread count, current branch).

4. **Write the script** using the metadata block format below, matching the style
   of this user's existing scripts (see `/Users/ruzzelwidjaja/scripts/test-raycast-script.sh`
   for their conventions: `# Required parameters:` / `# Optional parameters:` /
   `# Documentation:` section comments, `@raycast.author ruzzel`,
   `@raycast.authorURL https://raycast.com/ruzzel`).

   ```bash
   #!/bin/bash

   # Required parameters:
   # @raycast.schemaVersion 1
   # @raycast.title <Human-readable command name>
   # @raycast.mode <silent|compact|fullOutput|inline>

   # Optional parameters:
   # @raycast.icon 🤖
   # @raycast.packageName <group shown as subtitle>
   # @raycast.description <one-line description>
   # @raycast.argument1 { "type": "text", "placeholder": "..." }

   # Documentation:
   # @raycast.author ruzzel
   # @raycast.authorURL https://raycast.com/ruzzel

   # script body
   ```

   Only include `@raycast.argument1/2/3` if the command actually needs input —
   don't add arguments speculatively. Full JSON syntax for each argument `type`
   (`text`, `password`, `dropdown`) is in the reference doc.

5. **Make it executable and save it** to `/Users/ruzzelwidjaja/scripts/<kebab-case-name>.<ext>`.
   Run `chmod +x` on it — Raycast requires the file to actually be executable, not
   just have a shebang. Never put the literal string `.template.` in the filename;
   Raycast explicitly skips those.

6. **Handle errors correctly.** Any non-zero exit code is treated as a failure by
   Raycast, and it shows a toast built from the last line of output. So on failure
   paths, `echo` a human-readable message before `exit 1` — don't let it exit
   silently or dump a raw stack trace as the "error".

7. **Sanity-check before handing back:**
   - `schemaVersion`, `title`, and `mode` are all present (the three required fields).
   - `inline` mode has a `refreshTime` set.
   - Any `dropdown` argument has a `data` array of `{"title", "value"}` objects.
   - The file is executable (`ls -l` should show `x` bits) and has no syntax errors
     (for bash, run it through `bash -n` at minimum; shellcheck if available).
   - If this is bash, prefer running it through `shellcheck` if installed — Raycast's
     own contribution guidelines require this for a reason: shells are unforgiving
     about quoting and word-splitting, and a script that works when you type it by
     hand can break when Raycast invokes it non-interactively.

8. **Tell the user** what to do next in Raycast: reopen Raycast and search for the
   `title` they gave the command (no reload/restart needed since the folder is
   already watched), or if this is the very first script ever added, remind them to
   add `/Users/ruzzelwidjaja/scripts` as a Script Directory first (Raycast →
   Settings → Extensions → Script Commands → Add Script Directory).

## Reference

Full metadata field table, exact argument-type JSON syntax, output-mode details,
ANSI color codes for `inline`/`fullOutput`, and error-handling notes are in
`references/metadata-reference.md`. Read it before writing anything beyond the
simplest no-argument `compact`/`silent` script — the argument and mode semantics
are easy to get subtly wrong from memory.

Ready-to-copy per-language templates (bash, python, node, applescript, ruby, swift,
php) are in `templates/`.
