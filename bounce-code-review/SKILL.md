---
name: bounce-code-review
description: Review open bounceinsights pull requests that request my review or that I authored, from real checkouts, and write a grouped report with verified findings. Run only when explicitly invoked, e.g. by the daily review task.
disable-model-invocation: true
effort: high
argument-hint: "[repo#number ...]  (omit to review the whole queue)"
---

# Bounce Code Review

Review the pull requests waiting on me across the `bounceinsights` org and produce one report. A finding only counts if it was read in a real checkout, anchored to `repo/path:line`, and survived the verification pass. Silence is better than noise: an empty review is a valid outcome.

Arguments: `$ARGUMENTS`. If given (e.g. `dashboard-api#2232 ts-types#682`), review exactly those PRs and ignore the queue and the unchanged-PR shortcut. Otherwise review the queue.

## Setup

```bash
ROOT="${REVIEW_DIR:-$HOME/review}"
STATE="$ROOT/.code-review"
TODAY=$(date +%F)
mkdir -p "$STATE/notes/$TODAY" "$STATE/reports"
find "$ROOT" -mindepth 2 -maxdepth 2 -name .git -type d -exec sh -c 'git -C "${1%/.git}" worktree prune' _ {} \;
rm -rf "$ROOT/.wt"
```

The last two lines clear worktrees left by a crashed run (see **Large queues**).

- `ROOT/<repo>` are disposable review clones. Updating or resetting them is fine. Never touch `~/bounce`, which holds work in progress.
- `STATE/state.json` maps `repo#number` to `{ "head": "<sha>", "reviewed": "<date>", "verdict": "..." }` from earlier runs.
- Write each group's findings to `STATE/notes/$TODAY/<group>.md` as soon as the group is done, so a context compaction never loses work.

## Step 1: Find the PRs

Run `scripts/find-prs.sh`. It prints one JSON object per PR with `repo`, `number`, `title`, `author`, `isDraft`, `url` and `reason` (`requested` or `mine`). `review-requested:@me` already includes requests to teams I'm on.

- **Requested** PRs get a full review. Drafts included, marked `_draft_`.
- **Mine** PRs get the same full review, with the same bar. They are not optional and not lower priority: catching my own bugs before a teammate does is half the point of this run. I can't approve my own PR, so their verdict is only a readiness signal. The only skip is my **drafts** not updated in 14 days; list them in one line under Coverage gaps.
- **Unchanged** groups: if every PR in a group (Step 2) has the same head SHA as in `state.json`, don't re-review it. Copy that group's section verbatim from the most recent report in `STATE/reports/` into today's Unchanged section (format in `references/output.md`). If any PR in the group has new commits, re-review the whole group. If the section can't be found in the latest report, re-review it.

Save the script's output to `STATE/notes/$TODAY/queue.jsonl`. **Every line in it must end up in the report**: in a group table, under Unchanged, or under Coverage gaps with a reason. Step 7 checks this.

## Step 2: Metadata, groups, stacks

One call per PR, only the fields needed:

```bash
gh pr view <n> -R bounceinsights/<repo> \
  --json title,body,author,isDraft,baseRefName,headRefName,headRefOid,url,reviewRequests,latestReviews
```

- **Groups**: PRs sharing a `[BOUN-XXXXX]` title code are one feature, reviewed together across repos. No code means its own group, `<repo>#<n>`. Never drop a PR silently.
- **Intent**: read the body for intent, then put it aside; long bodies are usually testing guides. If `jira issue view BOUN-XXXXX --plain` works, read the ticket summary and description too. It is the spec the diff is checked against.
- **Reviewers**: say who else is asked or has reviewed only from `reviewRequests` and `latestReviews`. Never infer a name from the author, the ticket or the repo.
- **Stacks**: a `baseRefName` that isn't the repo's default branch means stacked. Diff against `baseRefName` so only this PR's changes are reviewed. Resolve the parent with `gh pr list -R bounceinsights/<repo> --head <baseRefName> --state all --json number,state`. If the base ref can't be fetched, mark the PR "not reviewed: base unresolvable"; never fall back to the default branch.
- **Referenced PRs** that didn't request my review are context only: name them in the group's **Not reviewed (not requested)** line.

