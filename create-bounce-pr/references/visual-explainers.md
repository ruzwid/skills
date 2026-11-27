# Visual explainers

When a picture explains the change better than bullets, draw it as a small product-style UI: cards, nested containers and clear type, not a flowchart. GitHub can't render custom HTML or CSS in a PR body, so build the explainer as a static HTML page, render it to a PNG with playwright-cli, and attach it like a screenshot.

Use Mermaid only for graph relationships too tangled to lay out as cards (many-to-many dependencies, a state machine with many transitions) or formal notation a reviewer expects (a sequence diagram of a protocol).

## Design

Minimal, shadcn/ui-like:

- **Structure by nesting.** A card per service, repo or screen, with what changed as items inside it. Group related cards in a grid.
- **Hierarchy through type.** A small uppercase muted label (repo), a semibold title (component, route), plain items. One accent colour marks what's new or changed; everything else stays neutral.
- **Quiet chrome.** 1px `#e4e4e7` borders, 12px card radius, 8px item radius, white cards on `#fafafa`, consistent 12–16px spacing.
- **Few connectors.** A single muted `→` between cards when order matters. No crossing lines, no arrow labels; put the meaning in the items.
- **Show only what this PR changes**, plus just enough context to place it. Mark new items with the accent border and a small "new" tag; mark removed ones with strikethrough.
- Keep it to one image, at most about 960px wide and 3–4 cards. Two simple explainers beat one dense one. Extra ones go in a `<details>` block.

## Template

Write it to `/tmp/bounce-pr/evidence/explainer.html`, and change only the content inside `#explainer`:

```html
<!doctype html><html><head><meta charset="utf-8"><style>
:root{--bg:#fafafa;--card:#fff;--border:#e4e4e7;--muted:#71717a;--fg:#09090b;--accent:#f4f4f5;--pink:#db2777}
*{box-sizing:border-box;margin:0}
body{font:14px/1.5 -apple-system,BlinkMacSystemFont,"Inter","Segoe UI",sans-serif;color:var(--fg);background:var(--bg)}
#frame{padding:24px;width:960px;background:var(--bg)}
#explainer{display:grid;grid-template-columns:1fr auto 1fr;gap:12px;align-items:stretch}
.card{background:var(--card);border:1px solid var(--border);border-radius:12px;padding:16px}
.label{font-size:12px;color:var(--muted);text-transform:uppercase;letter-spacing:.04em;margin-bottom:8px}
.title{font-weight:600;margin-bottom:8px}
.item{background:var(--accent);border:1px solid var(--border);border-radius:8px;padding:8px 10px;margin-top:8px}
.new{border-color:var(--pink)}
.removed{text-decoration:line-through;color:var(--muted)}
.tag{font-size:12px;color:var(--pink);font-weight:500}
.arrow{align-self:center;color:var(--muted);font-size:18px}
code{font:12px ui-monospace,SFMono-Regular,Menlo,monospace}
</style></head><body><div id="frame"><div id="explainer">
  <div class="card"><div class="label">dashboard</div><div class="title">Composer</div>
    <div class="item new">Tag picker <span class="tag">new</span></div>
    <div class="item">Send</div></div>
  <div class="arrow">→</div>
  <div class="card"><div class="label">retrieval-engine-v2</div><div class="title"><code>POST /sources/retrieve</code></div>
    <div class="item new"><code>tagIds</code> scope check <span class="tag">new</span></div>
    <div class="item">Weaviate search</div></div>
</div></div></body></html>
```

Change `grid-template-columns` to fit the layout: `1fr auto 1fr` for two cards with an arrow, `repeat(3, 1fr)` for three side by side, or a single column with cards nested inside a parent card for one service's internals.

## Render

playwright-cli doesn't open `file://` pages, so serve the folder for a moment. Render at 2× so it's sharp on retina screens, and capture `#frame` so the card edges aren't clipped:

```bash
cd /tmp/bounce-pr/evidence
echo '{"browser":{"contextOptions":{"viewport":{"width":1008,"height":800},"deviceScaleFactor":2}}}' > explainer.config.json
python3 -m http.server 8765 --bind 127.0.0.1 >/dev/null 2>&1 & SERVER=$!
playwright-cli -s=explainer open http://127.0.0.1:8765/explainer.html --config=/tmp/bounce-pr/evidence/explainer.config.json
playwright-cli -s=explainer run-code "async page => { await page.locator('#frame').screenshot({ path: '/tmp/bounce-pr/evidence/explainer.png' }); return 'ok'; }"
playwright-cli -s=explainer close
kill $SERVER
```

Look at the PNG (Read the image) before attaching: nothing clipped or overflowing, and readable at GitHub's width. Attach it like any screenshot (`![What changed](/tmp/bounce-pr/evidence/explainer.png)` plus `--attach`), directly under **What changed**.
