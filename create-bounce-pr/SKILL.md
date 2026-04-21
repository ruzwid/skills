---
name: create-bounce-pr
description: "End-to-end PR creation for Bounce Insights repositories — commits, pushes, and opens PRs with review-tool-formatted descriptions. Use this skill whenever the user asks to create, open, or ship a PR for a Bounce repo, commit and create a PR for a BOUN ticket, generate a PR description, fill in the PR template, prepare the PR, write the PR body, or mentions review-tool formatting. Also triggers on description-only requests (e.g. 'give me the PR description for BOUN-XXXX'). Trigger proactively when the user has finished work on a BOUN branch and hasn't opened the PR yet."
---

# Create Bounce PR

Take a Bounce ticket from *"work is done on the branch"* to *"PRs are open and ready for review"*. The skill infers what changed, commits with approval, pushes, and opens PRs whose bodies parse cleanly in `review-tool.sh`. It can also stop at just the markdown description if that's all the user wants.

The review-tool uses regex to extract repo names, branches, commands, and install flags from the PR body — so the format must be exact.

**Critical format rule:** Every value the review-tool reads must stay wrapped in square brackets — `[Yes]`, `[dashboard]`, `[BOUN-1234]`, `[npm run start]`, `[y]`. Breaking this breaks the tool.

## Expected setup (before this skill runs)

This skill assumes the normal Bounce workflow:

1. **Jira ticket already exists.** The user (or their manager/colleague) created it beforehand — either in the Atlassian UI or via `jira issue create -tTask -s"<summary>"`. This skill does **not** create tickets.
2. **Branch already checked out.** The user has already done, in each repo they plan to touch:
   ```bash
   cd ~/bounce/<repo>
   git checkout master && git pull
   git checkout -b BOUN-XXXX
   ```
3. **Code changes exist on the branch.** They may come from any source: this conversation, a previous agent session, the user writing code by hand, or a mix. The skill figures out what changed in Step 1 — it doesn't care who wrote it.

Only after all three is the user ready to say *"commit and create the PRs for BOUN-XXXX"*.

## Invocation

The user provides the ticket code and optionally an emulator-data branch override:

```
/create-bounce-pr BOUN-2004
/create-bounce-pr BOUN-2004 different-branch
```

- **First argument** — the ticket/branch code, used as the branch name for all repos with changes. **Do not prompt for this** — it comes from the invocation. If it's missing, ask once.
- **Second argument** (optional) — emulator-data branch override

Emulator-data branch inference is handled in Step 1. Do NOT prompt the user for it.

## Step 1: Gather information about the changes

Figure out **which repos changed** and **what was done**. Use session context when it's sufficient; fall back to git inspection when it isn't. Don't do both — pick the cheaper reliable source.

### When to rely on session context

If the current conversation already contains the implementation work (files edited, discussions about the change, code produced in this thread), use it directly:

- Which repos did the user edit files in during this session?
- Which repos were discussed as having changes?
- What feature/fix was built and why?

### When to fall back to git inspection

Trigger a git fallback if **any** of these are true:

- This is a new conversation and the work was done earlier (previous agent session, another tool, or by hand)
- The user explicitly says "I wrote the code myself" / "the changes are already there"
- Session context is thin or only mentions the ticket without the actual edits
- The user asks you to double-check what's on the branch

Do **not** re-run git inspection if you already reliably determined the changed repos in this conversation — cache the result for the rest of the flow.

**How to inspect:**

1. Candidate repos = union of Bounce repos listed in the dependency tables below and any repos explicitly mentioned by the user.
2. For each candidate, check whether the ticket branch exists and differs from master:
   ```bash
   git -C ~/bounce/<repo> rev-parse --verify BOUN-XXXX 2>/dev/null \
     && git -C ~/bounce/<repo> diff --name-only master...BOUN-XXXX
   ```
   Non-empty output → that repo has changes on this ticket.
