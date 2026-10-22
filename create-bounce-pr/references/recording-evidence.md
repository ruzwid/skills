# Recording evidence with Playwright

Record a walkthrough video and capture screenshots of the change running locally, then attach them to the PR. Only do this when the user asks for a recording or screenshots, or when they accept your offer for a visual change.

## 1. Check the setup

Load the `playwright-cli` skill first (Skill tool) so you use the current command syntax, then check the CLI:

```bash
which -a playwright-cli
playwright-cli --version
playwright-cli --help | grep -E "video-chapter|find"
```

If the command is missing, or `--help` has no `video-chapter`, the install is missing or out of date. Ask the user to run:

```bash
npm install -g @playwright/cli@latest
```

```bash
npx playwright install --with-deps
```

```bash
playwright-cli install --skills --global
```

With nvm, each Node version has its own global packages. If `which -a` lists more than one `playwright-cli`, the first one on the `PATH` wins. Use the newest by prefixing commands with its directory, for example `PATH=~/.nvm/versions/node/<version>/bin:$PATH playwright-cli ...`, or ask the user to `nvm use` that version.

Don't install `@playwright/test` into a Bounce repo just to record. It changes that repo's `package.json`.

## 2. Get the app ready

- **Services** — the recording runs against the user's local services (dashboard on `http://localhost:3000` in dev, or the review ports). Confirm they respond before recording.
- **Accounts** — use emulator test accounts only, never real client logins. Look for documented test accounts in `~/bounce/emulator-data` (for example a `TEST_ACCOUNTS.md`) or ask the user which account to use.
- **Feature flags** — the dev dashboard exposes its GrowthBook instance as `window.__growthbook`. To force flags on from the first page load, and after every reload, add an init script before navigating:
  ```js
  await page.context().addInitScript((flags) => {
    Object.defineProperty(window, '__growthbook', {
      configurable: true,
      set(gb) {
        gb.setForcedFeatures(new Map(flags));
        Object.defineProperty(window, '__growthbook', { value: gb, writable: true, configurable: true });
      },
    });
  }, [['my-feature-flag', true]]);
  ```
  Some pages sit behind other flags (the Retrieval Engine tab needs `retrieval-engine`, impersonation needs `retrieval-engine-impersonate-client`), so force those too when the test account isn't targeted by them.
- **Data** — the scenario should start from a known state. Note anything the recording will create (tags, surveys, files) so you can remove it afterwards.

## 3. Learn the locators with a dry run

Walk the scenario once without recording, using `snapshot`, `find` and short `run-code` calls, and note a stable locator for each step. Prefer `data-cy` attributes, then roles and placeholders.

Gotchas from the Bounce dashboard:

- **antd tables** render a hidden measure row, so wait for `tbody tr.ant-table-row`, not `tbody tr`.
- **Empty tables** have no data rows; wait for the table itself instead.
- **The sidebar** shows icons only, and its text labels are hidden. Use `data-cy` items such as `[data-cy=log-out]`, or `page.goto` the route.
- **Product tours** (driver.js popovers) can cover the page on first visit. Close them with `.driver-popover-close-btn`.
- **Confirm dialogs** are `.ant-modal-confirm`, separate from the modal that opened them.
- **Forced flags** reset on a full reload unless they come from the init script above.

## 4. Write the hero script

Put everything under `/tmp/bounce-pr/evidence/`. Write the scenario as one file and run it with `run-code --filename`, so pacing, chapters and screenshots are part of the script:

```js
async page => {
  const OUT = '/tmp/bounce-pr/evidence';
  const pause = (ms = 1200) => page.waitForTimeout(ms);
  const chapter = (title, description) =>
    page.screencast.showChapter(title, { description, duration: 3200 });

  await page.setViewportSize({ width: 1440, height: 900 });
  await page.screencast.start({ path: OUT + '/walkthrough.webm', size: { width: 1440, height: 900 }, fps: 30 });
  await page.screencast.showActions({
    duration: 700,
    position: 'top-right',
    style: {
      point: 'width: 18px; height: 18px; border-radius: 50%; background: rgba(214, 51, 196, .65)',
      title: 'font-size: 15px',
    },
  });

  await chapter('Open the page', 'What this part of the video shows');
  await page.goto('http://localhost:3000/...');
  await pause();
  await page.screenshot({ path: OUT + '/01-<state>.png' });

  // One chapter per step of the Functionality Review, with a screenshot at each state worth showing.

  await page.screencast.hideActions();
  await page.screencast.stop();
  return 'done';
}
```

Then:

```bash
playwright-cli -s=pr open about:blank
```

```bash
playwright-cli -s=pr run-code --filename=/tmp/bounce-pr/evidence/hero.js
```

```bash
playwright-cli -s=pr close
```

Guidelines:

- **Mirror the Functionality Review.** One chapter per step group, so the video doubles as the review demo.
- **Pace it for a human.** Type with `pressSequentially(text, { delay: 40 })`, and pause about a second after each visible change.
- **Keep it short.** Aim for under 3 minutes. GitHub limits videos to 10 MB on free plans and 100 MB on paid ones.
- **Show backend proof** when the change writes data. A screenshot of the document in the Firestore emulator UI (`http://localhost:4000/firestore/default/data/<collection>/<docId>`) shows the stored fields. Open it in a second page with a tall viewport (for example 1440×1500) so the fields you care about are visible.
- **Keep secrets out.** `run-code` echoes the whole script in its output, so only emulator test passwords may appear in it, never real credentials.
- **When it fails partway,** the screenshots taken so far are kept, but the data changes are too. Reset the test data before re-running, so the video starts from the same state.

## 5. Check before attaching

- Look at every screenshot (Read the image), and confirm the video exists and is a sensible size.
- Never attach anything showing client data (respondent answers, client names, emails). Uploads to GitHub can't be undone.
- Remove whatever the recording created, so the user's local data and emulator-data exports stay clean.

## 6. Attach

Reference each file by absolute path in the body, and pass the same path to `--attach` on `gh pr create` or `gh pr edit`. `gh` uploads the files and rewrites the links (see Step 5 in `SKILL.md`). A video renders as a player and takes no alt text:

```markdown
![Walkthrough](/tmp/bounce-pr/evidence/walkthrough.webm)
```

Lay the screenshots out with a format from **Choosing visuals** in `writing-the-body.md`.
