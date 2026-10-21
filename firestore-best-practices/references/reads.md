# Reads

## Count with aggregations

Aggregations read index entries, never documents: 1 read per 1,000 index entries.

**Incorrect (bills one read per document):**

```ts
const snap = await db.collection("responses").where("surveyId", "==", id).get();
const total = snap.size;
```

**Correct:**

```ts
// Admin SDK
const agg = await db.collection("responses").where("surveyId", "==", id).count().get();
const total = agg.data().count;

// Web modular SDK
const agg = await getCountFromServer(query(collection(db, "responses"), where("surveyId", "==", id)));
```

`sum()` and `average()` work the same way (`aggregate({ total: AggregateField.sum("amount") })` / `getAggregateFromServer`). They ignore non-numeric values.

Limits:
- 60 second deadline. Around ten million index entries a query will time out.
- No listeners and no offline support. A live count needs a maintained counter.
- Still linear in the entries scanned: cheap per entry, not free.

**Use a write-time counter instead when** the number is shown on a hot screen, must be live, or covers millions of rows. Keep it in a summary document updated with `FieldValue.increment()`, sharded if written concurrently, or maintained by a trigger. See `writes-and-scale.md`.

## Projections

`select("title", "status")` returns only those fields.
- Same read cost per document (Standard edition).
- Less egress, less latency, less memory. Worth it for list screens over large documents.
- Server SDKs and REST only. The web and mobile SDKs always fetch whole documents, so on clients, keep list fields in small documents instead.

## Pagination

Use cursors. `offset` bills every skipped document.

**Incorrect:**

```ts
db.collection("responses").orderBy("createdAt", "desc").offset(page * 20).limit(20);
```

**Correct:**

```ts
let q = db.collection("responses").orderBy("createdAt", "desc").limit(20);
if (lastDoc) q = q.startAfter(lastDoc);
```

- Always `limit()` queries that can grow.
- Order by a field that is unique, or add a tie-breaker (`orderBy("createdAt").orderBy(FieldPath.documentId())`), so cursors don't skip or repeat documents with equal values.

## N+1 reads

A `get()` per item in a list costs a read and a round trip each.
- Batch-fetch known IDs: `db.getAll(...refs)` (Admin SDK), or `where(documentId(), "in", ids)` in chunks of 30.
- Run independent reads in parallel (`Promise.all`), never in a sequential `await` loop.
- If the same parent field is shown on every list item, denormalise it (`denormalisation.md`).

## Listeners

- Billed for documents returned and changed, not for the open connection. A long-lived listener is cheaper than polling.
- Listen to the narrowest query that serves the screen, with a `limit()`. Never listen to a whole large collection.
- Create a listener once per screen and unsubscribe on unmount. Re-subscribing on every render re-bills the initial snapshot.
- High-churn collections with many listeners cost reads on every change for every listener. A dashboard of 50 viewers on a collection changing 10 times a second is 500 reads a second.
- Embedded data makes every change re-send the whole document to every listener.
- After 30 minutes disconnected, the reconnect re-bills the full result.

## Query semantics that cause silent bugs

- **Missing fields are invisible.** A document without the field has no index entry, so it's excluded by `==`, `!=`, `not-in`, ranges, and **any `orderBy` on that field**. `where("archived", "!=", true)` misses every document that never had `archived`. Write defaults on create, and backfill before shipping a query on a new field.
- **`!=` and `not-in` also exclude `null`**, and match across types (`!= 1` returns strings).
- **Ranges stop at a type boundary.** `where("age", ">", 18)` never returns `age: "25"`.
- **`in`, `not-in` and `array-contains-any` accept 30 values.** OR queries are limited to 30 disjunctions after normalisation, so `in` combined with OR can exceed it quickly.
- **`array-contains` matches whole elements**: it can't match a field inside an array of maps. Keep a separate array of the values you need to query.
- **Strings sort by UTF-8 bytes**: uppercase before lowercase, no locale ordering, no case-insensitive matching. Store a normalised copy (e.g. lowercase) if you need it.
- **Only the first 1,500 bytes of a value are indexed**, so equality and ordering on very long strings are unreliable.

## Security rules are not filters

Rules check whether a query *could* return a forbidden document, not what it actually returns. If the rule is `resource.data.ownerId == request.auth.uid`, the query must include `where("ownerId", "==", uid)`, or it fails entirely even when every stored document would pass.
- Rule `get()`/`exists()` calls bill reads. Up to 10 per single-document request or query, 20 per transaction or batched write.
- Server SDKs (Admin) bypass rules. Authorisation there is your code's job.

## Things Firestore can't do natively

- **Joins.** Denormalise or batch-get.
- **Full-text search, prefix-in-the-middle, fuzzy matching.** Prefix search is possible with a range (`>= term`, `< term + ""`) on a normalised field. Anything more needs an external search index (Algolia, Typesense, Elasticsearch, Meilisearch) kept in sync by triggers.
- **Group by, pivots, weighted aggregates, cross-tabs.** Move these to an analytical store (`denormalisation.md`).