3. For human-readable context on *what* changed, use `git -C ~/bounce/<repo> log master..BOUN-XXXX --oneline` and `git -C ~/bounce/<repo> diff master...BOUN-XXXX --stat`. Read full diffs only for repos you actually need to describe.

If the user can just tell you which repos are in scope, accept that and skip scanning — it's faster and accurate.

### Outcome

By the end of Step 1 you must know:

- The set of repos with changes on this ticket (everything else is on `master`)
- A short summary of what was built in each and why (for the Context and What changed sections)

### Emulator-data branch

Infer in this priority order — **never prompt the user**:

1. Second argument, if the user provided one explicitly
2. User's natural language (e.g., *"BOUN-10306 for both"* → use that for both)
3. Default: same branch as the first argument (the ticket code)
4. **Last resort only** — if still ambiguous, run `git -C ~/bounce/emulator-data branch --show-current`. Use `master` if it returns `master`/`main`; otherwise use whatever branch it reports.

## Step 2: Determine which repos to include

Only include repos that are actually needed. Do NOT pad the description with extra repos.

### Always include:
- **emulator-data** — the review-tool always processes this

### Include if they have changes on the ticket branch:
- **Library repos**: ts-types, api-core, dashboard-core
- **Service repos**: dashboard, dashboard-api, api, web-surveys, admin-api, admin-v2, ai-server, cron-api, firestore-functions, retrieval-engine, retrieval-engine-v2, app

### Supporting services (on master)

A repo belongs in Repositories to Review if **any** of these are true:

1. It has code changes on the ticket branch
2. A changed repo directly depends on it at runtime (see dependency table below)
3. Its UI or URL appears in the Functionality Review steps (see flow audit below)

When included only for reasons 2 or 3, use branch `[master]` and install `[n]`.

**Direct runtime dependencies:**

| If this repo changed... | Also include on master |
|------------------------|----------------------|
| dashboard | dashboard-api |
| web-surveys | api |
| admin-v2 | admin-api |
| app | api |
| retrieval-engine-v2 | dashboard, dashboard-api |
| dashboard-api / api / admin-api | — (none by default; rely on flow audit) |

Do not chain further. If `dashboard` changed, include `dashboard-api` but **not** `api` — unless the feature actually needs `api` or the flow audit pulls it in.

**Flow audit — always run after drafting the Functionality Review steps.** Re-read the steps and ask: *which services does the reviewer need running to complete them?* Any service whose URL must be visited or whose UI must be used goes in Repositories to Review, even with zero code changes.

| If the review steps involve... | Also include on master |
|-------------------------------|----------------------|
| Viewing, taking, or inspecting a survey | web-surveys, api |
| Creating or editing surveys via the dashboard UI | dashboard, dashboard-api |
| Any admin action | admin-v2, admin-api |
| An end-to-end flow that spans creation → viewing | dashboard, dashboard-api, web-surveys, api |

**Example:** If only `dashboard-api` changed but the review steps say *"open a generated survey and inspect the questions"*, the reviewer needs `dashboard` (to trigger creation) and `web-surveys` + `api` (to view the result) — all three appear in Repositories to Review on master.

### Do NOT automatically include:
- **firestore-functions** — only include if the user actually changed it or it's on a non-master branch
- **api** — only include if the user changed it or a changed repo directly needs it
- Any other repo not touched on the ticket branch

## Step 3: Generate the description

Reminder: every value that review-tool reads stays in `[brackets]` (see top of file) — `[Yes]`/`[No]`, repo names, branches, commands, `[y]`/`[n]`.

### Markdown heading levels
Use `##` for top-level sections (`## Changes`, `## Testing`, `## Functionality Review`) and `###` for sub-sections (`### Context`, `### What changed`). Sub-sections within Testing (like **Impact on Repositories** and **Repositories to Review**) use bold text, not headings.

### Output template

````markdown
## Changes

### Context

[Short paragraphs covering the relevant beats — Situation, Problem, Fix. See guidance below.]

### What changed

