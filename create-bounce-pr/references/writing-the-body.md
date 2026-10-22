# Writing the body

Skip all preambles and keep prose brief. Every sentence should save the reviewer time.

## `### Context`

Give reviewers the picture so they understand the PR before reading code. Cover whichever beats actually apply — don't manufacture filler:

- **Situation** — what existed before, how it worked
- **Problem** — what broke or was missing, and why it mattered
- **Fix** — what this PR does about it, in one sentence

A small refactor may only need Situation + Fix. A bug fix usually needs all three.

**Bad:**

> Fixed formatting bug in surveys

**Good:**

> PR #1833 fixed "Placeholder" text rendering in WPP surveys by clearing `columnChoicesFormatting` and `rowItemsFormatting` to empty arrays in `shiftAndInsertQuestions`. This worked but had a side effect — it stripped all rich text formatting (bold/italic/underline) from matrix questions, breaking the formatting support added in #500.
>
> The proper fix for the Placeholder mismatch is handled in the companion PR (BOUN-10345), which regenerates formatting at runtime when rules overwrite options.

## `### What changed`

Lead with a visual, then follow with short bullets.

### Visual summary

Pick the smallest view that makes the key point clear. For a visible UI change, a screenshot (or a before/after pair) usually beats a component tree. Keep the tree for structural changes a screenshot can't show. **Choosing visuals** below lists every format.

- Show logic or an algorithm as pseudocode:

```text
on(save)
  if content is unchanged
    return cached result
  write new content
  return fresh result
```

- Show runtime control flow as a call tree:

```text
submitForm
  createSession
    persistPrompt
    launchAgent
  navigateToSession
```

- Show UI structure as a component tree, including state and module boundaries that matter:

```text
<SurveyEditor> (dashboard/src/pages/survey-editor.tsx)
  useSurveyQuestions()
  <QuestionList>
    <MatrixQuestion> (dashboard-core)
```

- Show file responsibility or a broad refactor as a shallow file tree:

```text
src/
├── rules/          # runtime answer rules
├── formatting/     # rich text generation
└── export/         # survey → editor normalisation
```

- Show cross-repo interaction, control flow, or data flow with Mermaid — the natural fit when a change spans several Bounce services:

```mermaid
sequenceDiagram
    participant Dashboard
    participant DashboardAPI as dashboard-api
    participant API as api
    Dashboard->>DashboardAPI: create survey
    DashboardAPI->>API: publish questions
    API-->>Dashboard: survey link
```

- Use `diff` when the point is what changes and the surrounding shape already exists. Match the diff shape to the topic.

For a call-tree change:

```diff
 shiftAndInsertQuestions
   shiftQuestionIndexes
-  clearFormatting
+  preserveFormattingArrays
   insertQuestions
```

For a component change:

```diff
 <SurveyEditor>
   <QuestionList>
+    <RefreshButton />
   <QuestionPreview>
```

For a file-layout change:

```diff
 src/
 ├── rules/
+│   └── generate-formatting.ts   # rebuilds formatting at runtime
-└── formatting.ts
+└── formatting/
+    ├── matrix.ts
+    └── single-choice.ts
```

For a state or control-flow change:

```diff
 on(ruleOverwritesOptions)
-  update rowItems
+  update rowItems
+  regenerate rowItemsFormatting
```

- Show the whole block when most of it is new, when omitted context would hide ownership or order, or when the reviewer needs a copyable target shape.

Place each visual next to the short text it supports. Keep only the calls, files, props, states, and boundaries needed to understand this PR. You may use one, you may use several — it is unlikely you will use all of them. Use your judgement and don't overwhelm the reviewer. A trivial change (copy tweak, config bump) needs no visual.

### Bullets

Use a **table** instead when 3+ fields, options, or behaviors change in the same structured way.

- Start each bullet with a verb: "Update", "Add", "Remove", "Refactor", "Revert"
- Wrap code identifiers in backticks
- One clear action per bullet; don't repeat what the visual already shows
- Single repo → plain bullets. Multiple repos → group by repo name with sub-bullets indented 3 spaces.

