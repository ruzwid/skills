---
name: bounce-pr-description
description: "Generate PR descriptions for Bounce Insights repositories, formatted for the review-tool. Use this skill whenever the user asks to create, generate, or write a PR description, pull request description, or review-tool description for any Bounce repo. Also trigger when the user says things like 'write the PR body', 'fill in the PR template', 'prepare the PR', 'generate the repos to review section', or mentions review-tool formatting. Trigger proactively when the user is about to open a PR and hasn't written a description yet."
---

# Bounce PR Description Generator

Generate structured PR descriptions that the `review-tool.sh` can parse. The review-tool uses regex to extract repo names, branches, commands, and install flags from the PR body — so the format must be exact.

## Invocation

The user provides a ticket code and optionally an emulator-data branch override:

```
/bounce-pr-description BOUN-2004
/bounce-pr-description BOUN-2004 different-branch
```

- First argument: the ticket/branch code — used as the branch name for all repos that have changes
- Second argument (optional): emulator-data branch override. If not provided, assume emulator-data is on the same branch as the ticket code. Only run a git check if the user explicitly asks or it's ambiguous from context.

**Important**: Do NOT prompt the user for the emulator-data branch. Instead, infer it intelligently:
1. If the user says "BOUN-10306 for both", use BOUN-10306 for both
2. If the user provides a second argument explicitly, use that
3. Otherwise, assume emulator-data is on the same branch as the first argument

## Step 1: Gather information from the session

Do NOT scan all repos with git. Instead, determine everything from the current conversation context.

### Which repos were changed?
Look at the conversation history for this session:
- Which repos did the user edit files in?
- Which repos were discussed as having changes?
- What code was modified?

Only these repos have changes. Everything else is on `master`.

### What was built and why?
From the session context, understand:
- What feature/fix was implemented
- Why it was needed (the ticket context)
- What specifically changed in each repo

### Emulator-data branch
- If the user provided a second argument explicitly, use that as the emulator-data branch
- If the user's natural language indicates both repos are on the same branch (e.g., "BOUN-10306 for both"), use the first argument
- Otherwise, assume the emulator-data branch is the same as the ticket code from the first argument
- **As a last resort only**: if the branch is ambiguous and not specified by the user, run: `git -C ~/bounce/emulator-data branch --show-current` to detect the current branch. If it returns `master` or `main`, use `master`. Otherwise use whatever branch it's on.
- **Do NOT prompt** the user — infer from context or fall back to the git check silently

## Step 2: Determine which repos to include

Only include repos that are actually needed. Do NOT pad the description with extra repos.

### Always include:
- **emulator-data** — the review-tool always processes this

### Include if they have changes in this session:
- **Library repos**: ts-types, api-core, dashboard-core
- **Service repos**: dashboard, dashboard-api, api, web-surveys, admin-api, admin-v2, ai-server, cron-api, firestore-functions, retrieval-engine, retrieval-engine-v2, app

### Include as a supporting service (on master) ONLY if the changed repo directly depends on it:
| If this repo changed... | Also include on master |
|------------------------|----------------------|
| dashboard | dashboard-api |
| web-surveys | api |
| admin-v2 | admin-api |
| app | api |
| retrieval-engine-v2 | dashboard, dashboard-api |
| dashboard-api | (nothing extra by default — see flow audit below) |
| api | (nothing extra by default — see flow audit below) |
| admin-api | (nothing extra by default — see flow audit below) |

Only add the direct backend companion (unless specified otherwise) — do not chain further (e.g., if dashboard changed, add dashboard-api but NOT api unless the user also changed api or dashboard-api depends on it for this specific feature).

### Flow audit — ALWAYS do this after drafting the Functionality Review steps

After writing the review steps, re-read them and ask: **which services does the reviewer need running to actually complete these steps?**

Cross-reference against the port table. Any service whose URL must be visited or whose UI must be used should be in Repositories to Review — even if it has zero code changes. Add it on `master` with install `[n]`.

**Common full-stack patterns to catch:**
| If the review steps involve... | Also include on master |
|-------------------------------|----------------------|
| Viewing, taking, or inspecting a survey | web-surveys, api |
| Creating or editing surveys via the dashboard UI | dashboard, dashboard-api |
| Any admin action | admin-v2, admin-api |
| An end-to-end flow that spans creation → viewing | dashboard, dashboard-api, web-surveys, api |

**Example:** If only `dashboard-api` changed but the review steps say "open a generated survey and inspect the questions", the reviewer needs `dashboard` (to trigger creation) and `web-surveys` + `api` (to view the result) — all three must appear in Repositories to Review on master.

This audit overrides the "nothing extra" defaults in the table above.

### Do NOT automatically include:
- **firestore-functions** — only include if the user actually changed it or it's on a non-master branch
- **api** — only include if the user changed it or a changed repo directly needs it
- Any other repo not touched in the session

## Step 3: Generate the description

### Brackets are critical
Every value must be in square brackets `[like this]`. The review-tool regex extracts text from inside brackets. This applies to:
- Impact answers: `[Yes]` or `[No]`
- Repo names: `[dashboard]`
- Branch names: `[BOUN-1234]`
- Commands: `[npm run start]`
- Install flags: `[y]` or `[n]`

### Markdown heading levels
Use `##` for top-level sections (`## Changes`, `## Testing`, `## Functionality Review`) and `###` for sub-sections (`### Context`, `### What changed`). Sub-sections within Testing (like **Impact on Repositories** and **Repositories to Review**) use bold text, not headings.

