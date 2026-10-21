---
name: firestore-best-practices
description: Cloud Firestore data modeling, indexing, query, cost and scaling guidance for writing and reviewing code that uses Firestore through the Firebase client SDKs, the Admin SDK or Google Cloud client libraries. Use when designing collections or document shapes, choosing between embedding, subcollections and root collections, writing or reviewing queries, counts, pagination, listeners, transactions, batch jobs, counters, Cloud Functions triggers or composite indexes, deciding what to index or exempt, or investigating a high Firestore bill, slow queries, contention errors or hotspots.
metadata:
  version: "1.0.0"
  last-verified: "2026-10-21"
---

# Firestore Best Practices

Firestore bills per document read, written and deleted, plus storage that includes every index entry. Almost every decision is a trade between those four. Design from the reads the app makes, not from how the data is related.

Facts were last checked against the official docs on the `last-verified` date above. If that is more than six months ago, confirm limits and billing rules in the Firestore docs before quoting exact numbers.

This guide targets **Standard edition** (the default, and what Firebase projects use). Enterprise edition has optional indexes, Pipelines and size-based billing; see `references/cost-model.md` before applying cost advice to it.

## Mental model

- The database is one sorted key-value table. A document's key is its full path; a subcollection is not "inside" its parent, it just shares a key prefix.
- The table is cut into contiguous key ranges (splits). Each split is synchronously replicated; a write commits when a majority of replicas agree.
- Every indexed field adds index entries: keys with no payload, sorted in the same kind of table. A write updates the document and all its index entries in one commit.
- Every query is a contiguous scan of one index, or a merge of several. Cost and latency scale with **results returned**, not with collection size.

## Hard rules

1. **Count with an aggregation, never by fetching.** `count()`, `sum()` and `average()` bill 1 read per 1,000 index entries scanned; fetching bills 1 read per document. If the number is read constantly or over millions of rows, maintain it at write time instead.
2. **Paginate with cursors, never `offset`.** Skipped documents are billed as reads.
3. **Write every field you filter on, with a default.** A missing field has no index entry, so `==`, `!=`, `not-in`, ranges and `orderBy` all silently skip that document. Use `null` or `false`, not absence, and backfill before relying on a new filter.
4. **Use auto-generated document IDs** for anything written at volume. Sequential or timestamp-prefixed IDs send every write to the last split. Store human-readable names as fields.
5. **Keep documents in the tens of KB.** 1 MiB is the hard limit. Anything that grows per user or per event (responses, messages, logs) goes in a subcollection or root collection, not an array or map.
6. **Don't update one document from many writers at once.** Use `FieldValue.increment`, sharded counters, or a trigger that aggregates asynchronously.
7. **Exempt fields you never filter or sort on** (large strings, blobs of settings, device info, big maps and arrays, high-rate timestamps). Every indexed field adds write latency and storage, and can hit the 40,000 index entries per document limit.
8. **Composite index order: equalities first, then range fields (most selective first), then sort.** One index serves any query that matches a prefix of its fields.
9. **Make queries match security rules.** Rules are not filters: a query that *could* return a forbidden document fails entirely.
10. **Make triggers idempotent and loop-safe.** Cloud Functions triggers are at-least-once, and a trigger that writes to the document it listens on retriggers itself.

## If… then…

| If you need to… | Do this | Details |
| --- | --- | --- |
| Show a number of documents | `count()` aggregation; write-time counter if it's hot or huge | `references/reads.md` |
| Show a list with related data (e.g. titles) | Denormalise a snapshot of the field onto the item, or batch-get parents | `references/denormalisation.md` |
| Store data that's always read together and bounded | Embed it in one document | `references/data-modeling.md` |
| Store data that grows without bound | Subcollection (default when in doubt) | `references/data-modeling.md` |
| Query across every parent's children | Collection group query + collection-group-scope index, or a root collection with a parent id field | `references/data-modeling.md` |
| Filter on two equality fields | No composite needed (index merge); add a composite if it's slow | `references/indexing.md` |
| Filter with a range and sort by another field | Composite index covering both; expect the range field to act as a sort key too | `references/indexing.md` |
| Fetch only some fields | `select()` projection (less egress and latency, same read cost) | `references/reads.md` |
| Increment a counter | `FieldValue.increment()`; shard it if writes are concurrent | `references/writes-and-scale.md` |
| Bulk import or migrate | `BulkWriter` (Admin SDK), random-ish key order, ramp up with 500/50/5 | `references/writes-and-scale.md` |
| Show live data | Keep one long-lived listener on a narrow query | `references/reads.md` |
| Search free text | Not supported natively in Standard; use an external search index | `references/reads.md` |
| Run analytics, exports, cross-tabs | Export or stream to BigQuery or a warehouse, not Firestore queries | `references/denormalisation.md` |
| Delete a document with subcollections | Delete the subcollections too (`recursiveDelete`); they are not removed automatically | `references/writes-and-scale.md` |

## Reviewing Firestore code

Check, in order:
1. **Reads in loops.** A `get()` per item in a list (N+1). Batch with `getAll` or `in` on `documentId()` (30 per query), or denormalise.
2. **Fetch-then-count, fetch-then-filter, fetch-then-sort.** Push them to the query or an aggregation.
3. **`offset()` pagination, or unbounded queries without `limit()`.**
4. **Unbounded growth** inside a document: arrays or maps keyed by user, response, or event.
5. **Filters on fields that may be missing** from older documents.
6. **Hot documents or hot key ranges**: shared counters, "last updated" fields written by every request, sequential IDs, indexed timestamps at high write rates.
7. **Listeners** that are re-created per render or per navigation, or that listen to a whole collection.
8. **Transactions** that read large result sets, have side effects, or wrap writes that need no reads (use a batch).
9. **New query shapes** without the matching composite index in `firestore.indexes.json`.
10. **Triggers** that aren't idempotent, or that write back to their own source document without a guard.

## References

Read only what the task needs.

| File | Impact | Covers |
| --- | --- | --- |
| `references/cost-model.md` | CRITICAL | What is billed and when, billing traps, Standard vs Enterprise |
| `references/data-modeling.md` | CRITICAL | Embed vs subcollection vs root collection, document size, query-first design, collection IDs |
| `references/reads.md` | HIGH | Aggregations, projections, pagination, listeners, N+1, query semantics and gotchas |
| `references/indexing.md` | HIGH | Automatic indexes, composite order, index merging, multiple ranges, exemptions |
| `references/writes-and-scale.md` | HIGH | Hotspots, IDs, 500/50/5, contention, transactions, batches, counters, triggers, deletes, TTL |
| `references/denormalisation.md` | MEDIUM | Copies, snapshot vs live, fan-out, when to move workloads out of Firestore |
| `references/limits.md` | REFERENCE | Hard limits and quotas in one table |