**Bad:**

```
- Fixed some stuff
- Made changes to the survey page
```

**Good — multiple repos:**

```
- **web-surveys**:
   - Update `shiftAndInsertQuestions` to preserve formatting arrays
   - Remove dead `clearFormatting` code path
- **api**:
   - Add `generateFormatting()` helper to runtime rule execution
```

**Good — table:**

```markdown
| Where options change | Formatting updated? |
|---|---|
| mainWpp creates questions | No formatting created at all |
| exportSurveyToEditor normalizes | Yes — generates from current values |
| pipeFamiliarBrandsRule (runtime) | NO — only updates rowItems |
```

## `## Evidence`

Concrete proof the change works. This is what the author already verified, unlike Functionality Review, which is what the reviewer will do.

Use execution-based evidence: tests, typecheck or lint output, console output, a `curl` response. Paste real output trimmed to the relevant lines. Only include evidence you actually ran or saw in this session or the branch history. Never invent output.

**Test runs** go in one compact block for all repos: a `#` heading per repo with the command, its trimmed output, and `---` between repos:

````markdown
- **Tests**
  ```markdown
  # dashboard-api — `jest src/routes/tags` (Firestore emulator)
  PASS src/routes/tags/index.test.ts
  PASS src/routes/tags/sourceTags.test.ts
  Tests:       150 passed, 150 total
  ---
  # retrieval-engine-v2 — `uv run pytest tests/unit`
  1363 passed
  ---
  # dashboard — `jest src/customComponents/__tests__`
  Tests:       309 passed, 309 total
  ```
````

Follow it with one line on what the new tests cover, if that isn't obvious from their names.

**A bug fix** shows the specific test that failed before and passes now:

```markdown
- **Before:** `formatting.test.ts › preserves matrix formatting on shift` — fails, `rowItemsFormatting` is `[]`
  **After:** passes
```

### Recordings and screenshots (visual changes)

When the user asks for a recording or screenshots, or accepts your offer for a visual change, record them yourself with Playwright: follow `references/recording-evidence.md`. Lay out the result with a format from **Choosing visuals** below.

If the user already has screenshots of their own, ask which ones to use and which are **before** vs **after**; never guess. Copy them to `/tmp/bounce-pr/evidence/` with clean names (macOS screenshot names contain characters that break markdown links) and attach them the same way.

If the change is visual and there is nothing to attach, leave a placeholder and remind the user to drag images into the PR on GitHub:

```markdown
- **Before:** <!-- drag screenshot here -->
  **After:** <!-- drag screenshot here -->
```

If the change isn't visual and there is no execution evidence either, omit the whole `## Evidence` section.

## Choosing visuals

Pick per PR, by what the reviewer most needs to see. Most PRs need one or two of these, not all. Text visuals (pseudocode, call trees, Mermaid, `diff`) are under **Visual summary** above.

| Format | Best for |
|---|---|
| Single screenshot | A new screen or state; one look explains it |
| Before/after table | Layout, styling or copy changes; several comparisons stacked as rows |
| Walkthrough video | Multi-step flows, interactions, anything that moves |
| State grid | A component's empty, loading, error and filled states side by side |
| Permission matrix | Features that differ by role, org, team or flag |
| Data proof | Changes that write data: the stored document, or a before/after of its shape |
| API example | New or changed endpoints: a request and its response |
| Responsive pair | Changes that must work on desktop and mobile |
| Collapsible section | Long logs, extra screenshots, secondary detail |
| Metrics table | Performance work: numbers before and after |

Before/after table (GitHub renders images in table cells; add rows for more comparisons):

```markdown
| Before | After |
|---|---|
| ![Before](/tmp/bounce-pr/evidence/before-table.png) | ![After](/tmp/bounce-pr/evidence/after-table.png) |
| ![Before](/tmp/bounce-pr/evidence/before-modal.png) | ![After](/tmp/bounce-pr/evidence/after-modal.png) |
```