## Step 3: Read the code

1. Sync every repo the group touches, plus the consumers Step 4 will grep:
   `scripts/sync-repos.sh <repo> [<repo> ...]`
   It clones missing repos, fetches only each base branch, and parks each clone on its up-to-date base. Read its `MISSING` / `NO-BASE` / `STUCK` / `BEHIND` lines and carry them into Coverage gaps.
2. Check the PR out in place, in the repo you are reading:
   ```bash
   REPO="$ROOT/<repo>"
   git -C "$REPO" fetch -q --no-tags origin "+pull/<n>/head:pr-<n>" \
     "+refs/heads/<base>:refs/remotes/origin/<base>"
   git -C "$REPO" checkout -q -f pr-<n>
   git -C "$REPO" diff --stat "origin/<base>...HEAD"
   git -C "$REPO" diff "origin/<base>...HEAD"
   ```
   A subagent reviewing in parallel uses its own worktree instead (see **Large queues**). Only one PR is checked out per repo at a time. Every other repo stays parked on its base branch, because Step 4 greps consumers on base. If a consumer you need to grep has a PR checked out, return it to base first.
3. List the changed surfaces: exported functions, endpoints, fields, types, component props, API call sites.
4. **Open every changed file in full** in `$REPO`. Hunks hide the signature, the early return and the existing error handling.
5. Grep callers of each changed export from the repo **root**, never `src/` only. Cypress specs, `tests/`, `__mocks__/`, root `config.js` and `scripts/` live outside it:
   ```bash
   grep -rn "<identifier>" "$REPO" --exclude-dir={node_modules,dist,build,coverage,.git,.next}
   ```
6. Never review from the diff alone. No readable tree means "not reviewed".
7. Before moving to the next PR in the same repo, and when the group is done, park the repo back on its default branch: `git -C "$REPO" checkout -q -f <default-branch> && git -C "$REPO" branch -D -q pr-<n>`.

## Step 4: Cross-repo impact

For every **renamed or removed** identifier, search the **old** name. That's what breaks callers.

- **Consumers, locally**: grep the consumer clones (on their base branch) listed in `references/repos.md`, with the same excludes.
- **Whole org**: `gh search code "<old_identifier>" --owner bounceinsights --json repository,path`. It covers every repo's default branch, including ones never cloned, but indexing can lag. A hit in an unexpected repo is a finding (an unknown dependency edge); a clean result is not proof of safety.
- A rename with zero hits in a consumer that should reference it is itself a flag: dead code or a missed call site.

## Step 5: Evaluate

Read only the references the group needs:

| The group touches | Read |
|---|---|
| Anything | `references/universal.md` |
| `.jsx`/`.js`/`.tsx` UI code, hooks, client routes | `references/frontend.md` |
| Handlers, routes, services, jobs, Firestore, Redis | `references/backend.md` |
| `ts-types`, `api-core`, `dashboard-core`, or a cross-repo contract | `references/shared-contracts.md` |
| Which repo depends on what, pinned versions | `references/repos.md` |

For Firestore-heavy changes, also load the `firestore-best-practices` skill if it's installed and apply its "Reviewing Firestore code" checklist.

Run `npx -y react-doctor@latest --verbose --scope changed` inside `$REPO` while the PR is checked out when the diff changes how React components behave: new or restructured components, hooks, effects, state, context, or rendering of lists and large data. Skip it for copy, i18n keys, styles, config and small prop tweaks. Stop it if it hasn't finished within about two minutes. Its output is a list of **candidates**: each one still goes through Step 6, and none is pasted raw. Its rules assume modern React, so drop anything that doesn't apply to the repo's React version (`references/frontend.md`).

**Don't run test suites, typechecks, builds or `npm install`.** The author and CI own those, and a passing suite isn't a review signal. The exception is proving a specific finding: a few lines run against the changed function (as a throwaway script, outside the repo) are fine when they turn a suspicion into a reproduced bug. Don't list unrun tests under Coverage gaps.

