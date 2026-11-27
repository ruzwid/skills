# Granola light

The look for explainer images: calm and editorial, thin borders, one olive accent used only to mark what's new.

```css
@import url('https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600&family=Zilla+Slab:wght@500;600&display=swap');
:root {
  --page: #FCFCF8;        /* warm off-white background */
  --surface: #FFFFFF;     /* cards */
  --ink: #292929;         /* text */
  --muted: color-mix(in oklch, #292929 60%, transparent);
  --border: #E3E3E3;
  --primary: #5B6F00;     /* olive, the only accent */
  --accent-soft: #F0F2E3; /* olive tint for new items */
  --shadow: 0 2px 6px 0 #47432A0D;
  --display: "Zilla Slab", Georgia, serif;
  --body: "Archivo", -apple-system, "Segoe UI", sans-serif;
  --mono: ui-monospace, "SF Mono", Menlo, monospace;
}
```

- **Type:** Zilla Slab for the title and card names (600); Archivo for everything else, 13–14px; code in the mono stack. Sentence case; hierarchy from size, not weight or capitals.
- **Shapes:** cards 22–28px radius, inner blocks 12–16px, badges are pills (9999px). Borders do the separating; the shadow is barely there.
- **Accent:** olive only, and only for new or changed things. No second bright colour, no gradients.
