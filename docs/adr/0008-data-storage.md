# 0008 — Operational data store

| Field | Value |
|---|---|
| Status | Proposed (revision of original ADR-009, Accepted) |
| Date | 2026-10-18 |
| Deciders | Solution Architect, Key Developer *(one person, see README)* |
| Supersedes | ADR-009 Data Storage Platform Selection (decision kept, rationale and data model corrected) |
| Related | [0000](0000-cost-optimization-strategy.md), [0006](0006-compute-hosting.md), [0009](0009-event-driven-ingestion.md), [0014](0014-instrument-domain-model.md), [0015](0015-ui-and-real-time-push.md) |
| Traces to | NFR-COST-01, NFR-DATA-01 (idempotent writes), NFR-DATA-02 (history retention), C4 L2 container: Operational Store |

## Context and Problem Statement

The ingestion processor writes price ticks continuously during trading hours; the UI reads the latest price per instrument and short history ranges. The original ADR-009 selected Azure Cosmos DB for NoSQL on the free tier. That choice holds, but two parts of the original reasoning were wrong and are corrected here:

1. **Rejection rationale for Azure SQL.** The original rated Azure SQL "cost efficiency: low". In fact Azure SQL has a free offer (100,000 vCore-seconds of serverless compute, 32 GB storage per database, up to 10 databases per subscription, renewing monthly). The real reason it does not fit is the *shape* of that allowance: 100,000 vCore-seconds is about 27.8 vCore-hours per month. A database that receives writes every few seconds never auto-pauses, so the monthly allowance would be consumed within days and the database would then pause until the next month (or start billing). Cosmos DB's free tier is a standing throughput allowance (1000 RU/s and 25 GB, indefinitely) that fits continuous ingestion.
2. **Partition key.** `/commodityCode` has only a handful of values (oil, gas, LNG). Cosmos DB stops accepting writes to a logical partition once it reaches 20 GB, and with low-cardinality keys all writes land on one physical partition. Tick history for one commodity grows without bound, so the key would eventually fail.

## Decision Drivers

- D1 — Continuous writes at zero cost ([0000](0000-cost-optimization-strategy.md)).
- D2 — Idempotent writes: at-least-once delivery from Service Bus must not create duplicates ([0009](0009-event-driven-ingestion.md)).
- D3 — Cheap "latest price per instrument" reads for the UI.
- D4 — Unbounded history without hitting the 20 GB logical-partition limit.
- D5 — Managed identity access, no keys ([0005](0005-identity-and-access.md)).

## Considered Options

1. Azure Cosmos DB for NoSQL, free tier, provisioned throughput
2. Azure SQL Database, serverless free offer
3. Azure Table Storage
4. Azure VM + SQL Server Developer (rejected in the original on cost and operational overhead; not re-evaluated)

## Decision Outcome

**Chosen option:** Option 1, Cosmos DB free tier, with the corrected data model below.

### Weighted evaluation

| Criterion (weight) | Cosmos DB free tier | Azure SQL free offer | Table Storage |
|---|---|---|---|
| Zero cost under continuous writes (35%) | 5 | 1 | 4 |
| Query flexibility for UI and history (25%) | 4 | 5 | 2 |
| Idempotent upsert and change feed (20%) | 5 | 4 | 3 |
| Enterprise and portfolio value (20%) | 5 | 5 | 2 |
| **Weighted score** | **4.75** | **3.4** | **2.9** |

### Data model

**Account:** free tier enabled, provisioned throughput, **database-level shared throughput of 1000 RU/s** (the free allowance). Autoscale above the allowance is disabled in IaC. Only one free-tier account is allowed per subscription, so dev and prod share the account with separate databases, or dev uses the Cosmos DB emulator ([0016](0016-environments-and-infrastructure-as-code.md)).

| Container | Partition key | Document id | Purpose |
|---|---|---|---|
| `price-ticks` | `/pk` = `{instrumentId}\|{yyyy-MM}` (synthetic) | `eventId` from the message ([0012](0012-message-contract-and-versioning.md)) | Append-only tick history; TTL 90 days |
| `latest-prices` | `/instrumentId` | `instrumentId` | One document per instrument, upserted on every tick; the UI reads only this container for live views |
| `instruments` | `/venueCode` | `instrumentId` | Reference data ([0014](0014-instrument-domain-model.md)) |
| `adapter-status` | `/adapterId` | `adapterId` | Last heartbeat and state ([0013](0013-adapter-control-plane.md)) |

- **Why the synthetic key:** `instrumentId` has tens to hundreds of values (contracts per venue), and the month bucket caps each logical partition at one month of one contract, far below 20 GB. A history query for one contract and a date range touches one or two partitions.
- **Idempotency:** the document id is the message's `eventId`; redelivered messages produce the same id, so `CreateItem` conflicts (409) are treated as success, and `latest-prices` is updated only if the incoming `eventTimeUtc` is newer (optimistic concurrency with ETag).
- **History beyond 90 days:** daily OHLC bars are computed from the change feed into a `daily-bars` container (no TTL). Raw ticks older than 90 days are not kept.

### Consequences

- Good, because continuous ingestion costs nothing and throughput is predictable.
- Good, because the data model is explicitly designed against the platform's limits.
- Bad, because 1000 RU/s is shared across all containers; a burst (e.g. backfill) must be throttled. 429 responses are retried by the SDK; the ingestion function's concurrency is capped.
- Bad, because ad-hoc relational queries are harder than in SQL; accepted, since query patterns are known and narrow.

### Confirmation

- Load test: sustained tick rate at expected peak × 3 stays below 1000 RU/s.
- Metric alert on 429 rate and on normalized RU consumption > 80%.

## Pros and Cons of the Options

### Cosmos DB free tier
- Good, because it offers standing free throughput, idempotent upserts, change feed and managed identity.
- Bad, because of the single free account per subscription and the shared RU budget.

### Azure SQL free offer
- Good, because of full SQL, EF Core and familiar tooling.
- Bad, because the monthly vCore-seconds allowance does not survive a continuously active database.

### Table Storage
- Good, because it is extremely cheap.
- Bad, because of weak query model, no change feed and low portfolio value.

## More Information

- Cosmos DB free tier: https://learn.microsoft.com/azure/cosmos-db/free-tier
- Hierarchical partition keys and the 20 GB logical partition limit: https://learn.microsoft.com/azure/cosmos-db/hierarchical-partition-keys
- Azure SQL free offer: https://learn.microsoft.com/azure/azure-sql/database/free-offer
- Alternative considered for `price-ticks`: hierarchical partition key `[/instrumentId, /month]`. Kept as an option if cross-month queries per instrument become frequent.
