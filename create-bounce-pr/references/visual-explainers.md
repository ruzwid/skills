# Visual explainers

An explainer is the fastest way for a reviewer to understand a PR. At a glance it shows what the PR does and how it's built. Looking closer, it shows enough of the implementation to judge it: whether the design is sound, where it could break, and what they'd push back on. It's for architecture, data flow and backend behaviour. Product screens belong in Evidence as screenshots; don't mock the UI.

GitHub can't render custom HTML in a PR body, so build the explainer as a static HTML page, render it to a PNG with playwright-cli, and attach it like a screenshot. Use Mermaid only for relationships too tangled for cards (a state machine with many transitions) or notation a reviewer expects.

## Decide what to draw

There's no required layout. Draw what this PR needs a reviewer to see, and let the change decide the shape. It should work at two depths:

- **At a glance:** the title, subtitle and the New and Changed parts say what the PR does and where it lives, in about five seconds.
- **On a closer look:** the decisions a reviewer would judge are visible, not buried in the diff: where the new logic sits and what it calls, what triggers it, what it reads and writes, the order of steps, what happens when something fails or is skipped, and limits such as timeouts, retries, caps and flags. If one of these is the risky part of the PR, make it prominent.

Leave out whatever doesn't help someone understand or judge the change.

Detail is a range, not a choice between templates:

- **Simple:** a handful of cards with a name and a one-line subtitle, stacked or side by side, with arrows between them, and maybe a short list inside one card. Good for "what are the pieces and how do they connect": a new service, a new layer, an overview a reviewer reads in five seconds. Code names are optional.
- **Detailed:** the changed service as a large card holding its route and call chain in order, nested cards for each step, the services it calls as side cards, and labelled connectors from the exact row that makes each call. Good when the reviewer needs to find every box in the diff: a backend flow across repos, or a change where order, skipping or failure handling is the point.
- **Anything between or beside those:** before and after side by side, a timeline, the data's shape at each step, a grid of who can do what. Invent the shape if none of these fit.

Before attaching, check the PNG against this: could someone who hasn't read the diff say what the PR does and how, and name the one thing they'd question? If not, change what's shown, not just how it looks.

If it isn't obvious which level helps, render two and let the user pick before attaching. If a picture needs more than about a dozen boxes, text below 13px or crossing connectors, cut unchanged context or split it into two images.

## What makes one readable

- **Title** names the feature; a one-line subtitle says what happens in plain words.
- **Real names** when you show code: routes (`POST /api/v1/files/indexing`), functions (`auto_tag_file()`), file paths (small and muted), constants and models. A reviewer should be able to find each box in the diff.
- **Nesting shows containment, arrows show calls or data.** Label a connector with what passes, in one or two words: `auto_tag`, `prompt`, `tags`, `status`.
- **Mark what changed** with the design system's New and Changed styles, keep unchanged context muted, and add a small legend when you use the badges. Show only enough unchanged context to place the change.
- **Edge cases in one line** in a footer, such as when a step is skipped, unless one is the risky part of the PR; then draw it. Numbers only if measured.

## Style

Use the tokens in `references/design-system.md` for colours, fonts, radii, borders and shadow. They set the look, not the layout.

## Building it

Write `/tmp/bounce-pr/evidence/explainer.html` with everything inside `<div id="explainer">`, sized to the content (about 600px wide for a simple stack, up to 1200px for a wide map). When the fonts have loaded and any layout script has run, set `document.body.dataset.ready = "1"`; the render step waits for it.

Two sketches from opposite ends of the range follow. They're examples, not templates: change the structure freely.

### Simple: stacked layers

Plain flexbox and arrow glyphs; no script beyond the ready flag.

