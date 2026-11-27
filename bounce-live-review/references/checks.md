# Running checks

## Manifest

`$REVIEW_DIR/review-manifest.json`, written by review-tool:

- `_review`: the repo and PR the environment runs.
- `<repo>.url`, `<repo>.log`: where each app answers and where its server log goes. `dashboard.ui_paths.login` is the login path.
- `dashboard-api.firestore_emulator`, `dashboard-api.sign_in_url`: the Firestore emulator and the Auth emulator sign-in endpoint.
- `_auth.accounts` (email, password, uid), `_auth.defaults` (`bounce_admin`, `client_user`) and `_auth.clear_session_js`.

Never write a password into a plan, result, report or chat. Read it from the manifest when you type it.

## Personas

Pick each check's account in this order:

1. The PR names an account for the step (an Accounts table, or "as `x@bounce.test`"): use it.
2. Admin rights or "Bounce admin": `_auth.defaults.bounce_admin`.
3. A user or client, or no persona named: `_auth.defaults.client_user`.
4. A persona the seed data has but the defaults can't play (another org, a team member, a read-only user): find a matching account in `_auth.accounts` from its email and the emulator data, and say which you picked and why.
5. None fits: `BLOCKED: needs persona <x>`. Never substitute. A cross-tenant 403 run as the wrong account passes for the wrong reason.

Give each persona its own session, named `<group>-<persona>`:

```bash
playwright-cli -s=<group>-<persona> open <url> --config="$LIVE/playwright-cli.json"
```

Sessions don't share cookies, storage or IndexedDB, so one Firebase login can't leak into another. Log in once per session through the app's login page and reuse it. To switch accounts in one session, run `_auth.clear_session_js` with `eval` and reload.

## Recording

One video per check, in that check's session:

```bash
playwright-cli -s=<session> video-start --size 1280x720 "$LIVE/<group>/<n>-<slug>.webm"
playwright-cli -s=<session> video-show-actions
playwright-cli -s=<session> video-chapter "<sub-action>"   # one per sub-action
playwright-cli -s=<session> video-stop
```

- Always pass an absolute path, and keep `--size` equal to the config's viewport so text stays readable.
- `video-show-actions` labels each click and fill in the video, so a reviewer can follow it without the transcript.
- A check that switches persona records one video per persona, with the persona in the slug.
- If `video-start` asks for ffmpeg, run `playwright-cli install-browser ffmpeg`.
- Take a `screenshot` of the final state of every FAIL and of anything a PASS hinges on.

## Reading the page

Snapshots go to files, not into your context. Use `find "<text>" --max-results=5` to read what you need; open a snapshot file only when `find` isn't enough. Act on elements by role and visible name (button text, field label).

## UI checks

1. Go to the path, do what the check says, and wait for the result to render.
2. Read the expected text with `find`, and the network calls the check depends on with `requests --all`, then `request <n>` or `response-body <n>`. `--all` keeps requests from before a navigation.
3. Put the observed value in Actual: the exact text, the status and the relevant response field.

## API checks

1. Get an ID token: POST `{"email","password","returnSecureToken":true}` to `_auth.sign_in_url` and use `idToken`.
2. Open the API's own URL first (any route), so `fetch` is same-origin.
3. Call it with `eval "async () => { const response = await fetch(...); ... }"` and `Authorization: Bearer <idToken>`, unless the check is unauthenticated.
4. Write method, route, persona, status and body onto the page (append to `document.body`), so the video shows them.

## Log checks

After the request, search the repo's `log` from the manifest for the entry (route, requestId, time) and save it to `$LIVE/<group>/<n>-<slug>.log.json`.

## Test data

When the seed data lacks what a check needs:

1. Create it the way a user would, through the UI or API, as a recorded **setup** check.
2. If that can't work locally, write documents straight into the Firestore emulator (`dashboard-api.firestore_emulator`, project `demo-bounce`), copying the shape the backend's create code builds. Only ever write to the emulator.
3. Say in the results what you seeded and how.

## "Before this PR"

The environment only runs the PR branches. To compare with the old behaviour, read `master`'s code (`git -C "$REVIEW_DIR/<repo>" show origin/master:<file>`) and say that's what you did.

## Breaking it

Break-it checks are where live testing earns its cost. For each one, write down what should happen before you try it, e.g. "a double click on Start Project creates one project". Then:

- **Inputs**: empty, whitespace-only, very long, emoji/RTL, the maximum the UI allows plus one.
- **Timing**: double submit, navigating away mid-request, reload during a loading state, two tabs editing the same thing.
- **Access**: the same URL as another org's user, a read-only user, or signed out.
- **State**: the flag off, the empty state (no data), lots of data, and data created before this PR.
