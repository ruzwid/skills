# Visual explainers

An explainer shows how the change works under the hood: the services it touches, what passes between them, the call chain inside them, and where state is stored. It's for architecture, data flow and backend behaviour. Product screens belong in Evidence as screenshots, not here; don't mock the UI.

GitHub can't render custom HTML in a PR body, so build the explainer as a static HTML page, render it to a PNG with playwright-cli, and attach it like a screenshot. Use Mermaid only for relationships too tangled for cards (a state machine with many transitions) or notation a reviewer expects.

## Layout

Pick the one that answers the reviewer's main question. If it isn't obvious, render two or three and let the user choose before attaching.

- **System map** (default): the service that changed is a large card in the middle, holding its route and its call chain in order. The services it talks to (other repos, Firestore, Weaviate, Langfuse, an LLM) are small cards on the left and right. Each connector runs from the row that makes the call to the service it calls.
- **Swimlanes:** one row per system and one column per step; each card is the work that system does at that step. For "who does what, in what order".
- **Data journey:** the data's shape at each step as small JSON blocks (request, stored document, model input and answer, final document). For changes whose point is the data.

## Content

- **Real names.** Routes (`POST /api/v1/files/indexing`), functions (`auto_tag_file()`), file paths (`tags/auto_tag.py`), constants and models. A reviewer should be able to find each box in the diff.
- **Connector labels** say what passes, in one or two words: `auto_tag`, `prompt`, `1 call`, `tags`, `status`.
- **Emphasis by change:**
  - **New:** olive border, olive tint, solid olive **New** pill, solid olive connectors.
  - **Changed:** olive outline **Changed** pill (dashed border on the box).
  - **Unchanged:** no badge, muted text, grey connectors. Only enough of it to place the change.
- **Edge cases in one line** under the map, e.g. when a step is skipped. Numbers only if measured.

## Style

Granola light: copy the `:root` block from `references/granola-design.md` into the template.

## Template

Write `/tmp/bounce-pr/evidence/explainer.html`. Side cards are positioned and connectors drawn by the script, from the elements' measured positions, so nothing needs hand-aligning: give each anchor row an `id`, list the ids a side card serves in `data-anchor`, and list the connectors in `WIRES`.