The checklists are a floor, not a ceiling. When they come up empty but something feels off, ask:
1. What does this code assume that nothing guarantees?
2. What happens on the second call, the concurrent call and the failed call?
3. Who else can reach this, and with what input?

## Step 6: Verify every finding

Read `references/finding-bar.md` and apply it to each candidate before it reaches the report:

1. Re-open the anchored lines (check the PR out again if the repo was already parked) and try to **refute** the finding: pre-existing, handled elsewhere, intentional per the PR body or ticket, unreachable, or caught by the typechecker (TS repos only).
2. Score confidence 0–100 with the rubric there. Keep 80+. A 50–79 finding survives only as a **question** the author can answer. Drop the rest.
3. Deduplicate: one root cause across several PRs is one finding with several locations.
4. Cap at 8 findings per PR: keep every blocking finding and the best nits, and say how many were trimmed.

## Step 7: Report

Before writing, reconcile against `STATE/notes/$TODAY/queue.jsonl`: count its `requested` and `mine` lines, and confirm each PR appears in a table, under Unchanged, or under Coverage gaps. If any is missing, review it now. Never drop one silently.

Write the report exactly as `references/output.md` describes, save it to `STATE/reports/$TODAY.md`, and print it as the final answer. End the answer with a link to the saved file: `Report: [$TODAY.md](<absolute path>)`.

The same goes for follow-ups in the same session ("review these please: <urls>"): review them with this skill's steps, add their group sections to today's report, and answer in chat with those sections exactly as written to the report, each starting with its table. Never rewrite them as prose or bullets for chat.

Then update `state.json` with each reviewed PR's head SHA, today's date and its verdict. Leave unchanged PRs' entries as they are, so `reviewed` keeps the date of their actual review.

Once today's report is saved, delete earlier days. Today's report already carries every unchanged section, so nothing is lost:

```bash
find "$STATE/reports" -name '*.md' ! -name "$TODAY.md" -delete
find "$STATE/notes" -mindepth 1 -maxdepth 1 -type d ! -name "$TODAY" -exec rm -rf {} +
```

Skip this cleanup if the run stopped before writing today's report. Worktree cleanup always runs:

```bash
find "$ROOT" -mindepth 2 -maxdepth 2 -name .git -type d -exec sh -c 'git -C "${1%/.git}" worktree prune' _ {} \;
rm -rf "$ROOT/.wt"
```

Questions about a PR already reviewed run in the main clone, in place, one PR at a time (Step 3). Check out the head SHA recorded in `state.json`, so the answer matches the reviewed code. If the PR has newer commits, say so.

**Never post to GitHub during a review run.** Posting happens only when I ask afterwards, following the posting rules in `references/output.md`.

## Large queues

With four or more groups, hand each group to a subagent and run them in parallel. With fewer, review in place in the main session.

Subagents share the clones in `ROOT`, so each one works in its own worktree:

1. **Main session, before starting subagents:** run `sync-repos.sh` for every repo any group touches, then fetch every queued PR (the `fetch` in Step 3.2). Git locks refs during a fetch, so parallel fetches into one clone fail.
2. **Each subagent** gets the group's PRs, `ROOT`, `STATE`, the Step 2 notes and the paths of the reference files to read. For each PR it creates a worktree and reviews there:
   ```bash
   WT="$ROOT/.wt/<group>-<repo>-<n>"
   git -C "$ROOT/<repo>" worktree add -q --detach "$WT" pr-<n>
   ```
   It follows Steps 3–5 with `$WT` as `$REPO`, but greps consumers in the main clones, which stay on their base branch. It never checks out anything in a main clone. Findings use `repo/path:line`, never the worktree path.
3. **When its group is done**, the subagent writes candidates to the notes file and removes its worktrees: `git -C "$ROOT/<repo>" worktree remove --force "$WT"`.
4. **Step 6 runs in the main session after every subagent has finished**, so one consistent bar applies to every finding and no checkout in a main clone moves a tree a subagent is reading. Re-open anchored lines by checking the PR out in place, as in Step 3.
