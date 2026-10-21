# 0006 — Compute and hosting model

| Field | Value |
|---|---|
| Status | Proposed (revision; merges original ADR-006 and ADR-007, both Accepted) |
| Date | 2026-10-18 |
| Deciders | Solution Architect, Key Developer *(one person, see README)* |
| Supersedes | ADR-006 Execution Platform Baseline, ADR-007 Runtime Hosting Model |
| Related | [0000](0000-cost-optimization-strategy.md), [0009](0009-event-driven-ingestion.md), [0013](0013-adapter-control-plane.md), [0015](0015-ui-and-real-time-push.md) |
| Traces to | NFR-COST-01, NFR-PERF-02 (tick-to-store latency), C4 L2 containers: Adapters, Ingestion, Admin/Query API |

## Context and Problem Statement

The original ADR-006 and ADR-007 both chose Azure Functions on the Consumption plan, deferred Container Apps and rejected VMs. Two facts change the decision:

- The platform targets **.NET 10**. Microsoft states that .NET 9 is the last .NET version supported on the **Linux Consumption** plan; newer versions will not be added.
- Hosting function apps on Linux in a Consumption plan **retires on 30 September 2028**; Microsoft recommends migrating to **Flex Consumption**.

.NET 10 is generally available for the Functions isolated worker model. Where do the adapters, the ingestion processor and the APIs run?

## Decision Drivers

- D1 — .NET 10, isolated worker model.
- D2 — Scale to zero; near-zero idle cost ([0000](0000-cost-optimization-strategy.md)).
- D3 — Native triggers: timer (adapters), Service Bus (ingestion), HTTP (APIs).
- D4 — Managed identity for every outbound connection ([0005](0005-identity-and-access.md)).
- D5 — No hosting plan that is already announced for retirement.

## Considered Options

1. Azure Functions on **Flex Consumption** (Linux), .NET 10 isolated
2. Azure Functions on Consumption (Windows), .NET 10 isolated
3. Azure Container Apps (consumption profile)
4. Azure VM + Docker (rejected in the original ADR on cost; not re-evaluated)

## Decision Outcome

**Chosen option:** Option 1, Flex Consumption.

### Workload placement

| Workload | Function app | Trigger | Notes |
|---|---|---|---|
| Market data adapters (one function per venue) | `func-signallog-adapters` | Timer (schedule per venue, trading hours only) | Disable/enable per function via app setting ([0013](0013-adapter-control-plane.md)) |
| Ingress (thin HTTP → Service Bus) | `func-signallog-ingress` | HTTP, called only by APIM | No business logic ([0010](0010-api-management-ingestion-gateway.md)) |
| Ingestion processor | `func-signallog-ingestion` | Service Bus topic subscription `persist` | Idempotent upsert ([0008](0008-data-storage.md)) |
| Live push broadcaster | `func-signallog-ingestion` | Service Bus topic subscription `live-push` | SignalR output binding ([0015](0015-ui-and-real-time-push.md)) |
| Admin/Query API (Minimal-API style HTTP functions) | `func-signallog-api` | HTTP | Behind Entra ID; consumed by the UI ([0015](0015-ui-and-real-time-push.md)) |

Separate function apps give separate managed identities and least-privilege role assignments ([0005](0005-identity-and-access.md)), and allow the adapters to be stopped without affecting ingestion.

### Consequences

- Good, because .NET 10 is supported and the plan is the one Microsoft is investing in.
- Good, because idle cost is near zero and scale-out is automatic.
- Bad, because cold starts add latency to the first execution after idle; acceptable because adapters are timer-driven and ingestion latency targets are in seconds, not milliseconds. Always-ready instances are not used (they incur cost).
- Bad, because "Minimal API" in the CV sense becomes HTTP-triggered functions; if a true ASP.NET Core Minimal API host is wanted, it can run on Container Apps later without changing the other workloads.

### Confirmation

- IaC deploys Flex Consumption with `FUNCTIONS_WORKER_RUNTIME=dotnet-isolated` and .NET 10.
- Verify .NET 10 availability for Flex Consumption in the target region before Accepting this ADR.

## Pros and Cons of the Options

### Flex Consumption
- Good, because it supports .NET 10, scale to zero, VNet integration and managed identity.
- Bad, because cold starts remain.

### Consumption (Windows)
- Good, because it is the classic, well-understood plan.
- Bad, because it offers no VNet integration and fewer future features.

### Container Apps
- Good, because it supports any ASP.NET Core host, KEDA scaling and a free monthly grant.
- Bad, because there is more to configure (images, registry, revisions) for workloads that fit Functions triggers natively.

## More Information

- Azure Functions runtime versions and .NET support: https://learn.microsoft.com/azure/azure-functions/functions-versions
