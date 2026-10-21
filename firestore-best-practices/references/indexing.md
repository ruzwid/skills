# Indexing (Standard edition)

Every query is served by an index. Without the right index the query fails, with a console link to create it. It never falls back to a scan.

## Automatic single-field indexes

By default, for every field in every document of a collection:
- Scalars: an ascending and a descending entry.
- Arrays: ascending, descending and an `array-contains` entry per element.
- Maps: entries for every nested field, at every level.

That's at least two index entries per field per document, all written in the same commit as the document. They make simple queries work out of the box, and they are the main reason writes are slower than reads and storage is larger than the data.

Collection-group scope indexes are **not** automatic. A collection group query filtering on a field needs a collection-group-scope single-field index (an exemption that enables it) or a composite.

## Exemptions

Exempt fields you never filter or sort on. An exemption only disables automatic indexing; a composite index can still include the field.

Good candidates:
- Large strings: descriptions, notes, HTML, JSON blobs.
- Large or deep maps: settings, device info, metadata, raw payloads.
- Large arrays, especially of maps.
- Timestamps or other monotonically increasing values written at a high rate (the index becomes a hotspot near 500 writes per second).
- TTL fields.

For collections that are mostly read whole, exempt broadly and enable only what's queried. Exemptions are set in `firestore.indexes.json` (`fieldOverrides`) or the console, and need index-admin permissions on the project.

Limits: 40,000 index entries per document, 1,000 composite indexes and 1,000 single-field configurations per database.

## Equality-only queries: index merging

`where("status", "==", "open").where("ownerId", "==", uid)` needs no composite. Firestore merges the single-field indexes, stepping a cursor through each and leapfrogging to the next shared key (a zigzag merge join).

This is fast when the combined result is dense. It degrades when one filter matches very little and another matches a lot, because the cursors thrash. If such a query is slow or times out, add a composite index over the equality fields.

## Composite indexes

Needed when a query combines a range or `!=` filter with filters or sorts on other fields, or sorts by more than one field.

**Field order: equalities → range fields (most selective first) → sort fields.**

The index narrows on the equality fields and **the first range or sort field only**. Range filters on later fields are evaluated against each scanned entry and discarded if they fail, so they cost index-entry reads (1 per 1,000) and latency.

Example:

```ts
db.collection("responses")
  .where("surveyId", "==", id)
  .where("gender", "==", "female")
  .where("createdAt", ">=", start)
  .orderBy("createdAt", "desc");
// Index: surveyId ASC, gender ASC, createdAt DESC
```

- One composite serves every query whose equality filters match a prefix of it. Put the filter used by most queries first and reuse the index.
- Don't create one composite per screen. Each index adds a write and storage on every document in the collection.
- Direction matters for sort fields: an index on `createdAt DESC` serves `orderBy("createdAt", "desc")`.

## Multiple range fields

Queries can have range or `!=` filters on up to 10 fields. Only the first is narrowed by the index; the rest are post-filtered. Order them by selectivity (most selective first), and control which one leads with `orderBy`.

To avoid post-filtering, turn a range into an equality at write time by bucketing: store `ageBand: "18-24"` or `createdMonth: "2026-10"` and filter with `==`.

## Indexes in code

- Keep `firestore.indexes.json` in the repo and deploy it (`firebase deploy --only firestore:indexes`). Don't hand-create indexes in the console without exporting them.
- Add the index in the same change as the query. Index builds on large collections take minutes to hours, so deploy indexes before the code that needs them.
- The emulator doesn't require composite indexes, so a missing index shows up only against a real project. Test new query shapes there, or check the index file in review.
- Remove indexes no query uses. They cost on every write.