- [Concise bullets describing what was done — each bullet starts with a verb]
- [Wrap code identifiers in backticks: `functionName`, `repoName`, `CONSTANT_NAME`]
- [Group by repo if touching multiple repos, using sub-bullets]
- [If a code example helps illustrate the approach, include it in a fenced code block between the context and the bullet list]

## Testing

**Impact on Repositories**

<!--- If there are changes on ts-types then mark Yes. Otherwise, mark No.  -->
Is there any changes on ts-types repository? [No]

<!--- If there are changes on api-core then mark Yes. Otherwise, mark No.  -->
Is there any changes on api-core repository? [No]

<!--- If there are changes on dashboard-core then mark Yes. Otherwise, mark No.  -->
Is there any changes on dashboard-core repository? [No]


**Repositories to Review**

[REPO ENTRIES — see format rules below. Keep `dashboard` last if included.]

## Functionality Review
<!--- Describe below step by step, how reviewer should test the functionality once all the process have started. -->

[REVIEW STEPS — see guidance below]
````

Replace `[No]` with `[Yes]` in the Impact section for any library repo that has actual changes.

### Writing the `### Context` section

Give reviewers the picture so they understand the PR before reading code. Cover whichever of these beats actually apply — don't manufacture filler:

- **Situation** — what existed before, how it worked
- **Problem** — what broke or was missing, and why it mattered
- **Fix** — what this PR does about it, in one sentence

A small refactor may only need Situation + Fix. A bug fix usually needs all three. If a code example helps (e.g. showing what a generated data structure looks like), place it between the paragraphs and the bullet list inside a fenced code block with the right language tag.

**Bad:**

> Fixed formatting bug in surveys

**Good:**

> PR #1833 fixed "Placeholder" text rendering in WPP surveys by clearing `columnChoicesFormatting` and `rowItemsFormatting` to empty arrays in `shiftAndInsertQuestions`. This worked but had a side effect — it stripped all rich text formatting (bold/italic/underline) from matrix questions, breaking the formatting support added in #500.
>
> The proper fix for the Placeholder mismatch is handled in the companion PR (BOUN-10345), which regenerates formatting at runtime when rules overwrite options.

### Writing the `### What changed` bullets

**Pick a format first:**

- **Table** — when 3+ fields, options, or behaviors change in the same structured way
- **Bullets** — everything else

**Bullet rules:**

- Start each bullet with a verb: "Update", "Add", "Remove", "Refactor", "Revert"
- Wrap code identifiers in backticks: function names, variable names, file names, constants
- One clear action per bullet
- Single repo → plain bullets, no prefix. Multiple repos → group by repo name with sub-bullets indented 3 spaces.

**Bad:**

```
- Fixed some stuff
- Made changes to the survey page
- Updated things
```

**Good — single repo:**

```
- Update `shiftAndInsertQuestions` to preserve formatting arrays
- Remove dead `clearFormatting` code path
- Add unit test for matrix question formatting
```

**Good — multiple repos:**

```
- **web-surveys**:
   - Update `shiftAndInsertQuestions` to preserve formatting arrays
   - Remove dead `clearFormatting` code path
- **api**:
   - Add `generateFormatting()` helper to runtime rule execution
```

**Good — table for structured comparisons:**

```markdown
| Field | Before | After |
|-------|--------|-------|
| `columnChoicesFormatting` | Preserved on shift | Cleared to `[]` |
| `rowItemsFormatting` | Preserved on shift | Cleared to `[]` |
```

```markdown
| Where options change | Formatting updated? |
|---|---|
| mainWpp creates questions | No formatting created at all |
| exportSurveyToEditor normalizes | Yes — generates from current values |
| pipeFamiliarBrandsRule (runtime) | NO — only updates rowItems |
```

## Repo entry format rules

### Ordering
1. **emulator-data** — first
2. **Library repos** with changes — ts-types, api-core, dashboard-core
3. **Backend services** — firestore-functions, api, dashboard-api, admin-api, ai-server, cron-api
4. **Frontend services** — web-surveys, admin-v2
5. **dashboard** — always last if included

