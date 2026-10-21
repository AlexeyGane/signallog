# 0000 — Cost optimization strategy and budget envelope

| Field | Value |
|---|---|
| Status | Proposed (revision of original ADR-000, Accepted) |
| Date | 2026-10-18 |
| Deciders | Solution Architect, Key Developer *(one person, see README)* |
| Supersedes | ADR-000 (original one-line version) |
| Related | [0006](0006-compute-hosting.md), [0007](0007-observability.md), [0008](0008-data-storage.md), [0009](0009-event-driven-ingestion.md) |
| Traces to | NFR-COST-01 (monthly run cost), Azure Boards Epic "Platform Foundation" |

## Context and Problem Statement

SignalLog is a self-funded portfolio project. It must look and behave like an enterprise system while costing no more than a streaming subscription. The original ADR-000 set a guardrail of ≤ USD 10/month for normal operation and ≤ USD 25/month during demo phases, but did not break the figure down by component. When the target architecture was costed, a single Azure Service Bus Standard namespace (≈ USD 0.0135/hour, ≈ USD 10/month) consumed the entire normal-operation envelope on its own. A budget that the architecture cannot meet is not a guardrail; it is a contradiction that every later ADR silently violates.

This ADR therefore answers: **what is the monthly budget, how is it allocated across components, and how is it enforced?**

## Decision Drivers

- D1 — Total cost must stay affordable for a private individual over 12+ months.
- D2 — The budget must be compatible with the architecture (event-driven, topics, gateway, managed identity).
- D3 — Free tiers and free offers are preferred where they do not compromise the architecture story.
- D4 — Cost must be observable and alerting must fire before the guardrail is breached.

## Considered Options

1. **Keep ≤ USD 10/month**, downgrade messaging to Service Bus Basic (queues only, no topics).
2. **Raise the guardrail to ≤ USD 20/month normal / ≤ USD 30/month demo**, keep Service Bus Standard (topics).
3. **No fixed guardrail**, review cost ad hoc.

## Decision Outcome

**Chosen option:** Option 2, because topics with subscriptions are central to the event-driven design ([0009](0009-event-driven-ingestion.md)) and the incremental ≈ USD 10/month buys a materially better architecture, while still meeting D1.

### Budget envelope (normal operation)

Figures are planning estimates based on public pricing at the time of writing and **must be re-checked against the Azure pricing calculator before this ADR is Accepted**.

| Component | ADR | Tier / offer | Planned monthly cost (USD) |
|---|---|---|---|
| Azure Service Bus | 0009 | Standard (base charge, 13M operations included) | ≈ 10 |
| Azure API Management | 0010 | Consumption (pay per call) | ≈ 0–1 at demo traffic |
| Azure Functions | 0006 | Flex Consumption (on-demand) | ≈ 0–2 |
| Azure Cosmos DB for NoSQL | 0008 | Free tier (1000 RU/s, 25 GB, provisioned throughput) | 0 |
| Storage account | 0006 | Standard LRS (Functions host storage, exports) | ≈ 1 |
| Application Insights / Log Analytics | 0007 | Pay-as-you-go with daily cap | ≈ 0–2 |
| Key Vault | 0005 | Standard (operations only) | < 1 |
| Azure SignalR Service | 0015 | Free tier | 0 |
| Azure App Configuration | 0013 | Free tier | 0 |
| Static Web Apps (UI) | 0015 | Free plan | 0 |
| GitHub, Azure Boards | 0002, 0003 | Free plans | 0 |
| **Total (planned)** | | | **≈ 12–17** |
| **Guardrail** | | | **≤ 20 (normal), ≤ 30 (demo)** |

### Enforcement

- Azure Cost Management budget on the subscription at USD 20 with alerts at 50%, 80% and 100% of the budget, plus a forecast alert at 100%.
- Separate budget alert for the demo period at USD 30, enabled only for the demo window.
- Application Insights daily cap set so that observability cannot exceed its line ([0007](0007-observability.md)).
- Cosmos DB database-level throughput fixed at 1000 RU/s (the free-tier allowance); autoscale above it is disallowed by IaC ([0008](0008-data-storage.md)).
- Every ADR that adds a paid resource must add a row to the table above in the same pull request.

### Consequences

- Good, because the budget now matches the architecture and every later ADR can be checked against a concrete line item.
- Good, because cost becomes a reviewable artefact (a table in a PR), which is itself an enterprise practice worth demonstrating.
- Bad, because normal-operation cost doubles compared with the original target.
- Risk: free offers change without notice (mitigation: monthly cost review; the budget alert catches drift).

### Confirmation

- Budget and alerts exist in Azure Cost Management and are defined in IaC ([0016](0016-environments-and-infrastructure-as-code.md)).
- Monthly cost review recorded as an Azure Boards task with the actual-versus-planned table.

## Pros and Cons of the Options

### Option 1 — ≤ USD 10, Service Bus Basic
- Good, because it preserves the original target.
- Bad, because Basic has queues only: no topics, no fan-out to independent subscribers (persistence, alerting, analytics).
- Bad, because the "event-driven" claim weakens to point-to-point queuing.

### Option 2 — ≤ USD 20 / 30, Service Bus Standard
- Good, because it supports topics, subscriptions, duplicate detection and sessions.
- Bad, because it costs ≈ USD 10/month more.

### Option 3 — no guardrail
- Good, because it is simple.
- Bad, because cost drift goes unnoticed; contradicts D4.

## More Information

- Azure Service Bus pricing: https://azure.microsoft.com/pricing/details/service-bus/
- Azure Cosmos DB free tier: https://learn.microsoft.com/azure/cosmos-db/free-tier
- Review triggers: guardrail breached two months in a row; a free offer is withdrawn; a new paid component is proposed.
