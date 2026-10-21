# Limits (Standard edition)

Check the official quotas page for current values; these change occasionally.

## Documents

| Limit | Value |
| --- | --- |
| Document size | 1 MiB (1,048,576 bytes) |
| Field value size | 1 MiB − 89 bytes |
| Document name (path) size | 6 KiB |
| Field name / field path size | 1,500 bytes |
| Map / array nesting depth | 20 levels |
| Subcollection depth | 100 levels |
| Indexed value size | 1,500 bytes (longer values are truncated in the index) |

## Indexes

| Limit | Value |
| --- | --- |
| Index entries per document | 40,000 |
| Composite indexes per database | 1,000 (with billing enabled) |
| Single-field configurations per database | 1,000 (with billing enabled) |
| Fields per composite index | 100 |
| Index entry size | 7.5 KiB |
| Total index entry size per document | 8 MiB |

## Queries

| Limit | Value |
| --- | --- |
| `in`, `not-in`, `array-contains-any` values | 30 |
| OR disjunctions (after normalisation) | 30 |
| Fields with range or inequality filters | 10 |
| Aggregation query deadline | 60 seconds |
| Security rules document accesses | 10 per single-document request or query, 20 per transaction or batch |

## Writes and transactions

| Limit | Value |
| --- | --- |
| API request size | 10 MiB |
| Transaction time limit | 270 seconds (60 seconds idle) |
| Field transforms per document per commit | 500 |
| Writes per commit | No fixed count since 2023; bounded by request size |
| New collection ramp-up | 500 ops/s, +50% every 5 minutes |

## Free tier (one database per project)

50,000 reads, 20,000 writes and 20,000 deletes per day; 1 GiB stored; 10 GiB egress per month. TTL deletes, PITR, backups and restores aren't covered.
