Run my daily Bounce PR review, then teach me one thing.

## 1. Review

Use the `bounce-code-review` skill with no arguments. If it can't be invoked as a skill, read `~/.claude/skills/bounce-code-review/SKILL.md` and follow it exactly, reading its `references/` and running its `scripts/` from that folder.

Do not post anything to GitHub. The report is for me; I'll ask for comments to be posted afterwards.

## 2. Today's learning

After the report, add a `## Today's learning` section with at least one lesson I can carry into my own work.

- **Topic**: pick it from today's reviews: a finding, a pattern done well, or a concept a PR depends on (frontend, backend, system design, architecture, databases, code design, or general engineering). With no PRs today, pick something from the Bounce stack (React 16/17, Express, Firestore, Redis, shared packages).
- **No repeats**: read `~/review/.code-review/learnings.md` first and choose a topic not already there. Then append `- <date> — <topic>` to it.
- **Explain it simply**, in under 250 words:
  1. The idea in one plain sentence.
  2. Why it matters, using the concrete code from today's PR (`repo/path:line`) when there is one.
  3. An everyday analogy.
  4. A one-line rule of thumb worth remembering.
  5. One quick question to test myself, with the answer hidden in a `<details>` block.
- **Make it visual**: build an animated diagram that shows the idea step by step (data flowing, a race happening, an index being scanned). Use the `archify` skill if it's available, otherwise the `artifact-design` skill. Publish it as an Artifact if the Artifact tool is available. Otherwise save it to `~/review/.code-review/learnings/<date>-<slug>.html`. Link it at the end of the section.
