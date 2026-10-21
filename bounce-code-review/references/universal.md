# Universal checks (every PR)

- **Intent match.** Does the diff do what the PR body and ticket say? Is anything in the diff unexplained: an unrelated refactor, a version bump, a flag flipped, a config default changed?
- **Missing pieces.** Does the ticket ask for something the diff doesn't do (a second screen, the API side, the migration of existing data)?
- **Error paths.** New branches that can throw have a handler, and failures are visible. A bare `catch {}`, or a caught error neither rethrown nor logged, is a finding.
- **Leftovers.** `console.log`, commented-out code, `TODO` with no ticket, `.only`/`.skip` in tests, hardcoded ids/URLs/env values, debug flags left on.
- **Tests.** If behaviour changed, does a test assert the *new* behaviour? A nit by default. Blocking when the change touches auth, tenancy, billing, data shape, or anything that can lose data.
- **Naming.** Does each name still describe what it does? A `get*` that gained a side effect is a real finding.
- **Conventions are discovered, not remembered.** Where a check depends on a helper, wrapper, error envelope or logging style, grep a known-good sibling in the same repo, cite it, and hold the PR to it. No citation, no finding.
- **Duplication of existing code.** A new helper that duplicates an existing one in the repo or in `api-core`/`dashboard-core`. Grep for it before flagging, and cite the existing one.
