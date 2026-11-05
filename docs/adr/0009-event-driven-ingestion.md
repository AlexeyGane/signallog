# 0009 — Event-driven ingestion via Azure Service Bus

| Field | Value |
|---|---|
| Status | Proposed |
| Date | 2026-10-18 |
| Deciders | Solution Architect, Key Developer *(one person, see README)* |
| Related | [0000](0000-cost-optimization-strategy.md), [0008](0008-data-storage.md), [0010](0010-api-management-ingestion-gateway.md), [0012](0012-message-contract-and-versioning.md), [0013](0013-adapter-control-plane.md) |
| Traces to | NFR-REL-01 (no tick loss), NFR-DATA-01 (idempotent processing), C4 L2: Messaging |

## Context and Problem Statement

Adapters produce price ticks independently and at different rates. Persistence, live UI push and (later) alerting all consume the same ticks. The producers must not depend on consumer availability, and a failing consumer must not lose data. How are ticks transported from producers to consumers?

## Decision Drivers

- D1 — Decouple producers from consumers; tolerate consumer downtime.
- D2 — Fan-out to multiple independent consumers.
- D3 — Explicit delivery semantics and poison-message handling.
- D4 — Managed, low-cost, managed-identity capable ([0000](0000-cost-optimization-strategy.md), [0005](0005-identity-and-access.md)).

## Considered Options

1. Azure Service Bus Standard: topics and subscriptions
2. Azure Service Bus Basic: one queue
3. Azure Event Grid (namespace topics)
4. Azure Event Hubs
5. Direct writes from adapters to the database (no broker)

## Decision Outcome

**Chosen option:** Option 1.

### Topology

| Entity | Type | Producer | Consumers (subscriptions) |
|---|---|---|---|
| `price-ticks` | topic | Ingress function behind API Management ([0010](0010-api-management-ingestion-gateway.md)) | `persist` → ingestion function; `live-push` → SignalR broadcaster ([0015](0015-ui-and-real-time-push.md)); `alerts` (reserved) |
| `market-status` | topic | Ingress function, routed by CloudEvents `type` ([0019](0019-market-status-events.md)) | `persist` → ingestion function; `live-push` → SignalR broadcaster |
| `adapter-heartbeats` | topic | adapters | `status` → admin API ([0013](0013-adapter-control-plane.md)) |
| `adapter-commands` | topic | admin API | one subscription per adapter, filtered on `adapterId` ([0013](0013-adapter-control-plane.md)) |

### Delivery semantics

- **At-least-once.** Consumers are idempotent ([idempotent receiver](../standards/concepts-and-sources.md#eip)): the `eventId` is the Cosmos DB document id ([0008](0008-data-storage.md)).
- **Duplicate detection** on `price-ticks` and `market-status` with `MessageId = eventId` and a 10-minute window, which removes most producer-side retry duplicates before they reach consumers.
- **Ordering is not relied upon.** `latest-prices` is updated only when the incoming `eventTimeUtc` is newer. Sessions are therefore not used, which keeps consumers simple and parallel.
- **Dead-lettering** after the maximum delivery count; a DLQ message raises an alert ([0007](0007-observability.md)) and is reprocessed by a runbook after the cause is fixed.

### Consequences

- Good, because a new consumer is a new subscription, with no change to producers.
- Good, because producers keep working while the database or a consumer is down; messages wait in subscriptions.
- Bad, because Standard tier carries a fixed base charge (≈ USD 10/month), accounted for in [0000](0000-cost-optimization-strategy.md).
- Bad, because at-least-once forces every consumer to be idempotent; this is a deliberate design constraint, tested explicitly.

### Confirmation

- Integration test: the same message delivered twice results in one stored tick.
- Chaos test: ingestion function stopped for 30 minutes, restarted, no ticks lost.

## Pros and Cons of the Options

### Service Bus Standard topics
- Good, because it offers pub/sub, duplicate detection, DLQ, filters and managed identity.
- Bad, because of the fixed monthly base charge.

### Service Bus Basic queue
- Good, because it costs very little.
- Bad, because it has no topics: every new consumer requires producer changes or a forwarding function.

### Event Grid
- Good, because it is push-based and cheap per event.
- Bad, because it has no duplicate detection and no transactions ([comparison](https://learn.microsoft.com/azure/service-bus-messaging/compare-messaging-services)), so every duplicate reaches consumers. *Corrected 2026-11-04: the earlier text said Event Grid offers only notifications, not a durable queue per consumer. Namespace topics do offer pull delivery with queue semantics: receive, acknowledge, release, reject, lock renewal, maximum delivery count and dead-lettering ([pull delivery](https://learn.microsoft.com/azure/event-grid/pull-delivery-overview)). The decision is unchanged, because duplicate detection is part of the delivery semantics above.*

### Event Hubs
- Good, because it is built for high-throughput streams with replay.
- Bad, because it is oversized for a few ticks per second, with partition and checkpoint management overhead.

### Direct database writes
- Good, because it is the simplest path.
- Bad, because it couples producers to database availability and offers no fan-out.

## More Information

Sources (checked 2026-11-04):

- Service Bus tiers: Basic supports queues only; Standard adds topics, subscriptions, sessions, transactions and duplicate detection: https://learn.microsoft.com/azure/service-bus-messaging/service-bus-premium-messaging#choosing-a-tier
- Duplicate detection on `MessageId` within a configured window (not available on Basic): https://learn.microsoft.com/azure/service-bus-messaging/duplicate-detection
- Dead-letter queues and maximum delivery count: https://learn.microsoft.com/azure/service-bus-messaging/service-bus-dead-letter-queues
- Choose between Event Grid, Event Hubs and Service Bus: https://learn.microsoft.com/azure/service-bus-messaging/compare-messaging-services
- Event Grid namespace topics, pull delivery: https://learn.microsoft.com/azure/event-grid/pull-delivery-overview