### Format by repo type

**emulator-data** (no command/install fields):
```
  - **Repository to Pull From:** [emulator-data]
  - **Branch to Pull:** [<branch>]
```

**Library repos** — ts-types, api-core, dashboard-core:
```
  - **Repository to Pull From:** [ts-types]
  - **Branch to Pull:** [BOUN-XXXX]
  - **Install (y or n):** [y]
```

**Service repos** (all 4 fields required):
```
  - **Repository to Pull From:** [<repo-name>]
  - **Branch to Pull:** [<branch>]
  - **Command to run:** [<command>]
  - **Install (y or n):** [<y or n>]
```

### Service reference

Command goes in the repo entry's `[Command to run:]` field. URL is where the service is reachable once review-tool starts it — use it in the Functionality Review steps.

| Repo | Command | URL |
|------|---------|-----|
| dashboard | `npm run start` | http://localhost:3002 |
| web-surveys | `npm run start` | http://localhost:3003 |
| admin-v2 | `npm run start` | http://localhost:3004 |
| dashboard-api | `npm run start-dev` | http://localhost:1440 |
| api | `npm run start-dev` | http://localhost:1441 |
| admin-api | `npm run start-dev` | http://localhost:1442 |
| ai-server | `npm run start-dev` | — |
| cron-api | `npm run start-dev` | — |
| firestore-functions | `npm run fb-run-review` | http://localhost:4001 |
| retrieval-engine | `python3 run.py` | http://localhost:1444 |
| retrieval-engine-v2 | `sh ./scripts/dev_local_startup.sh` | — |
| app | `npm run app-setup-review` | — |

### Install flag logic

The install flag tells the review-tool whether to run `npm install`. The decision comes from **Impact on Repositories**:

| Repo has changes? | Any library (ts-types / api-core / dashboard-core) marked `[Yes]`? | Install |
|---|---|---|
| Yes | — | `[y]` |
| No (on master) | Yes | `[y]` |
| No (on master) | No | `[n]` |

A library marked `[Yes]` means downstream repos need a fresh install to pick up the updated dependency, even when their own branch is `master`.

### Branch logic
- Repos with changes: use the ticket code provided by the user (e.g., `BOUN-2004`)
- Supporting service repos on master: use `[master]`
- emulator-data: use the user-provided branch or the detected branch

## Functionality Review guidance

Write specific, numbered steps based on what was actually built. Do not write generic steps. URLs come from the **Service reference** table above.

### Template structure

```
1. Run `review-tool <primary-repo> <PR_NUMBER>` to set up all services.
2. [Navigation step — where to go first]
3. [Action step — what to do]
4. [Verification step — what to confirm/expect]
```

`<primary-repo>` is the repo the PR is being opened in.

### Step types

Each step should be one of:

- **Setup** — run a command or open a URL
- **Action** — click, fill in, submit
- **Verification** — "Confirm that…", "Verify that…", "Check that…" — always end with the expected result

### URL formatting

When a step mentions a local service, write it as a markdown link with the service name as the label. GitHub renders it as a clickable shortcut, so reviewers don't have to memorize ports.

- **Good** — `Open [dashboard](http://localhost:3002) and go to **My Surveys**.`
- **Acceptable** — `Open http://localhost:3002 (dashboard) and go to My Surveys.`
- **Bad** — `Open localhost and go to My Surveys.`

### Bad vs Good

**Bad:**

> Test the feature.

**Good:**

