---
name: bounce-code-review
description: Review open bounceinsights pull requests that request my review or that I authored, from real checkouts, and write a grouped report with verified findings. Run only when explicitly invoked, e.g. by the daily review task.
disable-model-invocation: true
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
mkdir -p "$STATE/notes/$TODAY" "$STATE/reports" "$STATE/worktrees"
```

- `ROOT/<repo>` are disposable review clones. Updating or resetting them is fine. Never touch `~/bounce`, which holds work in progress.
- `STATE/state.json` maps `repo#number` to `{ "head": "<sha>", "reviewed": "<date>", "verdict": "..." }` from earlier runs.
- Write each group's findings to `STATE/notes/$TODAY/<group>.md` as soon as the group is done, so a context compaction never loses work.

## Step 1: Find the PRs

Run `scripts/find-prs.sh`. It prints one JSON object per PR with `repo`, `number`, `title`, `author`, `isDraft`, `url` and `reason` (`requested` or `mine`). `review-requested:@me` already includes requests to teams I'm on.

- **Requested** PRs get a full review. Drafts included, marked `_draft_`.
- **Mine** PRs get the same review. I can't approve my own PR, so their verdict is only a readiness signal. Skip my **drafts** not updated in 14 days; list them in one line under Coverage gaps.
- **Unchanged** PRs: if `state.json` has the same head SHA (found in Step 2), don't re-review. List them in the report's Unchanged section with the last verdict and date.

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
- **Referenced PRs** that didn't request my review are context only: name them in the merge order, marked "not requested".

## Step 3: Read the code

1. Sync every repo the group touches, plus the consumers Step 4 will grep:
   `scripts/sync-repos.sh <repo> [<repo> ...]`
   It clones missing repos, fetches only each base branch, and parks each clone on its up-to-date base. Read its `MISSING` / `NO-BASE` / `STUCK` / `BEHIND` lines and carry them into Coverage gaps.
2. Check the PR out into its own worktree, so the base clone stays on base for greps:
   ```bash
   git -C "$ROOT/<repo>" worktree prune
   git -C "$ROOT/<repo>" fetch -q --no-tags origin "+pull/<n>/head:pr-<n>" \
     "+refs/heads/<base>:refs/remotes/origin/<base>"
   git -C "$ROOT/<repo>" worktree add -f -q "$STATE/worktrees/<repo>-<n>" pr-<n>
   WT="$STATE/worktrees/<repo>-<n>"
   git -C "$WT" diff --stat "origin/<base>...HEAD"
   git -C "$WT" diff "origin/<base>...HEAD"
   ```
3. List the changed surfaces: exported functions, endpoints, fields, types, component props, API call sites.
4. **Open every changed file in full** in `$WT`. Hunks hide the signature, the early return and the existing error handling.
5. Grep callers of each changed export from the repo **root**, never `src/` only. Cypress specs, `tests/`, `__mocks__/`, root `config.js` and `scripts/` live outside it:
   ```bash
   grep -rn "<identifier>" "$WT" --exclude-dir={node_modules,dist,build,coverage,.git,.next}
   ```
6. Never review from the diff alone. No readable tree means "not reviewed".
7. When the group is done: `git -C "$ROOT/<repo>" worktree remove --force "$WT" && git -C "$ROOT/<repo>" branch -D -q pr-<n>`.

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

For frontend changes, optionally run `npx -y react-doctor@latest --verbose --scope changed` inside `$WT`. Use it only if it finishes within about two minutes. Its output is a list of **candidates**: each one still goes through Step 6, and none is pasted raw.

The checklists are a floor, not a ceiling. When they come up empty but something feels off, ask:
1. What does this code assume that nothing guarantees?
2. What happens on the second call, the concurrent call and the failed call?
3. Who else can reach this, and with what input?

## Step 6: Verify every finding

Read `references/finding-bar.md` and apply it to each candidate before it reaches the report:

1. Re-open the anchored lines in `$WT` and try to **refute** the finding: pre-existing, handled elsewhere, intentional per the PR body or ticket, unreachable, or caught by the typechecker (TS repos only).
2. Score confidence 0–100 with the rubric there. Keep 80+. A 50–79 finding survives only as a **question** the author can answer. Drop the rest.
3. Deduplicate: one root cause across several PRs is one finding with several locations.
4. Cap at 8 findings per PR: keep every blocking finding and the best nits, and say how many were trimmed.

## Step 7: Report

Write the report exactly as `references/output.md` describes, save it to `STATE/reports/$TODAY.md`, and print it as the final answer.

Then update `state.json` with each reviewed PR's head SHA, today's date and its verdict.

**Never post to GitHub during a review run.** Posting happens only when I ask afterwards, following the posting rules in `references/output.md`.

## Large queues

With four or more groups, you may hand each group to a subagent to keep this context small. Give it the group's PRs, `ROOT`, `STATE`, the Step 2 notes and the paths of the reference files to read. Have it write candidates to the notes file. Step 6 always runs in the main session, so one consistent bar applies to every finding.
