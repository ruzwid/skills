---
name: create-bounce-pr
description: "End-to-end PR creation for Bounce Insights repositories — commits, pushes, and opens PRs with review-tool-formatted descriptions. Use this skill whenever the user asks to create, open, or ship a PR for a Bounce repo, commit and create a PR for a BOUN ticket, generate a PR description, fill in the PR template, prepare the PR, write the PR body, or mentions review-tool formatting. Also triggers on description-only requests (e.g. 'give me the PR description for BOUN-XXXX'). Trigger proactively when the user has finished work on a BOUN branch and hasn't opened the PR yet."
---

# Create Bounce PR

Take a Bounce ticket from *"work is done on the branch"* to *"PRs are open and ready for review"*. The skill infers what changed, commits with approval, pushes, and opens PRs whose bodies are fast to review and parse cleanly in `review-tool.sh`. It can also stop at just the markdown description if that's all the user wants.

**Critical format rule:** Every value the review-tool reads must stay wrapped in square brackets — `[Yes]`, `[dashboard]`, `[BOUN-1234]`, `[npm run start]`, `[y]` — and may only contain letters, digits, spaces, and `-`. Breaking this silently breaks the tool.

## Reference files

- `references/review-tool-format.md` — the body template, which repos to list, entry format, service reference (commands + URLs), install and branch logic. Read before Step 2.
- `references/writing-the-body.md` — how to write Context, the visual summary, Evidence, Merge Danger, and Functionality Review. Read before Step 4.

## Expected setup (before this skill runs)

1. **Jira ticket already exists.** This skill does **not** create tickets.
2. **Branch already checked out** in each repo the user plans to touch:
   ```bash
   cd ~/bounce/<repo>
   git checkout master && git pull
   git checkout -b BOUN-XXXX
   ```
3. **Code changes exist on the branch** — from this conversation, a previous session, by hand, or a mix. Step 1 figures out what changed regardless of who wrote it.

## Invocation

```
/create-bounce-pr BOUN-2004
/create-bounce-pr BOUN-2004 different-branch
```

- **First argument** — the ticket/branch code, used as the branch name for all repos with changes. **Do not prompt for this.** If it's missing, ask once.
- **Second argument** (optional) — emulator-data branch override.

## Step 1: Gather information about the changes

Figure out **which repos changed** and **what was done**. Use session context when it's sufficient; fall back to git inspection when it isn't. Don't do both — pick the cheaper reliable source.

**Use session context** if the conversation already contains the implementation work (files edited, the change discussed, code produced in this thread).

**Fall back to git** if any of these are true:

- This is a new conversation and the work was done earlier
- The user says "I wrote the code myself" / "the changes are already there"
- Session context only mentions the ticket without the actual edits
- The user asks you to double-check what's on the branch

Do **not** re-run git inspection once you've reliably determined the changed repos — cache the result for the rest of the flow. If the user just tells you which repos are in scope, accept that and skip scanning.

**How to inspect:**

1. Candidate repos = Bounce repos in the service reference plus any repos the user mentions.
2. For each candidate:
   ```bash
   git -C ~/bounce/<repo> rev-parse --verify BOUN-XXXX 2>/dev/null \
     && git -C ~/bounce/<repo> diff --name-only master...BOUN-XXXX
   ```
   Non-empty output → that repo has changes on this ticket.
3. For context on *what* changed: `git -C ~/bounce/<repo> log master..BOUN-XXXX --oneline` and `git -C ~/bounce/<repo> diff master...BOUN-XXXX --stat`. Read full diffs only for repos you need to describe — and read enough to draw the visual summary (call paths, components, data flow).

**Also look for evidence** while you're here: test runs, typecheck output, or console output from this session that shows the change working. Note it for the Evidence section; don't run new commands just to manufacture it. For visual changes, check for user screenshots per **Screenshots** in `references/writing-the-body.md`.

**Emulator-data branch** — infer in this order, **never prompt the user**:

1. Second argument, if provided
2. User's natural language (e.g. *"BOUN-10306 for both"*)
3. Default: same as the ticket code
4. Last resort: `git -C ~/bounce/emulator-data branch --show-current` — use `master` if it returns `master`/`main`, otherwise whatever it reports

**Outcome:** the set of repos with changes, a short summary of what was built in each and why, and any evidence available.

## Step 2: Determine which repos to include

Follow **Which repos go in Repositories to Review** in `references/review-tool-format.md`: emulator-data, changed repos, direct runtime dependencies on master, and anything pulled in by the flow audit after Step 4.

## Step 3: Identify the primary repo

The primary repo gets the full description. Other repos with changes get only a link to the main PR.

Pick the repo with the most significant changes. If only one changed, that's it. If it's close, prefer the frontend or user-facing service.

## Step 4: Generate the description (primary repo only)

Generate **one** description using the template in `references/review-tool-format.md`, written per `references/writing-the-body.md`:

