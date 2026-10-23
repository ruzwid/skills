# Shared contracts and group-level checks

## ts-types, api-core, dashboard-core

Consumed across stacks, so this is the one change that can break three services at once.

**"Types only, no runtime change" is not a safety argument, and the reason depends on the consumer:**
- **TypeScript consumers** (the backends) fail at build: loud, caught in CI, cheap.
- **JavaScript consumers** (dashboard, web-surveys, admin-v2, dashboard-core, app) have no typechecker. They import shared enums and constants **at runtime**, so a rename doesn't break their build. It ships and throws in the browser. Only a grep finds it.

| Change | Verdict |
|---|---|
| Add an optional field | Safe |
| Add a required field | Breaking for every producer of that type |
| Optional → required | Breaking |
| Required → optional | Breaking for readers that don't null-check |
| Widen a union / add an enum member | Breaking for exhaustive switches with a `never` default |
| Narrow a union / remove a member | Breaking for producers of the removed member |
| Change a field's type | Breaking |
| Rename anything exported | Breaking, always |

Union widening is the row that gets missed. Grep for `switch` statements on that type across all consumers.

**Renames** in one PR are blocking unless staged: add the new name, keep the old one `@deprecated`, migrate consumers, remove it in a follow-up once the sweep is clean. Say which step is missing.

**Pinning.** For each consumer PR in the group, read its pin for the shared package (`repos.md` explains the two styles). If a consumer imports a symbol that only exists on the shared-package branch, the group can't merge until the package is published and the pin or tarball bumped. Blocking until the author states the order.

**api-core carries behaviour, not just shapes.** A changed default, threshold, timeout or rounding rule silently affects every stack. List every caller rather than reasoning from the one the author had in mind. A function that gains a side effect with the same signature is invisible to the typechecker. A reordered parameter list with the same arity is breaking. Error messages are part of the contract when callers branch on them.

**dashboard-core** is the frontend version of the same problem: a shared React package with two JavaScript consumers and no typechecker, so a renamed export or changed prop contract breaks at runtime.

## Group-level checks

Only possible with the whole group in view, and where the expensive bugs live.

1. **Deploy skew outside the group.** The CircleCI release orchestrator deploys a ticket group's PRs in order, so don't write a merge order for the group. Flag what it can't order: a dependency on something outside the group (another ticket's PR, a Terraform or IAM change, a data backfill, an env var) that must land first. A change that is only safe if everything deploys at the same instant is **blocking**.
2. **Contract symmetry.** List every field or endpoint the backend PR adds, renames or removes, and confirm each appears in the frontend PR and in ts-types:
   `respondentQuota → api ✅  ts-types ✅  dashboard ❌ (still reads quotaMax)`
3. **Stack order.** Stacked PRs merge after their parents. Report it only when a stack crosses ticket groups (see Cross-group stack chains in `output.md`).
4. **Deduplicate.** One root cause across three PRs is one finding with three locations.
