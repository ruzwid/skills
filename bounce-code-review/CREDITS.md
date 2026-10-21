# Credits

- The finding criteria and comment-writing rules in `references/finding-bar.md` adapt OpenAI Codex's review rubric (`codex-rs/prompts/templates/review/rubric.md`).
- The 0–100 confidence rubric, the 80 threshold and the false-positive list adapt Anthropic's `code-review` plugin for Claude Code.
- Filtering after generation instead of prompting for fewer comments follows Greptile's "How to Make LLMs Shut Up".
- The spec/intent axis (checking the diff against the ticket, not only against standards) follows Matt Pocock's `code-review` skill.
- `references/frontend.md` draws on Vercel's `react-best-practices`, adjusted for React 16/17, and `react-doctor` is used as an optional candidate source.