1. `## Changes` — Context, then What changed (visual summary + bullets)
2. `## Evidence` — before/after from Step 1; omit if there's nothing concrete
3. `## Merge Danger` — door + blast radius
4. `## Testing` — Impact on Repositories + Repositories to Review
5. `## Functionality Review` — numbered steps, then run the flow audit and update Repositories to Review

## Step 5: Commit, push, and open the PRs

**Verify branch → commit (with approval) → push → `gh pr create`.** Skip this step entirely if the user only wants the markdown — no `gh`, no `jira` needed.

### Prerequisites

- **`gh` CLI** — must be authenticated (`gh auth status`). Attaching screenshots needs `gh` 2.99+ (`--attach`); if it's older, suggest `brew upgrade gh` or fall back to the drag-in placeholder.
- **`jira` CLI** — only needed when the user hasn't given a PR title. If they have, use it and skip Jira entirely.

**Fetch the ticket summary** (only if the user didn't give a PR title):

1. `jira issue view BOUN-XXXX --plain` (preferred)
2. If that fails but `JIRA_EMAIL` and `JIRA_API_TOKEN` are set:
   ```bash
   curl -s -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
     "https://bounceinsights.atlassian.net/rest/api/3/issue/BOUN-XXXX?fields=summary" \
     | jq -r '.fields.summary'
   ```
3. Otherwise ask the user for the summary (or switch to description-only)

### PR title and commit message format

Same string for the PR title and the first commit:

```
[BOUN-2322] - <PR title from the user, or the Jira ticket summary>
```

The ticket code must match the branch / first invocation argument. If the user's title already has the `[BOUN-XXXX] - ` prefix, don't add it twice.

### Per-repo flow

Run **in order** for every repo with changes. Stop at the first failure and report it.

**1. Verify branch**

```bash
git -C ~/bounce/<repo> branch --show-current
```

Must equal the ticket code. If not, **stop** and report *current* vs *expected* — do not commit, push, or open a PR.

**2. Commit (with approval)**

```bash
git -C ~/bounce/<repo> status --short
```

If clean, skip to 3. Otherwise:

- Show the uncommitted files, split into **(a)** files you can account for (edited this session or matching the ticket scope from Step 1) and **(b)** files that look unrelated.
- Ask before committing either group — **never commit without approval**. Call out group (b): *"These files don't look related to BOUN-XXXX — do you want to include them?"*
- First commit message = PR title. Later commits: same prefix with a short descriptor, e.g. `[BOUN-XXXX] - address review comments`.

**3. Push**

```bash
git -C ~/bounce/<repo> push -u origin BOUN-XXXX
```

Push explicitly so auth, rejected-commit, and hook failures surface before the PR is built.

### Create PRs

When the ticket spans several repos, every PR starts with a **Related PRs** block linking the other PRs in the group. Secondaries are created first so the main PR can be created with its complete block and never needs editing — re-editing it after `--attach` would mean re-sending local image paths.

1. **Secondary PRs** — create each with a temporary body and capture its URL:
   ```bash
   cd ~/bounce/<other-repo> && gh pr create \
     --base master \
     --title "[BOUN-XXXX] - <title>" \
     --body "Main PR to follow."
   ```

2. **Main PR** — put the Related PRs block (all secondary URLs) at the top of the description in `/tmp/bounce-pr/body.md` (`--body-file` preserves the markdown exactly), then:
   ```bash
   cd ~/bounce/<primary-repo> && gh pr create \
     --base master \
     --title "[BOUN-XXXX] - <title>" \
     --body-file /tmp/bounce-pr/body.md \
     --attach /tmp/bounce-pr/before.png \
     --attach /tmp/bounce-pr/after.png
   ```
   Pass one `--attach` per screenshot referenced in the body, using the same absolute path; drop the flags when there are none. Capture the returned PR URL. If the body has a screenshot placeholder, remind the user to drag images in on GitHub.

3. **Back-fill the secondaries** — now that every URL is known, replace each secondary's body with its Related PRs block (the main PR plus the other secondaries):
   ```bash
   gh pr edit <secondary-pr-url> --body-file /tmp/bounce-pr/related-<repo>.md
   ```

**Related PRs block** — list the *other* PRs only, main first and marked. Bare URLs render as `bounceinsights/<repo>#<n>` links on GitHub:

```markdown
**Related PRs**
- https://github.com/bounceinsights/dashboard-api/pull/1234 (main — full description and review steps)
- https://github.com/bounceinsights/web-surveys/pull/567
```

On the main PR, drop the `(main …)` line and list the secondaries. Single-repo tickets get no block.

4. **Show all PR links:**
   ```
   PRs created:
   - dashboard-api (main): https://github.com/org/dashboard-api/pull/1234
   - web-surveys: https://github.com/org/web-surveys/pull/567
   ```
