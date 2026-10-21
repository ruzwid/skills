# The bar for a finding

Most review noise comes from comments that are true but not worth fixing. Teams measuring AI reviewers found most comments were nits nobody acted on. What helped was filtering findings after generation, not prompting for fewer of them. So: generate candidates freely in Step 5, then filter hard here.

## A finding must meet all of these

1. It meaningfully affects correctness, security, data, performance or maintainability.
2. It's discrete and actionable: one defect, one fix. Not "the codebase could use more tests".
3. It was **introduced by this PR**. Pre-existing problems don't count (see the exception below).
4. The author would fix it if they knew. It doesn't demand rigour absent from the rest of the repo.
5. It doesn't depend on unstated assumptions about intent or inputs. State the inputs or scenario that trigger it.
6. If it claims another part of the code breaks, it names the provably affected code. Speculation that "this may break something" is not a finding.
7. It isn't clearly an intentional change described in the PR body or ticket.
8. It's anchored to `repo/path:line` in a tree you actually read.

## Refute before you keep

For each candidate, re-open the lines and look for the reason it's wrong:
- Already handled earlier in the function, by middleware, by the caller, or by a guard you didn't read.
- The "missing" field or index exists in another file of the same PR.
- The behaviour change is the point of the PR.
- In a TypeScript repo, the typechecker or CI would catch it.

## Confidence rubric

- **0**: Doesn't survive light scrutiny, or is pre-existing.
- **25**: Might be real, couldn't verify. Or stylistic and not in any documented convention.
- **50**: Verified real, but minor or rarely hit.
- **75**: Verified, very likely hit in practice, directly affects behaviour or breaks a cited convention.
- **100**: Certain. The evidence directly confirms it and it will happen often.

Keep 80+. A 50–79 finding is kept only as a **question** whose answer would settle it. Drop everything else.

## Severity: three levels only

- **blocking**: breaks production or a consumer, loses or corrupts data, opens an authz/tenancy/injection hole, contradicts the stated intent, or changes a cross-repo contract with no safe rollout order.
- **nit**: everything else worth saying. Author's discretion. Prefix with "Nit:" when posting.
- **question**: correctness depends on information only the author has. Ask it. Don't promote a guess to blocking, and don't drop the uncertainty.

## Do not flag

- Anything the formatter, linter or typechecker catches **in the TypeScript repos**. The JavaScript frontends have no typechecker, so name and shape mismatches there are real findings.
- Pre-existing issues the PR doesn't make worse. Exception: at most one adjacent, cheap nit, labelled "pre-existing".
- Code a parent PR in the stack introduced.
- Speculative refactors with no concrete defect ("could be a hook", "consider extracting").
- Blanket advice ("add tests", "validate input") that doesn't name the specific input and failure.
- Performance claims without a scale argument. "N is user-supplied and unbounded" is a finding; "this `.map` could be slow" is not.
- Restating what the diff does.
- APIs the repo's pinned major version doesn't support.
- Style preferences with no documented convention. To claim "doesn't match our patterns", cite the precedent you grepped.

## Writing each finding

- One short paragraph: what breaks, under which inputs or scenario, and why. Severity should match reality, never inflated.
- Matter-of-fact tone. No flattery, no "great job", no hedging filler.
- Code in the comment: 3 lines at most. Use a `suggestion` block only for a concrete replacement, preserving the exact indentation.
