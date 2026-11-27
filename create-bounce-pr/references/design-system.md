# Design system

Tokens for explainer images: colours, type, radii, borders and shadow. They set the look, not the layout. The feel is calm and editorial: warm off-white page, white cards, thin borders, and one olive accent used only to mark what's new or changed.

```css
@import url('https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600&family=Zilla+Slab:wght@500;600&display=swap');
:root {
  --page: #FCFCF8;        /* warm off-white background */
  --surface: #FFFFFF;     /* cards */
  --fill: #F3F3EF;        /* neutral tint for a card that should stand out without meaning "new" */
  --ink: #292929;         /* text */
  --muted: color-mix(in oklch, #292929 60%, transparent);
  --border: #E3E3E3;
  --line: #CFCFC6;        /* connectors and arrows that aren't new */
  --primary: #5B6F00;     /* olive, the only accent */
  --accent-soft: #F0F2E3; /* olive tint for new items */
  --shadow: 0 2px 6px 0 #47432A0D;
  --display: "Zilla Slab", Georgia, serif;
  --body: "Archivo", -apple-system, "Segoe UI", sans-serif;
  --mono: ui-monospace, "SF Mono", Menlo, monospace;
}
```

Copy the whole block to the top of the page's `<style>`. The `@import` must come first or the fonts won't load.

- **Type:** Zilla Slab (600) for the title and card names; Archivo for everything else, 13–15px; code in the mono stack. Sentence case. Hierarchy comes from size, not weight or capitals.
- **Shapes:** outer cards 22–28px radius, nested cards 12–16px, badges are pills (9999px). Borders do the separating; the shadow is barely there. Nest cards to show what lives inside what.
- **Colour:** olive only, and only for new or changed things: solid olive **New** pill, olive border and tint on new boxes and connectors, olive outline **Changed** pill (dashed border on the box). Unchanged things stay neutral with muted text. `--fill` can lift an ends-of-the-stack layer, like a frontend or a shared service, without implying change. No second bright colour, no gradients.
- **Space:** generous padding (16–24px in cards, 8–12px between siblings). Leave white space rather than shrinking text.
