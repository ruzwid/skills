# Data modeling

## Start from the queries

Write down the screens and jobs first, then the reads each one makes: which documents, filtered by what, sorted by what, how often, and whether it's live. Pick the layout that makes the most frequent reads cheap. A schema designed from "how the data relates" and queried later usually ends in fetch-everything-and-filter code.

For each read, answer:
1. Is it a point lookup (known path) or a query?
2. How many documents does it return, now and at 10x scale?
3. Is it live (listener) or one-off?
4. Which fields does it filter and sort on? Those need to exist on every document and be indexed.
5. Is it per parent, or across all parents?

## A document is the unit of everything

A read returns the whole document. A write rewrites the whole document and its index entries. A listener receives the whole document on every change. Size the boundary around what's read, written and watched together.

## Three layouts

Example: a survey with questions and responses.

| | A. Embed | B. Subcollections | C. Root collections |
| --- | --- | --- | --- |
| Shape | `surveys/{id}` with `questions[]` and `responses[]` | `surveys/{id}/questions/{q}`, `surveys/{id}/responses/{r}` | `surveys/{id}`, `questions/{q}`, `responses/{r}` each with `surveyId` |
| Read one survey with everything | 1 read | 1 + N reads | 1 + N reads |
| Growth | Hits 1 MiB (near 10,000 small responses); every write rewrites the whole thing | Unbounded | Unbounded |
| Concurrent writers | All contend on one document | Spread across documents | Spread across documents |
| Listener cost | Every change re-sends the whole document | Per changed document | Per changed document |
| Query across all surveys | Not possible | Collection group query + index | Plain query |
| Security rules | One rule for everything | Natural per-parent rules | Must check `surveyId` ownership |

**Rule of thumb:**
- Read together, bounded, small, rarely changed by multiple writers → **embed**.
- Grows without bound, or written concurrently → **subcollection**.
- Shared by several parents, or queried mostly across parents → **root collection**.
- In doubt → **subcollection**. It's easy to query per parent, and collection group queries reach across parents.

Embedding is fine for small fixed lists (a survey's 20 questions). It is wrong for anything that grows per user or per event.

## Document size

- Hard limit 1 MiB. Aim for tens of KB.
- One read costs the same at 1 KB and 900 KB, but latency, egress, client memory and listener payload all scale with size.
- 20 surveys at 400 KB each is 8 MB down the wire for a list screen that needs titles. Keep list-screen fields in a small document, or project with `select()` on the server.
- Keep fields under a few hundred per document. Very wide documents slow writes and listeners.

## Subcollections and collection groups

- A subcollection is a key prefix, not a container. Reading the parent doesn't read the children, and deleting the parent doesn't delete them. Orphaned subcollections keep costing storage and still show up in collection group queries.
- A collection group query (`collectionGroup('responses')`) searches every collection with that ID at any depth. Its single-field indexes are **not** created automatically. Add collection-group-scope index exemptions or composites for the fields you filter on.
- **Collection IDs are global names.** Two different shapes both called `responses` (e.g. raw and cleaned) will be mixed together by a collection group query, with no way to tell them apart. Use distinct IDs for distinct shapes; share an ID only when you want them queried together.

## IDs and keys

- Use auto-generated IDs for anything written at volume. Sequential IDs (`r1`, `r2`, timestamps) concentrate writes on one split. See `writes-and-scale.md`.
- IDs sort lexicographically: `r10` sorts before `r2`. Don't rely on ID order for anything meaningful; store a sortable field.
- Deterministic IDs are fine, and useful, for idempotency (`{userId}_{surveyId}` for "one response per user per survey"), as long as they aren't sequential.
- Avoid `/` in IDs, and avoid `.` and `..` as IDs. Avoid `.`, `[`, `]`, `*` and backtick in field names; they need escaping in field paths.
- Don't put personal or secret data in document IDs or field names. They appear in logs, URLs and index entries.

## Field conventions

- Every field you filter or sort on must be present on every document, with a default (`null`, `false`, `0`, `[]`). Missing fields have no index entry. See `reads.md`.
- Store one type per field. Types sort in a fixed order (null < booleans < numbers < timestamps < strings < bytes < references < geopoints < arrays < vectors < maps). A range on numbers never returns the string `"25"`.
- Use timestamps, not date strings, for time.
- Keep field names short but readable. They are stored in every document and index entry.
- Use maps for small fixed groups of fields. Use subcollections, not maps keyed by ID, for collections of things.
