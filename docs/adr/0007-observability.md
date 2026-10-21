# 0007 — Observability platform

| Field | Value |
|---|---|
| Status | Proposed (expands original ADR-008, Accepted) |
| Date | 2026-10-18 |
| Deciders | Solution Architect, Key Developer *(one person, see README)* |
| Supersedes | ADR-008 (original one-line version) |
| Related | [0000](0000-cost-optimization-strategy.md), [0006](0006-compute-hosting.md), [0009](0009-event-driven-ingestion.md), [0013](0013-adapter-control-plane.md) |
| Traces to | NFR-OPS-01 (end-to-end tracing), NFR-OPS-02 (data freshness alerting), NFR-COST-01 |

## Context and Problem Statement

A price tick crosses six hops: adapter → API Management → ingress function → Service Bus → ingestion function → Cosmos DB → UI. Diagnosing a missing or late price requires one trace across all hops, metrics on freshness, and alerts. The original ADR-008 chose Serilog + OpenTelemetry + Application Insights + Azure Monitor and referred cost governance to an ADR-012 that does not exist; cost controls are therefore defined here.

## Decision Drivers

- D1 — One distributed trace per tick across all hops.
- D2 — Vendor-neutral instrumentation (OpenTelemetry).
- D3 — Business-level signals: data staleness per instrument, adapter health.
- D4 — Observability cost capped within [0000](0000-cost-optimization-strategy.md).

## Considered Options

1. OpenTelemetry (`Microsoft.Extensions.Logging` + OTel SDK) exporting to Application Insights via the Azure Monitor exporter
2. Serilog + OpenTelemetry + Application Insights (original ADR-008)
3. Application Insights SDK only (classic)

## Decision Outcome

**Chosen option:** Option 1. Logging goes through the standard `ILogger` abstraction; OpenTelemetry collects logs, traces and metrics. Serilog is not required: in a Functions isolated host it adds a second logging pipeline to configure, and its main benefits (structured logging, enrichment) are covered by `ILogger` message templates and OTel resource attributes. This is a deliberate change from the original ADR and can be reversed if a Serilog-specific sink is needed.

### Signals

| Signal | Source | Use |
|---|---|---|
| Distributed trace | W3C `traceparent` propagated from the adapter, through APIM and the ingress function, into Service Bus application properties, and picked up by the ingestion function | End-to-end view of one tick |
| `signallog.tick.age_seconds` (histogram) | Ingestion: `now − eventTimeUtc` | NFR latency target |
| `signallog.instrument.staleness_seconds` (gauge) | Admin API from heartbeats ([0013](0013-adapter-control-plane.md)) | Freshness alert during trading hours |
| Adapter heartbeat | `adapter-heartbeats` topic | Adapter liveness vs. data flowing |
| Dead-letter count | Service Bus metrics | Poison-message alert |

### Alerts (Azure Monitor)

- Staleness > threshold for any instrument during its trading session ([0017](0017-time-and-timezones.md)).
- Dead-letter message count > 0.
- Function failure rate > 5% over 15 minutes.
- Budget alerts are owned by [0000](0000-cost-optimization-strategy.md).

### Cost controls

- Workspace-based Application Insights with a **daily cap**.
- Sampling for successful request traces; exceptions and dead-letter events never sampled.
- 30-day retention (default) for the portfolio environment.

### Consequences

- Good, because a single trace view across all hops is a strong, demonstrable capability.
- Good, because instrumentation is portable to any OTel backend.
- Bad, because propagating trace context through Service Bus requires explicit handling in adapter and ingestion code; covered by an integration test.

### Confirmation

- Integration test asserts that the ingestion span has the adapter span as an ancestor.
- Runbook "Missing prices" starts from the staleness alert and the end-to-end trace.

## Pros and Cons of the Options

### OTel + ILogger
- Good, because it is a single pipeline and standard abstractions.
- Bad, because fewer ready-made sinks than Serilog.

### Serilog + OTel
- Good, because Serilog is familiar and has rich sinks.
- Bad, because two pipelines must be configured and kept consistent.

### Classic Application Insights SDK
- Good, because it is the simplest to start.
- Bad, because it is not vendor-neutral and Microsoft's direction is OpenTelemetry.