```html
<!doctype html><html><head><meta charset="utf-8"><style>
/* :root from granola-design.md */
* { box-sizing: border-box; margin: 0; }
body { background: var(--page); color: var(--ink); font: 14px/20px var(--body); }
#explainer { width: 1160px; padding: 40px 32px 32px; background: var(--page); }
h1 { font: 600 30px/36px var(--display); letter-spacing: -0.24px; }
header p { color: var(--muted); margin: 6px 0 28px; font-size: 15px; }
code { font-family: var(--mono); font-size: 12.5px; }
.map { position: relative; width: 1096px; }
.card { background: var(--surface); border: 1px solid var(--border); border-radius: 28px; box-shadow: var(--shadow); }
.side { position: absolute; width: 230px; padding: 16px 18px; display: flex; flex-direction: column; gap: 6px; border-radius: 22px; }
.side h2, .main > h2 { font: 600 20px/24px var(--display); display: flex; justify-content: space-between; align-items: center; gap: 8px; }
.side .line { font-size: 13px; color: var(--muted); }
.main { margin-left: 290px; width: 500px; padding: 18px 16px 16px; }
.main > h2 { padding: 0 6px 12px; }
.step { border: 1px solid var(--border); border-radius: 14px; background: var(--surface); padding: 10px 12px; }
.step + .step { margin-top: 8px; }
.step .top { display: flex; justify-content: space-between; align-items: center; gap: 8px; }
.step .top code { font-size: 13px; font-weight: 600; }
.step .desc { font-size: 13px; color: var(--muted); margin-top: 2px; }
.step.old .top code { color: var(--muted); font-weight: 500; }
.isnew { border: 1.5px solid var(--primary) !important; background: var(--accent-soft) !important; }
.changed { border: 1.5px dashed var(--primary) !important; }
.pill { font: 500 11.5px/16px var(--body); border-radius: 9999px; padding: 2px 10px; white-space: nowrap; }
.pill.new { background: var(--primary); color: var(--page); }
.pill.chg { border: 1px solid var(--primary); color: var(--primary); background: var(--surface); }
svg.wires { position: absolute; inset: 0; pointer-events: none; overflow: visible; }
.wire { fill: none; stroke: #CFCFC6; stroke-width: 1.5; } .wire.new { stroke: var(--primary); stroke-width: 2; }
.wlabel { font: 500 11.5px var(--body); fill: var(--muted); } .wlabel.new { fill: var(--primary); font-weight: 600; }
.foot { margin-top: 20px; font-size: 13px; color: var(--muted); }
</style></head><body><div id="explainer">
  <header><h1>Auto-tagging on upload</h1><p>One line on what happens, in plain words.</p></header>
  <div class="map" id="map">
    <div class="card side" id="svc-dashboard" data-anchor="a-route" data-side="left">
      <h2>Dashboard <span class="pill chg">Changed</span></h2><span class="line"><code>indexFile(…, { autoTag })</code></span>
    </div>
    <div class="card main" id="main">
      <h2>Retrieval Engine</h2>
      <div class="step isnew" id="a-route"><div class="top"><code>POST /api/v1/files/indexing</code><span class="pill new">New</span></div><div class="desc">What it does now</div></div>
      <div class="step old" id="a-pages"><div class="top"><code>index_pdf_pages()</code></div><div class="desc">Unchanged context</div></div>
    </div>
    <div class="card side" id="svc-weaviate" data-anchor="a-pages" data-side="right">
      <h2>Weaviate</h2><span class="line">Page index</span>
    </div>
    <svg class="wires" id="wires"></svg>
  </div>
  <p class="foot">Edge cases in one line.</p>
</div>
<script>
// from → to; `kind: "new"` draws it in olive.
const WIRES = [
  { from: "svc-dashboard", to: "a-route", label: "auto_tag", kind: "new" },
  { from: "a-pages", to: "svc-weaviate", label: "pages" },
];
function layout() {
  const map = document.getElementById("map"), base = map.getBoundingClientRect();
  const box = (id) => { const r = document.getElementById(id).getBoundingClientRect(); return { x: r.left - base.left, y: r.top - base.top, w: r.width, h: r.height, cy: r.top - base.top + r.height / 2 }; };
  const main = box("main"), bottoms = { left: 0, right: 0 };
  for (const card of document.querySelectorAll(".side")) {
    const side = card.dataset.side, centres = card.dataset.anchor.split(" ").map((id) => box(id).cy);
    const top = Math.min(...centres), bottom = Math.max(...centres);
    if (centres.length > 1) card.style.minHeight = bottom - top + 64 + "px";
    let y = centres.length > 1 ? top - 32 : top - card.offsetHeight / 2;
    y = Math.max(y, bottoms[side] ? bottoms[side] + 16 : 0);
    card.style.left = side === "left" ? "0px" : main.x + main.w + 76 + "px";
    card.style.top = y + "px";
    bottoms[side] = y + card.offsetHeight;
  }
  map.style.height = Math.max(main.y + main.h, bottoms.left, bottoms.right) + "px";
  let html = '<defs><marker id="m" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="7" markerHeight="7" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="#CFCFC6"/></marker><marker id="mn" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="7" markerHeight="7" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="#5B6F00"/></marker></defs>';
  for (const w of WIRES) {
    const a = box(w.from), b = box(w.to), right = b.x > a.x, cls = w.kind === "new" ? "new" : "";
    const y = w.from.startsWith("svc") ? b.cy : a.cy, x1 = right ? a.x + a.w : a.x, x2 = right ? b.x : b.x + b.w;
    const labelX = w.from.startsWith("svc") ? (x1 + main.x) / 2 : right ? (main.x + main.w + x2) / 2 : (x2 + main.x) / 2;
    html += `<path class="wire ${cls}" d="M${x1} ${y} H${x2}" marker-end="url(#${cls ? "mn" : "m"})"/><text class="wlabel ${cls}" x="${labelX}" y="${y - 7}" text-anchor="middle">${w.label}</text>`;
  }
  document.getElementById("wires").innerHTML = html;
}
document.fonts.ready.then(layout);
</script></body></html>
```

Rules that keep the connectors clean: each side card's anchors must be next to each other in the main card, or another side card ends up in the way; put the `id` on the box the line should start from, not on its text; one connector per call, so drop a read that would cross another card and mention it in the side card instead.

## Render

`run-code` has no `require` and playwright-cli won't open `file://`, so pass the HTML in with `setContent`. Render at 2× and capture only `#explainer`:

```bash
cd /tmp/bounce-pr/evidence
python3 -I -c 'import json; html = open("explainer.html").read(); open("shot.js", "w").write("""async page => {
  const context = await page.context().browser().newContext({ viewport: { width: 1240, height: 1400 }, deviceScaleFactor: 2 });
  const p = await context.newPage();
  await p.setContent(%s, { waitUntil: "networkidle" });
  await p.waitForFunction(() => document.getElementById("wires").innerHTML.length > 0);
  await p.locator("#explainer").screenshot({ path: "/tmp/bounce-pr/evidence/explainer.png" });
  await context.close();
  return "ok";
}""" % json.dumps(html))'
playwright-cli -s=explainer open about:blank
playwright-cli -s=explainer run-code --filename=/tmp/bounce-pr/evidence/shot.js
playwright-cli -s=explainer close
```

Look at the PNG (Read the image) before attaching: no clipped text, no label hidden under a card, every connector ending on a card. Attach it like any screenshot, directly under **What changed**, with alt text that says the flow in words: `![Alt text](/tmp/bounce-pr/evidence/explainer.png)` plus `--attach`. Keep the What changed bullets; they're the searchable version.
