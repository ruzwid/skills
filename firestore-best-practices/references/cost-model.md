# Cost model

Standard edition bills per document operation, not per byte. Writes cost about 3x reads per operation. Storage includes index entries, so every indexed field costs storage on every document.

## What counts as a read

| Operation | Billed |
| --- | --- |
| `get()` of a document | 1 read, even if the document doesn't exist |
| Query | 1 read per document returned; **at least 1 read even when empty** |
| Query using `offset(n)` | 1 read per skipped document + 1 per returned document |
| Query with range filters on more than one field | Documents returned + 1 read per 1,000 index entries scanned |
| `count()` / `sum()` / `average()` | 1 read per 1,000 index entries scanned (minimum 1) |
| Projection (`select()`) | Same as a full document read. Saves bandwidth and latency only |
| Listener, initial snapshot | 1 read per document in the result |
| Listener, afterwards | 1 read per document added, changed, or removed from the result because it changed. Deletions are free |
| Listener reconnect | Re-billed as a new query after 30 minutes offline, or on any reconnect when offline persistence is disabled |
| Security rules `get()`, `exists()`, `getAfter()` | 1 read per distinct document accessed, once per request |
| Reads served from the client cache | Free |

## What counts as a write or delete

- Each `set`, `update` or `create`: 1 write, regardless of how many index entries it changes. The index cost shows up as latency and storage, not as extra writes.
- Each document delete: 1 delete. Deleting a document does not delete its subcollections.
- Field transforms (`increment`, `arrayUnion`, `serverTimestamp`) inside a write don't add writes.
- TTL deletes are billed as deletes and are not covered by the free tier.

## Storage

Billed storage = document IDs + field names + values + metadata + **every single-field and composite index entry**. Long field names repeat in every document and every index entry. A document with 50 indexed scalar fields carries about 100 index entries.

## Bandwidth

Inbound is free, and so is traffic within the same region. Egress across regions or to the internet is billed. Projections reduce egress; they don't reduce reads. Requests denied by security rules don't count toward bandwidth.

## Billing traps

- **Fetch-then-count**: 100,000 documents to show "100,000 responses" costs 100,000 reads. `count()` costs about 100.
- **N+1 lookups**: a list of 100 items, each fetching its parent, is 200 reads and 101 round trips.
- **Offset pagination**: page 50 of 20 items bills 1,000 reads.
- **Polling instead of listening**: re-running a query every few seconds re-bills every result. A listener bills only changes.
- **Listener churn**: re-subscribing on every render or route change re-bills the initial snapshot each time.
- **Empty polling**: checking for new work every second costs at least 86,400 reads per day per poller, even with nothing found.
- **Rules lookups**: a rule that calls `get()` on a profile document adds a read to every request it guards.
- **Unused indexes**: large text, maps and arrays indexed by default inflate storage on every document.
- **Analytics on Firestore**: cross-tabs, exports and dashboards that read every document are the most expensive use of the database. See `denormalisation.md`.

## Measuring

- **Query Explain** (`query.explain({ analyze: true })` in the server SDKs) shows the index used, index entries scanned, documents returned and billed reads. Use it before shipping a new heavy query.
- Usage and Key Visualizer in the Google Cloud console show read/write volume and hot key ranges.
- The emulator doesn't model billing or index requirements accurately. Validate cost and indexes against a real project.

## Standard vs Enterprise edition

| | Standard | Enterprise |
| --- | --- | --- |
| Indexes | Automatic single-field indexes; composites required for complex queries | Optional; you define them; unindexed queries scan |
| Billing | Per document (reads, writes, deletes) | Read units per 4 KiB processed; write units per 1 KiB, **plus a write unit per index entry** |
| Queries | Core queries, listeners, offline | Adds Pipelines and MongoDB compatibility |

On Enterprise, document size and index count directly change the price of each operation, so small documents and few indexes matter even more, and projections may reduce cost. Check the Enterprise pricing page before applying Standard advice.
