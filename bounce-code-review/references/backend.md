# Backend checks

TypeScript on Express, Firestore for persistence, Redis for caching. Ordered by the cost of the bug: a missed index is a slow page, a missed tenant predicate is a breach.

## Authorization and tenancy

Work out the repo's auth model **before** reviewing its routes: read the router registration and the middleware it mounts. The backends differ: some are tenant-scoped, some are respondent-facing and token-scoped, some are internal-staff only. Demanding a tenant predicate where there is no tenancy is noise; missing one where there is tenancy is a breach.

- Find the tenancy key by grepping a known-good handler and copying its predicate. Cite it. If the repo clearly scopes queries by tenant and you can't find the key, that is a **question**, never a pass.
- A handler that loads a resource by id and only checks that the caller is logged in, with no tenant predicate. **Blocking.**
- Scope taken from the request (body, query, params) instead of the session or token. **Blocking.**
- Auth middleware assumed rather than verified: confirm the new route is registered behind it.
- Mass assignment: spreading a request body into an update, so a caller can set role, tenant or admin flags. **Blocking.**
- A list endpoint whose tenant filter only applies when an optional param is present.
- **A cache key without the tenant in it**: tenant B gets tenant A's cached response. **Blocking.**
- Respondent-facing unauthenticated routes: rate limited, token scoped to one survey, no internal fields in the response.
- A webhook or callback that doesn't verify its signature, or compares it with a non-constant-time check. **Blocking**: it's an unauthenticated write.

## Untrusted input

- File uploads without type and size limits. For formats that expand when parsed (workbooks, zips), also bound the parsed size, and check the parser's version against known advisories.
- A user-supplied filename reaching a filesystem path or `Content-Disposition` without stripping separators.
- Spreadsheet/CSV export values starting with `=`, `+`, `-` or `@` (formula injection into whoever opens the file).
- CORS or cookie changes (`SameSite`, `Secure`, allowed origins) hidden in an unrelated diff.

## Validation and integrity

- A validation schema defined but never applied: grep for its call site.
- Validation that bypasses the repo's existing validation middleware (cite it).
- Unbounded numeric params; `parseInt` without NaN handling; dates without a timezone.
- Validation failures returning 500 or a raw exception instead of a 4xx in the same envelope as sibling handlers.
- No idempotency on anything a client, webhook or job runner can retry.

## Firestore

No SQL, ORM or migrations exist in the org. Don't review for unique constraints, index DDL, `NOT NULL` defaults or down migrations.

**Conventions**: find the repo's existing read/write/transaction helpers and hold the PR to them. A raw collection call where a wrapper exists is a finding (cite the wrapper).

**Platform limits** (from Firestore's docs, invisible from our code):
- A new compound `where`/`orderBy` needs a composite index in `firestore.indexes.json`, or it fails at **runtime** with `FAILED_PRECONDITION`. Check that the file changed too.
- Batched writes cap at **500** operations. A loop adding to one batch over an unbounded set breaks past that.
- Documents cap at **1 MiB**. Arrays or maps that grow per respondent or per event will reach it.
- `in`, `not-in` and `array-contains-any` take at most **30** values. A user-supplied list needs chunking.
- **No offset pagination worth using**: skipped documents are billed as reads. Use cursors (`startAfter`).
- **No unique constraints**: uniqueness comes from a deterministic document id with `create()`, or a transaction, never a read-then-write check (it races).
- Counters use `FieldValue.increment`; a JS read-modify-write loses concurrent updates.
- **Collection-group queries span all parents**, and so all tenants, unless the tenant predicate is re-applied.
- A filter on a field older documents don't have silently skips them (no index entry). New fields need a default and a backfill before anyone filters on them.
- Unbounded collection reads with no `.limit()` are a billing problem as much as a latency one. Export paths are the usual offenders.

**Also:**
- **N+1**: an `await` on a `get()` inside a loop or `.map`. Worse here than in SQL because there are no joins. The fix is `getAll()`, a chunked `in` on `documentId()`, or denormalising.
- Writes that must be atomic but aren't in a transaction or batch. Conversely, a transaction wrapping an outbound HTTP call holds it open across the network and can retry the side effect.
- Cloud Functions triggers that aren't idempotent (they're at-least-once), or that write back to their own source document without a guard (infinite retrigger).

If the `firestore-best-practices` skill is installed, apply its "Reviewing Firestore code" list too.

## Domain logic

- A new query that doesn't filter soft-deleted documents, so deleted records come back. Or a hard delete where the rest of the code soft-deletes.
- A status field updated without checking the transition is legal (reopening a closed survey, completing a cancelled response).
- A bulk endpoint with unstated partial-failure behaviour: does one bad row fail the batch or get skipped silently?
- Date boundaries computed in server-local time when survey, client and respondent are in different zones.

## Async and external calls

- A promise neither awaited nor caught. **Blocking** if it's the only path that saves data.
- `Promise.all` over an unbounded set with no concurrency limit.
- Outbound calls with no timeout; retries with no backoff; retries on non-idempotent operations.
- Jobs: partial failure leaving inconsistent state, no dead-letter path, no recorded progress so a retry redoes everything.
- Long synchronous work in a request handler: large sync JSON, sync fs, sync crypto.
- Check the repo's TS target and Node version before suggesting newer built-ins.

## Data handling

- Respondent PII or answer content in logs. **Blocking**: this is a market-research platform and it's a data-handling commitment.
- Tokens, keys, auth headers or full request bodies logged.
- Internal error details returned to the client.
- A new failure path with no log at all.
- A new env var used without validation at boot, so misconfiguration fails on the first request instead of at startup.
- Caching with no invalidation or TTL; buffering a whole upload or export where streaming is possible.
