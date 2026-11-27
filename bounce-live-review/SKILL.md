---
name: bounce-live-review
description: Test bounceinsights PR groups live in a real browser against the local review environment (bounce-tools review-tool.sh), with playwright-cli. Runs the PR's Functionality Review, tries to reproduce the code review's findings, tries to break the change, records a video per check, and adds a Live check section to today's review report. Run only when explicitly invoked, usually after bounce-code-review in the same thread.
disable-model-invocation: true
effort: medium
argument-hint: "<BOUN-XXXXX | repo#number | PR url> [...]  (omit to pick from today's report)"
allowed-tools: Bash(playwright-cli:*)
---

# Bounce Live Review

Test the PR groups I pick in a real browser, against a real local environment. A check only passes on something you saw: text on the page, a status code, a response field, a log line. "The page loaded" is not a pass.

Arguments: `$ARGUMENTS`. Ticket codes, `repo#number` or PR URLs. With none, list the groups in today's report (`STATE/reports/$TODAY.md`) with their verdicts and ask which to test.

## Setup

```bash
STATE="$HOME/review/.code-review"
TODAY=$(date +%F)
LIVE="$STATE/live/$TODAY"
REVIEW_TOOL="$HOME/bounce/bounce-tools/scripts/review-tool.sh"
mkdir -p "$LIVE"
jq -n --arg out "$LIVE/.playwright-cli" \
  '{outputDir: $out, browser: {contextOptions: {viewport: {width: 1280, height: 720}, locateOnlyVisible: true}}}' \
  > "$LIVE/playwright-cli.json"
find "$STATE/live" -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} +
```

- `REVIEW_TOOL` is run from my bounce-tools checkout, which may have local changes. Run it; never edit, commit or pull anything in `~/bounce`.
- `REVIEW_DIR` (`~/review`) is also where bounce-code-review keeps its clones, and review-tool resets them to the PR branches. **Never run while a code review is running.** The next code review puts its clones back on base by itself.
- Open every browser session with `--config="$LIVE/playwright-cli.json"`. `locateOnlyVisible` stops clicks failing on hidden duplicate elements.
- Only ever act on `localhost` URLs and the local emulators. Stop if a step points at a deployed environment.

## Keep it cheap

I'm on a small plan. Spend tokens where they change the verdict:

- **Batch known steps.** Once a check's locators are known, run its actions and reads as one `run-code` script that returns a short summary, instead of one command per click. Use single commands only to find a locator you don't know.
- **Wait without polling.** Wait for review-tool with the Monitor tool, or one background `until grep -q 'Review process initiated successfully' <log>; do sleep 30; done`. Never check the log by hand in a loop.
- **Read narrowly.** `find --max-results=5`, not whole snapshots. Don't Read screenshots or videos unless a FAIL needs it.
- **Stop early.** If the environment can't support most of a group's checks, mark them `BLOCKED` and move on rather than working around it.

## Step 1: Preconditions

Check all of these before starting anything, and stop with exactly what to fix if one fails:

1. `playwright-cli --version` is 0.1.25 or newer. Older versions crop the bottom of headless videos and drop requests across navigations. If it's older, ask me to run `npm install -g @playwright/cli@latest`.
2. `REVIEW_DIR` and `GITHUB_API_KEY` are set. review-tool fetches the PR body with `curl` and that key, not `gh`, and exits without it. Test with `[ -n "$GITHUB_API_KEY" ] && echo set`; never print it.
3. `aws sts get-caller-identity` succeeds. If not, ask me to run `aws sso login`; never run it yourself.
4. `jq`, `python3` and Docker are available.

Then tell me in one line: which groups run, in which order, roughly 15 minutes of setup each, and that starting kills whatever listens on the review ports (`cleanup_ports` in review-tool.sh), including a review environment I already have up.

## Step 2: Plan each group

For each group, before starting its environment:

1. **Entry PR**: the group's PR whose body has `**Repository to Pull From:**` entries; that's the one review-tool starts. If several do, use the one with the most entries. If none do, mark the group `BLOCKED: no review-tool body` and move on.
2. **Read** each PR's body, its diff (`gh pr diff`), and the group's section in today's report, if there is one.
3. **Build the check list** from four sources, labelled by source. Aim for 3–8 checks, fewer for a small change. Every check must be able to change the verdict; drop any that can't:
   - **PR step**: each Functionality Review step after setup. Steps are often short and generic; make each one concrete from the diff (which button, which expected text or response).
   - **Finding**: each blocking finding, question, or nit the UI or API can trigger, from the code review. The check tries to reproduce it.
   - **Regression**: 0–2 existing flows, only when the diff touches shared code.
   - **Break it**: 1–3 attempts of your own, from the diff. Pick what the change makes likely: empty, long or odd input, double submit, back button or reload mid-flow, a second tab, another persona or org, the feature flag off.
