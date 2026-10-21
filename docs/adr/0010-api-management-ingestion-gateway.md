# 0010 — API Management in the ingestion path

| Field | Value |
|---|---|
| Status | Proposed |
| Date | 2026-10-18 (revised same day after tier verification) |
| Deciders | Solution Architect, Key Developer *(one person, see README)* |
| Related | [0000](0000-cost-optimization-strategy.md), [0005](0005-identity-and-access.md), [0006](0006-compute-hosting.md), [0009](0009-event-driven-ingestion.md), [0012](0012-message-contract-and-versioning.md) |
| Traces to | NFR-SEC-01, NFR-SEC-04 (input validation at the boundary), C4 L2: Ingestion Gateway, Ingress Function |

## Context and Problem Statement

All workloads run inside Azure and authenticate with managed identities, so adapters *could* publish directly to Service Bus with the `Data Sender` role. A gateway adds a hop, latency and cost. Does the ingestion path need API Management, which tier, and how does the gateway hand messages to Service Bus?

The first draft of this ADR chose the built-in `send-service-bus-message` policy on the Consumption tier. Verification against Microsoft documentation showed that combination does not exist (see *Policy availability* below).

## Decision Drivers

- D1 — A single, governed entry point for all producers, including future external ones.
- D2 — Contract validation at the boundary, so malformed ticks never reach the broker.
- D3 — Contract versioning independent of the broker topology ([0012](0012-message-contract-and-versioning.md)).
- D4 — Secretless end to end ([0005](0005-identity-and-access.md)).
- D5 — Cost within [0000](0000-cost-optimization-strategy.md): no fixed monthly gateway charge.

## Policy availability (verified 2026-10-18)

| Policy | Consumption | Classic (Developer/Basic/Standard/Premium) | v2 (Basic v2/Standard v2/Premium v2) |
|---|---|---|---|
| `send-service-bus-message` | ❌ | ✅ (preview integration) | ❌ |
| `validate-azure-ad-token` | ✅ | ✅ | ✅ |
| `validate-content` | ✅ (max body 4 MB) | ✅ | ✅ |
| `authentication-managed-identity` | ✅ | ✅ | ✅ |
| `rate-limit-by-key` | ❌ | ✅ | ✅ |
| `rate-limit` (per subscription key) | ✅ | ✅ | ✅ |

Notes:

- `send-service-bus-message` is documented for the **classic gateway only** (Developer, Basic, Standard, Premium) and not for Consumption, v2 or workspaces. The how-to page marks the Service Bus integration as preview; the policy reference page does not. Treated as preview.
- Microsoft does not document **regional** restrictions for individual policies; availability is defined per tier/gateway. Regional limits apply to tiers: v2 tiers are available in a subset of regions (in Europe, some regions such as UK South, North Europe and Germany West Central show temporary capacity warnings for some tiers). The Consumption tier's regions are not listed on the v2 availability page; confirm in the portal when creating the instance in the chosen region.
- The policy's `message-id` attribute must be a valid **GUID**. This drives the identifier choice in [0012](0012-message-contract-and-versioning.md).

## Considered Options

1. APIM classic tier (Developer or Basic) → Service Bus via `send-service-bus-message`
2. **APIM Consumption → thin ingress function → Service Bus**
3. APIM Basic v2 → thin ingress function → Service Bus
4. No gateway: adapters publish directly to Service Bus

## Decision Outcome

**Chosen option:** Option 2.

```text
Adapter ──(MI token, app role Prices.Publish)──► APIM Consumption
   validate-azure-ad-token · validate-content · /v1/ticks routing
   authentication-managed-identity (token for the ingress function)
                                        ──► func-signallog-ingress (HTTP)
                                              ──(MI, Data Sender)──► Service Bus topic price-ticks
```

### Gateway responsibilities (APIM Consumption)

| Concern | Policy |
|---|---|
| Authentication of producers | `validate-azure-ad-token`: audience = Ingestion API app ID, required role `Prices.Publish` |
| Contract validation | `validate-content` with the JSON schema of the active version, `max-size` 64 KB |
| Versioning | URL segment (`/v1/ticks`); each version maps to a schema and a backend route |
| Call to backend | `authentication-managed-identity` obtains a token for the ingress function's app registration; `traceparent` forwarded |
| Throttling | Not enforced per caller in the gateway: `rate-limit-by-key` is unavailable on Consumption and `rate-limit` requires subscription keys (a shared secret, rejected by [0005](0005-identity-and-access.md)). Producers are internal and trusted; back-pressure comes from the ingress function's concurrency limit and Service Bus. Revisit if an external producer is added (move to Basic v2 or issue subscription keys for that producer only). |

### Ingress function ("thin")

- One HTTP-triggered function in `func-signallog-ingress` ([0006](0006-compute-hosting.md)): reads the body, sets `MessageId = id`, copies `traceparent`, sends to `price-ticks`, returns `202 Accepted`. No business logic, no database access.
- Protected by built-in App Service authentication (Entra ID): only tokens issued to APIM's managed identity are accepted. Consumption-tier APIM has no static outbound IP, so IP restrictions are not used.

### Consequences

- Good, because there is no fixed gateway charge; Consumption includes the first 1 million operations per month ([0000](0000-cost-optimization-strategy.md)).
- Good, because every component is GA and secretless.
- Good, because the boundary still validates identity and contract before anything reaches the broker.
- Bad, because one more deployable and one more cold start on the path.
- Bad, because there is no per-producer throttling at the gateway (accepted, see above).

### Confirmation

- Contract test: an invalid payload is rejected with HTTP 400 and never appears in Service Bus.
- A call without the `Prices.Publish` role is rejected with 401/403.
- A direct call to the ingress function without APIM's token is rejected with 401.

## Pros and Cons of the Options

### Classic tier + `send-service-bus-message`
- Good, because there is no custom code between gateway and broker.
- Bad, because classic tiers carry a fixed monthly charge far above the [0000](0000-cost-optimization-strategy.md) envelope (Developer has no SLA and is not meant for production), and the integration is preview.

### Consumption + thin function
- Good, because it is pay-per-call, GA, and secretless.
- Bad, because of the extra hop and no per-caller rate limiting.

### Basic v2 + thin function
- Good, because `rate-limit-by-key` and more features are available.
- Bad, because of the fixed monthly charge, without enabling the Service Bus policy either.

### No gateway
- Good, because it is the simplest and cheapest.
- Bad, because there is no boundary validation or versioning; every producer is coupled to the broker.

## More Information

- `send-service-bus-message` policy: https://learn.microsoft.com/azure/api-management/send-service-bus-message-policy
- Send messages to Service Bus from APIM (preview): https://learn.microsoft.com/azure/api-management/api-management-howto-send-service-bus
- Feature comparison by tier: https://learn.microsoft.com/azure/api-management/api-management-features
- v2 tier region availability: https://learn.microsoft.com/azure/api-management/api-management-region-availability
- `rate-limit-by-key`: https://learn.microsoft.com/azure/api-management/rate-limit-by-key-policy