Permission matrix (checked roles only; say how each was verified):

```markdown
| Who | Sees tags | Can tag | Verified by |
|---|---|---|---|
| Org root | ✅ | ✅ | recording, chapter 2 |
| Read-only member | ✅ | ❌ | screenshot below |
| Another org | ❌ | ❌ | `sourceTags.test.ts` |
```

Data proof, as a shape diff:

```diff
 retrievalEngineV2Files/{fileId}
   name: "Q3 report.pdf"
   status: "indexed"
+  tags: ["tagId1", "tagId2"]
```

Or as a Firestore emulator screenshot of the stored document (see `recording-evidence.md`).

API example:

````markdown
```bash
curl -X POST localhost:1337/tags/sources/apply -d '{"items":[{"type":"file","id":"abc"}],"add":["t1"],"remove":[]}'
```
```json
{ "success": true, "updated": [{ "type": "file", "id": "abc" }], "failed": [] }
```
````

Collapsible section, so extra material doesn't push the review steps down:

```markdown
<details>
<summary>More screenshots (read-only view, other org)</summary>

![Read-only view](/tmp/bounce-pr/evidence/read-only.png)
</details>
```

A responsive pair is a two-column table like the before/after one, with `Desktop | Mobile` headers. Use markdown image links only: `gh --attach` rewrites `![alt](path)` links to the uploaded files, but HTML `<img>` tags aren't documented to work.

When a screenshot needs a pointer, draw it into the page before capturing (`playwright-cli highlight`, or an overlay in the hero script) rather than editing images afterwards.

## `## Merge Danger`

**Door** — is the merge reversible?

- **Two-way door** — reverting the PR fully restores the old behaviour. Most UI, API logic, and refactors.
- **One-way door** — reverting leaves lasting effects. At Bounce, typical one-way doors:
  - Writes, migrations, or deletes against Firestore data (survey, response, or user documents)
  - Changes to stored data shapes in `ts-types` that existing documents will be written in
  - emulator-data schema changes other branches rely on
  - firestore-functions triggers that fire on deploy or mutate data
  - Anything sent externally: emails, webhooks, third-party API calls

**Blast Radius** — one word for scope (e.g. `isolated`, `page`, `service`, `cross-repo`, `platform`), then a short line on what could break. Consider layout shifts, mobile/responsive breakage, consumer breakage, and performance.

Bounce heuristics:

- Any `[Yes]` in Impact on Repositories → at least `cross-repo`. Name the consumers (e.g. a `ts-types` change touches every service that imports the changed type).
- Shared `dashboard-core` components → every dashboard page using them.
- `web-surveys` / `api` changes → respondents taking live surveys, not just internal users.

## `## Functionality Review`

Write specific, numbered steps based on what was actually built. Do not write generic steps. URLs come from the service reference in `review-tool-format.md`.

```
1. Run `review-tool <primary-repo> <PR_NUMBER>` to set up all services.
2. [Navigation step — where to go first]
3. [Action step — what to do]
4. [Verification step — what to confirm/expect]
```

`<PR_NUMBER>` is only known after the PR is created — write it as a literal placeholder; it gets filled in once the PR is open.

Each step is one of:

- **Setup** — run a command or open a URL
- **Action** — click, fill in, submit
- **Verification** — "Confirm that…", "Verify that…", "Check that…" — always end with the expected result

Write local service URLs as markdown links labelled with the service name:

- **Good** — `Open [dashboard](http://localhost:3002) and go to **My Surveys**.`
- **Bad** — `Open localhost and go to My Surveys.`

**Bad:**

> Test the feature.

**Good:**

> 1. Run `review-tool dashboard 1234` to spin up all services.
> 2. Open [dashboard](http://localhost:3002) and go to **My Surveys**.
> 3. Click the refresh button and confirm it reads "Refresh this dashboard".
> 4. Verify the list refreshes after clicking.
> 5. Go to Trackers and confirm that button still reads "Refresh".

After drafting the steps, run the flow audit in `review-tool-format.md`.