```html
<!doctype html><html><head><meta charset="utf-8"><style>
/* the CSS block from design-system.md: @import first, then :root */
* { box-sizing: border-box; margin: 0; }
body { background: var(--page); color: var(--ink); font: 15px/22px var(--body); }
#explainer { width: 640px; padding: 36px 28px 28px; background: var(--page); }
h1 { font: 600 28px/34px var(--display); margin-bottom: 20px; }
.frame { border: 1px solid var(--border); border-radius: 28px; padding: 16px; display: flex; flex-direction: column; align-items: center; gap: 10px; }
.layer { width: 100%; background: var(--surface); border: 1px solid var(--border); border-radius: 16px; padding: 18px; text-align: center; }
.layer.filled { background: var(--fill); border-color: transparent; }
.layer h2 { font: 600 20px/26px var(--display); }
.layer p { color: var(--muted); }
.items { display: grid; grid-template-columns: 1fr 1fr; gap: 8px 24px; margin-top: 12px; }
.row { width: 100%; display: flex; gap: 10px; } .row .layer { flex: 1; }
.arrow { color: var(--line); font-size: 18px; line-height: 1; }
</style></head><body><div id="explainer">
  <h1>How uploads get tagged</h1>
  <div class="frame">
    <div class="layer filled"><h2>Dashboard</h2><p>Sources page · upload</p></div>
    <div class="arrow">↓</div>
    <div class="layer"><h2>Retrieval Engine</h2><p>FastAPI</p>
      <div class="items"><span>Index pages</span><span>Build catalog card</span><span>Pick tags</span><span>Save status</span></div>
    </div>
    <div class="arrow">↓</div>
    <div class="row"><div class="layer"><h2>Weaviate</h2></div><div class="layer"><h2>Gemini Flash</h2></div><div class="layer"><h2>Firestore</h2></div></div>
  </div>
</div><script>document.fonts.ready.then(() => { document.body.dataset.ready = "1"; });</script></body></html>
```

### Detailed: system map with drawn connectors

Use this script when connectors have to start from a particular row inside a card and end on another card. Side cards are positioned and connectors drawn from the elements' measured positions, so nothing needs hand-aligning: give each anchor row an `id`, list the ids a side card serves in `data-anchor`, and list the connectors in `WIRES`.

```html
<!doctype html><html><head><meta charset="utf-8"><style>
/* the CSS block from design-system.md: @import first, then :root */
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
.foot { margin-top: 20px; font-size: 13px; color: var(--muted); display: flex; justify-content: space-between; gap: 24px; }
.legend { display: flex; align-items: center; gap: 6px; white-space: nowrap; }
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
  <div class="foot"><span>Edge cases in one line.</span><span class="legend"><span class="pill new">New</span> added <span class="pill chg">Changed</span> behaviour changed</span></div>
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
    // A side card pushed below its row gets an elbow, so the line still ends on the card.
    const a = box(w.from), b = box(w.to), right = b.x > a.x, cls = w.kind === "new" ? "new" : "";
    const fromSide = w.from.startsWith("svc"), side = fromSide ? a : b, y = fromSide ? b.cy : a.cy;
    const ySide = Math.min(Math.max(y, side.y + 18), side.y + side.h - 18);
    const x1 = right ? a.x + a.w : a.x, x2 = right ? b.x : b.x + b.w, step = right ? 14 : -14;
    const xBend = fromSide ? x1 + step : x2 - step, [y1, y2] = fromSide ? [ySide, y] : [y, ySide];
    const d = y1 === y2 ? `M${x1} ${y1} H${x2}` : `M${x1} ${y1} H${xBend} V${y2} H${x2}`;
    const labelX = fromSide ? (xBend + x2) / 2 : (x1 + xBend) / 2;
    html += `<path class="wire ${cls}" d="${d}" marker-end="url(#${cls ? "mn" : "m"})"/><text class="wlabel ${cls}" x="${labelX}" y="${y - 7}" text-anchor="middle">${w.label}</text>`;
  }
  document.getElementById("wires").innerHTML = html;
  document.body.dataset.ready = "1";
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
  await p.waitForFunction(() => document.body.dataset.ready === "1");
  await p.locator("#explainer").screenshot({ path: "/tmp/bounce-pr/evidence/explainer.png" });
  await context.close();
  return "ok";
}""" % json.dumps(html))'
playwright-cli -s=explainer open about:blank
playwright-cli -s=explainer run-code --filename=/tmp/bounce-pr/evidence/shot.js
playwright-cli -s=explainer close
```

Look at the PNG (Read the image) before attaching: no clipped text, no label hidden under a card, every connector ending on a card. Attach it like any screenshot, directly under **What changed**, with alt text that says the flow in words: `![Alt text](/tmp/bounce-pr/evidence/explainer.png)` plus `--attach`. Keep the What changed bullets; they're the searchable version.