4. **Personas**: for each check, who runs it (`references/checks.md`).
5. Write the plan to `$LIVE/<group>/plan.md`: one line per check with its source, persona, action and expected result.

Don't ask me to approve the plan; start.

## Step 3: Run the environment, one group at a time

There is one environment: fixed ports and one emulator. Groups never run in parallel.

1. Start review-tool detached, so it doesn't depend on the session:
   ```bash
   nohup bash "$REVIEW_TOOL" <repo> <pr> > "$LIVE/<group>/review-tool.log" 2>&1 &
   echo $! > "$LIVE/<group>/review-tool.pid"
   ```
2. Wait for `Review process initiated successfully` in the log, with the Monitor tool or one background `until` loop (see **Keep it cheap**). Stop and report the relevant lines on `ERROR`, `Failed to fetch Pull Request description`, or no new output for 10 minutes.
3. **PR setup steps** beyond what review-tool does (e.g. `sh ./scripts/dev_local_startup.sh` in retrieval-engine-v2, which review-tool only clones, or indexing test files): run them now, before judging what's up, but only if they act on `$REVIEW_DIR` checkouts and local services. Anything that deploys, writes to a cloud resource, or needs credentials beyond the emulator: mark the checks that need it `BLOCKED` and say so.
4. Confirm everything is up:
   - `$REVIEW_DIR/review-manifest.json` has `_review` = this PR.
   - Every repo in the PR's Repositories to Review (except `emulator-data`) is running: it has a manifest entry whose `url` answers, or it was started by a setup step and answers on its port. Allow a minute or two for dev servers to compile.

   Only now, a repo that still doesn't answer makes its checks `BLOCKED`, with the log lines that say why.

## Step 4: Run the checks

Follow `references/checks.md` for personas, recording, UI, API and log checks, and test data.

- Run every group in this session, one after another, and write `$LIVE/<group>/results.md` as soon as a group is done, so a context compaction never loses work. Subagents would start cold and re-read everything.
- Record every check, so each result has a video. Videos cost no tokens; reading them does.
- **After every check**, before choosing its result, read `console --all` and `requests --all` for the time it ran. A new console error or a 4xx/5xx caused by the change is a finding even when the check passed. Folding these reads into the check's `run-code` script keeps it to one call.

## Step 5: Judge the results

For each check, settle one result:

- **PASS**: the Actual column quotes what you saw, and it matches Expected.
- **FAIL**: what you saw contradicts Expected. Retry once only if timing could explain it (a slow load, a race); a deterministic response, like a 200 where a 403 was expected, needs no retry.
- **BLOCKED: <why>**: the environment, persona or data couldn't support the check. Never test around it with a different account.
- **UNVERIFIED**: it ran, but you couldn't observe the thing that matters (e.g. no request to read, a toast that vanished before the snapshot). Never round it up to PASS.

Finding checks also say **reproduced** or **not reproduced**. Not reproducing a code finding doesn't refute it, unless the run shows the path is guarded (e.g. a 403 from the middleware the finding says is missing). Say which.

Before reporting a FAIL:
1. Rule out the environment: the service is up, its log has no startup error, and the persona and data are right. An environment problem is `BLOCKED`.
2. Find the cause in the code and anchor it to `repo/path:line` at the PR's head, applying bounce-code-review's `references/finding-bar.md`. A FAIL with no cause in the diff is reported as one, marked "cause not found".

## Step 6: Report

Write each group's section as `references/output.md` describes:
1. Save it to `$LIVE/<group>/results.md`.
2. If the group is in today's report, insert it under that group's section, before **Recommendation**.
3. Add each new FAIL cause to that group's **Blocking** or **Nits**, tagged `_(reproduced live, check <n>)_`.
4. Re-derive the row and group verdicts.

Print the group sections in chat word for word. End with a link to what was written: `Report: [$TODAY.md](<absolute path>)` when the sections went into today's report, otherwise one `Results: [<group>](<absolute path to results.md>)` line per group.

## Step 7: Clean up

- Close each browser session: `playwright-cli -s=<session> close`.
- Stop review-tool after the last group: `kill $(cat "$LIVE/<group>/review-tool.pid")`. If I said to keep it up, leave it running and tell me how to stop it.
- Keep the videos in `$LIVE` for a week (Setup deletes older days).

**Never post to GitHub during a run.** When I ask afterwards, follow the posting rules in `references/output.md`.
