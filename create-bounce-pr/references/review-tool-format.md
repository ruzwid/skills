# Review-tool format

`review-tool.sh` (`~/bounce/bounce-tools/scripts/review-tool.sh`) finds each value with a label-anchored regex — e.g. `**Repository to Pull From:** [x]`, `Is there any changes on ts-types repository? [Yes]`. It ignores headings and section order, so extra sections are safe. Two things are not:

- Every value it reads must stay wrapped in square brackets.
- Bracketed values may only contain letters, digits, spaces, and `-`. Anything else (`.`, `/`, `_`) makes the regex miss and the whole repo entry is **silently skipped**.
- Never quote a `**Repository to Pull From:**` line anywhere else in the body (e.g. inside a diff sketch) — the parser would pick it up as a real entry.

## Output template

````markdown
<Related PRs block — multi-repo tickets only, see Create PRs in SKILL.md>

## Changes

### Context

<see writing-the-body.md>

### What changed

<visual summary + bullets — see writing-the-body.md>

## Evidence

<see writing-the-body.md — omit the whole section if there is nothing concrete>

## Merge Danger

**Door:** <one-way or two-way>

<optional: one sentence on why>

**Blast Radius:** <one-word description>

<optional: potential ramifications of merge>

## Testing

**Impact on Repositories**

<!--- If there are changes on ts-types then mark Yes. Otherwise, mark No.  -->
Is there any changes on ts-types repository? [No]

<!--- If there are changes on api-core then mark Yes. Otherwise, mark No.  -->
Is there any changes on api-core repository? [No]

<!--- If there are changes on dashboard-core then mark Yes. Otherwise, mark No.  -->
Is there any changes on dashboard-core repository? [No]


**Repositories to Review**

<repo entries — see below. Keep `dashboard` last if included.>

## Functionality Review
<!--- Describe below step by step, how reviewer should test the functionality once all the process have started. -->

<review steps — see writing-the-body.md>
````

Use `##` for top-level sections and `###` for sub-sections. **Impact on Repositories** and **Repositories to Review** are bold text, not headings.

Replace `[No]` with `[Yes]` in Impact on Repositories for any library repo with actual changes.

## Which repos go in Repositories to Review

Only include repos that are actually needed. Do NOT pad the list.

A repo belongs if **any** of these are true:

1. It is **emulator-data** — always included
2. It has code changes on the ticket branch
3. A changed repo directly depends on it at runtime (dependency table below)
4. Its UI or URL appears in the Functionality Review steps (flow audit below)

When included only for reasons 3 or 4, use branch `[master]`.

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

**Flow audit — always run after drafting the Functionality Review steps.** Re-read the steps and ask: *which services does the reviewer need running to complete them?* Any service whose URL must be visited or whose UI must be used goes in, even with zero code changes.

| If the review steps involve... | Also include on master |
|-------------------------------|----------------------|
| Viewing, taking, or inspecting a survey | web-surveys, api |
| Creating or editing surveys via the dashboard UI | dashboard, dashboard-api |
| Any admin action | admin-v2, admin-api |
| An end-to-end flow that spans creation → viewing | dashboard, dashboard-api, web-surveys, api |

**Example:** If only `dashboard-api` changed but the review steps say *"open a generated survey and inspect the questions"*, the reviewer needs `dashboard` (to trigger creation) and `web-surveys` + `api` (to view the result) — all three go in on master.

**Do NOT automatically include** `firestore-functions` or `api` unless changed or directly needed.

## Ordering

1. **emulator-data** — first
2. **Library repos** with changes — ts-types, api-core, dashboard-core
3. **Backend services** — firestore-functions, api, dashboard-api, admin-api, ai-server, cron-api, retrieval-engine, retrieval-engine-v2
4. **Frontend services** — web-surveys, admin-v2
5. **dashboard** — always last if included

## Entry format by repo type

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

## Service reference

Command goes in the entry's `Command to run` field. URL is where the service is reachable once review-tool starts it — use it in the Functionality Review steps.

| Repo | Command | URL |
|------|---------|-----|
| dashboard | `[npm run start]` | http://localhost:3002 |
| web-surveys | `[npm run start]` | http://localhost:3003 |
| admin-v2 | `[npm run start]` | http://localhost:3004 |
| dashboard-api | `[npm run start-dev]` | http://localhost:1440 |
| api | `[npm run start-dev]` | http://localhost:1441 |
| admin-api | `[npm run start-dev]` | http://localhost:1442 |
| ai-server | `[npm run start-dev]` | — |
| cron-api | `[npm run start-dev]` | — |
| firestore-functions | `[npm run fb-run-review]` | http://localhost:4001 |
| retrieval-engine | `[]` | http://localhost:1444 |
| retrieval-engine-v2 | `[]` | — |
| app | `[npm run app-setup-review]` | — |

- **retrieval-engine** — leave the command empty; review-tool falls back to `python3 run.py` itself.
- **retrieval-engine-v2** — its start command (`sh ./scripts/dev_local_startup.sh`) can't pass the regex and review-tool has no fallback for it, so it only gets cloned. Use `[]` with install `[n]`, and add a Functionality Review step telling the reviewer to run `sh ./scripts/dev_local_startup.sh` inside the review-tool's `retrieval-engine-v2` checkout.

## Install flag logic

The install flag tells review-tool whether to run `npm install`. It follows from **Impact on Repositories**:

| Repo has changes? | Any library (ts-types / api-core / dashboard-core) marked `[Yes]`? | Install |
|---|---|---|
| Yes | — | `[y]` |
| No (on master) | Yes | `[y]` |
| No (on master) | No | `[n]` |

A library marked `[Yes]` means downstream repos need a fresh install to pick up the updated dependency, even on `master`. Python repos (retrieval-engine, retrieval-engine-v2) always use `[n]`.

## Branch logic

- Repos with changes: the ticket code (e.g. `[BOUN-2004]`)
- Supporting service repos: `[master]`
- emulator-data: the branch inferred in Step 1 of `SKILL.md`
