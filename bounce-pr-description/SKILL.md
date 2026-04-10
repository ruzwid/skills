---
name: bounce-pr-description
description: "Generate PR descriptions for Bounce Insights repositories, formatted for the review-tool. Use this skill whenever the user asks to create, generate, or write a PR description, pull request description, or review-tool description for any Bounce repo. Also trigger when the user says things like 'write the PR body', 'fill in the PR template', 'prepare the PR', 'generate the repos to review section', or mentions review-tool formatting. Trigger proactively when the user is about to open a PR and hasn't written a description yet."
---

# Bounce PR Description Generator

Generate structured PR descriptions that the `review-tool.sh` can parse. The review-tool uses regex to extract repo names, branches, commands, and install flags from the PR body — so the format must be exact.

## Invocation

The user provides a ticket code and optionally an emulator-data branch:

```
/pr-description BOUN-2004
/pr-description BOUN-2004 wppSurvey123
```

- First argument: the ticket/branch code — used as the branch name for all repos that have changes
- Second argument (optional): emulator-data branch override. If not provided, run one git check: `git -C ~/bounce/emulator-data branch --show-current` to get the current branch

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
If the user provided a second argument, use that as the emulator-data branch. Otherwise, run this single git command:
```bash
git -C ~/bounce/emulator-data branch --show-current
```
If it returns `master` or `main`, use `master`. Otherwise use whatever branch it's on.

## Step 2: Determine which repos to include

Only include repos that are actually needed. Do NOT pad the description with extra repos.

### Always include:
- **emulator-data** — the review-tool always processes this

### Include if they have changes in this session:
- **Library repos**: ts-types, api-core, dashboard-core
- **Service repos**: dashboard, dashboard-api, api, web-surveys, admin-api, admin-v2, ai-server, cron-api, firestore-functions, retrieval-engine, app

### Include as a supporting service (on master) ONLY if the changed repo directly depends on it:
| If this repo changed... | Also include on master |
|------------------------|----------------------|
| dashboard | dashboard-api |
| web-surveys | api |
| admin-v2 | admin-api |
| app | api |
| dashboard-api | (nothing extra) |
| api | (nothing extra) |
| admin-api | (nothing extra) |

Only add the direct backend companion (unless specified otherwise) — do not chain further (e.g., if dashboard changed, add dashboard-api but NOT api unless the user also changed api or dashboard-api depends on it for this specific feature).

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

### Output template

````markdown
### Changes

<!--- Context: why this was built -->
[1-2 sentences: the ticket, the problem, why this change exists]

<!--- Summary of changes -->
- [Concise bullets describing what changed — group by repo if touching multiple]

### Testing

**Impact on Repositories**

<!--- If there are changes on ts-types changes then mark Yes. Otherwise, mark No.  -->
Is there any changes on ts-types repository? [No]

<!--- If there are changes on api-core changes then mark Yes. Otherwise, mark No.  -->
Is there any changes on api-core repository? [No]

<!--- If there are changes on dashboard-core changes then mark Yes. Otherwise, mark No.  -->
Is there any changes on dashboard-core repository? [No]


**Repositories to Review**
<!--- Duplicate the template below for each repository affected by your changes -->
<!---  Copy and paste the below template for all repo which you want to review
If you have changes for dashboard, ensure that you keep the data for dashboard to the very last -->

[REPO ENTRIES — see format rules below]

### Functionality Review
<!--- Describe below step by step, how reviewer should test the functionality once all the process have started. -->

[REVIEW STEPS — see guidance below]

### Documentation
<!--- Make sure the documentation has been updated if necessary --->
- [ ] - [Documentation for this product](https://bounceinsights.atlassian.net/wiki/spaces/DEVELOPMEN/pages/751108109/READMEs) has been updated (if necessary)


---

### Review Tool

Read more on the review tool and usage [here](https://bounceinsights.atlassian.net/wiki/spaces/DEVELOPMEN/pages/993689601/Bounce+Review+Tool).
````

Replace `[No]` with `[Yes]` in the Impact section for any library repo that has actual changes.

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
| app | `npm run app-setup-review` |

### Install flag
- `[y]` — for repos with changes (on the feature branch), or repos that depend on a changed library (ts-types/api-core/dashboard-core)
- `[n]` — for supporting service repos on master with no dependency changes

### Branch logic
- Repos with changes: use the ticket code provided by the user (e.g., `BOUN-2004`)
- Supporting service repos on master: use `[master]`
- emulator-data: use the user-provided branch or the detected branch

## Functionality Review guidance

Write specific test steps based on what was actually built. Do not write generic steps.

### Start with the review-tool command
```
1. Run `review-tool <primary-repo> <PR_NUMBER>` to spin up all services
2. Wait for services to start
```

`<primary-repo>` is the repo the PR is being opened in.

### Then describe what to test
Reference specific URLs, pages, and expected behavior based on the actual changes from this session.

**Port reference:**
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

### Be specific
Bad: "Test the feature"
Good: "Open http://localhost:3002, go to My Surveys, verify the refresh button now reads 'Refresh this dashboard', click it and confirm the list refreshes. Then go to Trackers and confirm that button still reads 'Refresh'."