### Output template

````markdown
## Changes

### Context

[2-3 short paragraphs explaining:
1. **The situation** — what existed before, how things worked
2. **The problem** — what broke, what was wrong, what was missing
3. **The fix** — what this PR does to solve it]

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
<!--- Duplicate the template below for each repository affected by your changes -->
<!---  Copy and paste the below template for all repo which you want to review
If you have changes for dashboard, ensure that you keep the data for dashboard to the very last -->

[REPO ENTRIES — see format rules below]

## Functionality Review
<!--- Describe below step by step, how reviewer should test the functionality once all the process have started. -->

[REVIEW STEPS — see guidance below]
````

Replace `[No]` with `[Yes]` in the Impact section for any library repo that has actual changes.

### Writing the `### Context` section

The Context section gives reviewers the full picture so they understand the PR without reading the code first. Structure it as 2-3 short paragraphs:

**Paragraph 1 — The situation:** What existed before? How did the system work? Set the scene.
**Paragraph 2 — The problem:** What broke or was missing? Why did it matter? What was the user-facing or developer-facing impact?
**Paragraph 3 — The fix:** What does this PR do about it? One sentence on the approach.

If a code example helps explain the approach (e.g., showing what a generated data structure looks like), place it between the Context paragraphs and the bullet list, inside a fenced code block with the appropriate language tag.

**Bad context:** "Fixed formatting bug in surveys"

**Good context:**

> PR #1833 fixed "Placeholder" text rendering in WPP surveys by clearing `columnChoicesFormatting` and `rowItemsFormatting` to empty arrays in `shiftAndInsertQuestions`. This worked but had a side effect — it stripped all rich text formatting (bold/italic/underline) from matrix questions, breaking the formatting support added in #500.
>
> The proper fix for the Placeholder mismatch is handled in the companion PR (BOUN-10345), which regenerates formatting at runtime when rules overwrite options.

### Writing the `### What changed` bullets

- Start each bullet with a verb: "Update", "Add", "Remove", "Refactor", "Revert"
- Wrap all code identifiers in backticks: function names, variable names, file names, constants
- Keep each bullet to one clear action
- If touching multiple repos, group with sub-bullets:
  ```
  - **web-surveys**: Update `shiftAndInsertQuestions` to preserve formatting arrays
  - **api**: Add `generateFormatting()` helper to runtime rule execution
  ```

**When to use a table:** If the change affects multiple fields, options, or behaviors in a structured way, a table is clearer than bullets:

```markdown
| Field | Before | After |
|-------|--------|-------|
| `columnChoicesFormatting` | Preserved on shift | Cleared to `[]` |
| `rowItemsFormatting` | Preserved on shift | Cleared to `[]` |
```

For more complex comparisons, an ASCII box table also works well:

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

### Default commands

| Repo | Command |
|------|---------|
| dashboard | `npm run start` |
| web-surveys | `npm run start` |
| admin-v2 | `npm run start` |
| dashboard-api | `npm run start-dev` |
| api | `npm run start-dev` |
| admin-api | `npm run start-dev` |
| ai-server | `npm run start-dev` |
| cron-api | `npm run start-dev` |
| firestore-functions | `npm run fb-run-review` |
| retrieval-engine | `python3 run.py` |
| retrieval-engine-v2 | `sh ./scripts/dev_local_startup.sh` |
| app | `npm run app-setup-review` |

### Install flag logic

The install flag `[y]` or `[n]` tells the review-tool whether to run `npm install` for a repo. The logic is driven by the **Impact on Repositories** section:

- `[y]` — the repo has actual code changes on the feature branch
- `[y]` — the repo is on `master` BUT one of the impact repos it depends on has changed (ts-types, api-core, or dashboard-core are marked `[Yes]`). This is because a library change means the repo needs a fresh `npm install` to pick up the updated dependency.
- `[n]` — the repo is on `master` as a supporting service AND none of its library dependencies (ts-types/api-core/dashboard-core) have changed

**In short:** if Impact on Repositories is all `[No]`, then every repo on `master` gets `[n]`. If any impact repo is `[Yes]`, then repos on `master` that depend on that library get `[y]`.

### Branch logic
- Repos with changes: use the ticket code provided by the user (e.g., `BOUN-2004`)
- Supporting service repos on master: use `[master]`
- emulator-data: use the user-provided branch or the detected branch

## Functionality Review guidance

Write specific, numbered steps based on what was actually built. Do not write generic steps.

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
- **Setup**: Running a command or navigating to a URL
- **Action**: Clicking, filling in, submitting
- **Verification**: "Confirm that...", "Verify that...", "Check that..." — always end with the expected result

### Port reference

| Service | URL |
|---------|-----|
| dashboard | http://localhost:3002 |
| web-surveys | http://localhost:3003 |
| admin-v2 | http://localhost:3004 |
| dashboard-api | http://localhost:1440 |
| api | http://localhost:1441 |
| admin-api | http://localhost:1442 |
| firestore-functions | http://localhost:4001 |
| retrieval-engine | http://localhost:1444 |

### Bad vs Good

**Bad:**
> Test the feature.

**Good:**
> 1. Run `review-tool dashboard 1234` to spin up all services.
> 2. Open http://localhost:3002 and go to My Surveys.
> 3. Click the refresh button and confirm it reads "Refresh this dashboard".
> 4. Verify the list refreshes after clicking.
> 5. Go to Trackers and confirm that button still reads "Refresh".