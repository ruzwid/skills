# Writes and scale

## What a write is

One commit rewrites the document, deletes its old index entries and inserts new ones, then waits for a majority of replicas to agree. If those keys live on different splits, the commit is coordinated across them. More indexed fields and more documents per commit mean more latency.

## Hotspots

Firestore spreads load by splitting the key space into ranges. Writes concentrated in a narrow range queue on one split leader.

Causes:
- **Sequential document IDs** (`order_0001`, timestamps, incrementing numbers): every new document lands at the end of the key space.
- **Indexed monotonically increasing fields** (`createdAt` written at a high rate): the index entries pile up in one range even when the IDs are random. Exempt the field if you don't query it, or accept a lower write rate.
- **One hot document** updated by many writers: a shared counter, a "lastActivity" on a parent, a global config.
- **Sudden traffic** on a new or cold collection.

Fixes:
- Use auto-generated IDs. If you need a meaningful ID, make sure it isn't sequential, or prefix it with a hash or shard number.
- For bulk imports, shuffle the key order instead of writing in sorted order.
- Split hot documents (sharded counters, below).
- **Ramp traffic with 500/50/5**: start at no more than 500 operations per second on a new collection, then increase by 50% every 5 minutes. This lets splits divide ahead of the load. Load-test anything that launches big.

There is no fixed per-document write rate. It depends on contention, indexes and payload, so design for "a single document is not a queue" and load-test.

## Increments and field transforms

Use transforms instead of read-modify-write:

```ts
await ref.update({
  responseCount: FieldValue.increment(1),
  tags: FieldValue.arrayUnion("new"),
  updatedAt: FieldValue.serverTimestamp(),
});
```

These are atomic without a transaction. They still contend if many clients update the same document.

## Counters

Ways to keep a number, cheapest first:
1. **Read-time `count()`**: no write cost; 1 read per 1,000 entries. Good for thousands, occasional reads.
2. **One counter document + `increment()`**: 1 extra write per event, 1 read to display. Good until writers collide.
3. **Sharded counter**: N shard documents (`counters/{id}/shards/{0..N-1}`); each write increments a random shard, reads sum the shards (N reads, or a `sum()` aggregation). N shards handle about N times the write rate.
4. **Async trigger**: write events, and let a Cloud Function or scheduled job update the summary. Decouples the hot path; the number lags.

Live, hot, or over millions of rows → maintain it on write. Occasional and in the thousands → ask the index.

## Transactions and batched writes

- **Batched write** (`db.batch()`): atomic writes with no reads. Use it whenever you don't need to read first.
- **Transaction** (`db.runTransaction`): read, then write. All reads must come before any write.
- The function can run several times on contention. No side effects inside it: no emails, no external API calls, no mutating outer state. Return a value and act after it commits.
- Server SDKs take locks on what the transaction reads, so large reads inside a transaction block other writers and cause contention errors. Read only what decides the write.
- Mobile and web SDKs use optimistic concurrency and fail when offline.
- Limits: 10 MiB per request, 270 seconds per transaction, 60 seconds idle. The old 500-writes-per-commit cap was removed in 2023, but keep commits small anyway: fewer documents per commit means lower latency and less contention.
- For large jobs (migrations, backfills), use `BulkWriter` in the Admin SDK. It parallelises, retries, and ramps traffic for you. It isn't atomic across documents, so make each write idempotent.

## Cloud Functions triggers

- **At-least-once delivery.** A trigger can run twice for one event. Make it idempotent: use deterministic IDs for what it creates, `increment` only behind an "already processed" marker, or compare before and after.
- **No ordering guarantee** between events.
- **Loops.** An `onDocumentWritten` trigger that updates its own document fires again. Guard on whether the relevant fields actually changed.
- **Fan-out cost.** A trigger that updates 5,000 documents per event costs 5,000 writes per event. Count it before shipping.

## Deletes

- Deleting a document doesn't delete its subcollections. Use `db.recursiveDelete(ref)` (Admin SDK) or `firebase firestore:delete --recursive`. Each document deleted bills a delete.
- Mass deletes leave tombstones that slow queries scanning that range for a while. Don't re-query from the start of a range you just deleted; keep a cursor.
- **TTL policies** delete expired documents automatically, typically within 24 hours of expiry, billed as deletes. The TTL field must be a timestamp; exempt it from indexing.

## Migrations and backfills

- Add the field with a default for new writes first, then backfill old documents, and only then ship queries that filter on it.
- Run backfills with `BulkWriter`, a cursor, and a checkpoint so they can resume.
- Respect 500/50/5 on large backfills, and watch for contention on hot documents.