> 1. Run `review-tool dashboard 1234` to spin up all services.
> 2. Open [dashboard](http://localhost:3002) and go to **My Surveys**.
> 3. Click the refresh button and confirm it reads "Refresh this dashboard".
> 4. Verify the list refreshes after clicking.
> 5. Go to Trackers and confirm that button still reads "Refresh".

## Step 4: Commit, push, and open the PRs

After the description is ready, walk through: **verify branch → commit (with approval) → push → `gh pr create`**. Using `gh pr create --body-file` preserves the review-tool markdown exactly; copy-paste from the terminal would mangle it.

Skip Step 4 entirely if the user only wants the PR description markdown — no `gh`, no `jira` needed.

### Prerequisites

- **`gh` CLI** — required for creating PRs, must be authenticated (`gh auth status`)
- **`jira` CLI** — used only to fetch the ticket summary (for the PR title and the first commit message). Before running `gh pr create`, verify it works: `command -v jira` and `jira issue view BOUN-XXXX --plain`. If it fails, offer the user three options: install/fix the CLI, paste the ticket summary manually, or switch to description-only.
- **If the user only asked for the description** — do not require `jira` or `gh`; just output the markdown.

**Fetch the ticket summary** (when creating PRs and the user did not supply one):

1. Jira CLI: `jira issue view BOUN-XXXX --plain` (preferred)
2. If that fails but `JIRA_EMAIL` and `JIRA_API_TOKEN` are set, curl + Jira REST API:
   ```bash
   curl -s -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
     "https://bounceinsights.atlassian.net/rest/api/3/issue/BOUN-XXXX?fields=summary" \
     | jq -r '.fields.summary'
   ```
3. If neither works, ask the user for the summary text (or switch to description-only)

### PR title and commit message format

Use the same string for the GitHub PR title and for any commits you make after the user approves:

```
[BOUN-2322] - <Jira ticket summary>
```

Example: `[BOUN-2322] - Fix matrix question formatting on shift`

The ticket code in brackets must match the branch / first invocation argument.

### Determine the primary repo

The primary repo is where the main PR is created — typically the repo with the most significant changes on this ticket. If only one repo has changes, that's the primary.

### Per-repo flow

Run these **in order** for every repo with changes. Stop at the first failure and report it — do not skip ahead.

**1. Verify branch**

```bash
git -C ~/bounce/<repo> branch --show-current
```

Must equal the ticket code (the first invocation argument, e.g. `BOUN-2322`). If it doesn't match, **stop** and report *current* vs *expected*. Do not commit, push, or open a PR — the user needs to `git checkout` the right branch or correct the ticket argument first.

**2. Commit (with approval)**

```bash
git -C ~/bounce/<repo> status --short
```

If the tree is clean, skip to step 3. Otherwise:

- Show the uncommitted files to the user.
- Split them into **(a)** files you can account for (either edited in this session, or matching the scope of the ticket based on Step 1) and **(b)** files that look unrelated.
- Ask explicitly before committing either group — **never commit without approval**.
- For group (b), call them out: *"These files don't look related to BOUN-XXXX — do you want to include them?"*
- **First commit message = PR title:** `[BOUN-XXXX] - <Jira ticket summary>`
- Any additional commits on the same branch use the same prefix with a short descriptor, e.g. `[BOUN-XXXX] - address review comments`.

**3. Push**

```bash
git -C ~/bounce/<repo> push -u origin BOUN-XXXX
```

`gh pr create` (step 4) will auto-push if you skip this, but do it explicitly so push failures (auth, rejected commits, hooks) surface before the PR form is built.

**4. Create the PR** — see the next section.

### Create PRs

1. **Main PR** — primary repo, full review-tool description:
   ```bash
   cd ~/bounce/<primary-repo> && gh pr create \
     --base master \
     --title "[BOUN-XXXX] - <Jira ticket summary>" \
     --body-file /tmp/bounce-pr-body.md
   ```
   Write the full description from Step 3 to `/tmp/bounce-pr-body.md` first. Capture the returned PR URL.

2. **Secondary PRs** — other repos with changes, body links to the main PR:
   ```bash
   cd ~/bounce/<other-repo> && gh pr create \
     --base master \
     --title "[BOUN-XXXX] - <Jira ticket summary>" \
     --body "Main PR: <main-pr-url>"
   ```

3. **Show all PR links** when done:
   ```
   PRs created:
   - dashboard-api (main): https://github.com/org/dashboard-api/pull/1234
   - web-surveys: https://github.com/org/web-surveys/pull/567
   ```