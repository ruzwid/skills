# Denormalisation and workload placement

## Why copy data

Firestore has no joins. A list of 100 responses that shows each survey's title reads 100 responses plus up to 100 surveys. Copying `surveyTitle` onto each response makes it 100 reads. The cost moves to writes: renaming the survey means updating every response that carries the copy.

Reads usually outnumber writes by a wide margin, so copying frequently displayed, rarely changed fields is usually worth it.

## Snapshot or live

Decide for each copied field:

| | Snapshot | Live copy |
| --- | --- | --- |
| Meaning | The value at the time of the write (e.g. price at checkout, title when submitted) | Must always match the source |
| On source change | Nothing | Update every copy |
| Mechanism | Write it once | A trigger or job that fans out the update |
| Cost | Free after the first write | 1 write per copy per change |

Name the field so readers know which it is (`titleAtSubmit` vs `surveyTitle`), and document who owns the fan-out.

Keep live copies few and small. If a field changes often and has many copies, don't copy it. Batch-get the source instead.

## Fan-out

- Do it in a trigger or a job, not in the request that changed the source.
- Page through the copies with a cursor and write with `BulkWriter`.
- Copies are stale until the fan-out finishes. Make sure the UI tolerates that.
- Count the cost: 5,000 copies × 10 renames a day = 50,000 writes a day.

## Summary documents

For dashboards and list tiles, keep a small summary document per parent (`surveys/{id}/stats/summary` or fields on the parent) with counts and the few fields the tile shows, maintained on write. A tile then costs 1 read instead of a count plus a query.

## When Firestore is the wrong tool

Firestore is built for operational reads: known paths, narrow indexed queries, live updates. It's a poor and expensive fit for:
- Analytics, cross-tabs, pivots, weighting, group-by.
- Exports that read whole collections repeatedly.
- Reporting across many parents.
- Full-text search.

Move those workloads out:
- Stream or export to BigQuery (the "Stream Firestore to BigQuery" extension, or scheduled managed exports) or another warehouse, and query there.
- Build a derived, versioned table per entity when data is final (e.g. one row per respondent when a survey closes), and have dashboards and exports read it.
- Keep a dedicated search index in sync with triggers.

Firestore stays the system of record and the live layer; analysis reads from the derived store.
