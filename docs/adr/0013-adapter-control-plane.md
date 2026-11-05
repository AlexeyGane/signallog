# 0013 — Adapter control plane

| Field | Value |
|---|---|
| Status | Proposed |
| Date | 2026-10-18 |
| Deciders | Solution Architect, Key Developer *(one person, see README)* |
| Related | [0005](0005-identity-and-access.md), [0006](0006-compute-hosting.md), [0007](0007-observability.md), [0009](0009-event-driven-ingestion.md), [0015](0015-ui-and-real-time-push.md) |
| Traces to | NFR-OPS-03 (operator can stop/start a source), NFR-REL-02 (resilience policies), C4 L3: Adapter components |

## Context and Problem Statement

An administrator must be able to see whether each adapter is healthy, stop and start it, and tune its resilience behaviour (retries, circuit breaker, fallback) without redeploying. "Healthy" has two different meanings that are often confused: *the process is running* and *data is actually flowing*. How is the adapter fleet controlled and observed?

## Decision Drivers

- D1 — Separate liveness (process) from freshness (data).
- D2 — Stop/start without redeployment.
- D3 — Resilience parameters changeable at runtime.
- D4 — Least privilege for the admin API ([0005](0005-identity-and-access.md)).

## Considered Options

1. **Two-level control:** infrastructure level via Functions app settings; application level via commands on Service Bus and Azure App Configuration
2. Direct HTTP calls from the admin API to adapter endpoints
3. Redeploy to change behaviour

## Decision Outcome

**Chosen option:** Option 1.

### Infrastructure level — stop/start

- Each adapter is one timer-triggered function in `func-signallog-adapters` ([0006](0006-compute-hosting.md)).
- Stop/start sets the app setting `AzureWebJobs.<FunctionName>.Disabled` to `true`/`false` through Azure Resource Manager. The admin API's managed identity has a custom role limited to writing app settings on that one function app.
- Changing app settings restarts the function app by default on every hosting plan; Flex Consumption can apply them without downtime when its site update strategy is set to rolling updates ([disable a function](https://learn.microsoft.com/azure/azure-functions/disable-function), [site updates](https://learn.microsoft.com/azure/azure-functions/flex-consumption-site-updates)). A restart is acceptable for an explicit operator action and is shown in the UI as "applying…".
- Function names must not contain a hyphen: on Linux, functions with a hyphen in the name cannot be disabled this way ([disable a function, considerations](https://learn.microsoft.com/azure/azure-functions/disable-function#considerations)). Flex Consumption runs on Linux ([0006](0006-compute-hosting.md)).

### Application level — pause, parameters, fallback

- Commands (`Pause`, `Resume`, `SetPollingInterval`, `ForceFallback`) are published to `adapter-commands` with an `adapterId` property; each adapter's subscription filters on it ([0009](0009-event-driven-ingestion.md)). Adapters check their subscription at the start of each timer run.
- Resilience parameters live in Azure App Configuration (free tier) under `adapters:<adapterId>:resilience:*` and are read through `IOptionsMonitor`, so changes apply on the next run without restart.
- Resilience is implemented with `Microsoft.Extensions.Http.Resilience` (Polly v8): retry with [exponential backoff and jitter](../standards/concepts-and-sources.md#backoff-jitter), [circuit breaker](../standards/concepts-and-sources.md#circuit-breaker), timeout, and a fallback source where configured.

### Health model

| Signal | Meaning | Source |
|---|---|---|
| Heartbeat | Adapter run completed (success or handled failure), with counts and circuit state | `adapter-heartbeats` topic, stored in `adapter-status` ([0008](0008-data-storage.md)) |
| Staleness | Time since the last tick per instrument, evaluated only while the instrument's effective market status is `OPEN`: trading session from reference data ([0017](0017-time-and-timezones.md)), overridden by venue-reported status ([0019](0019-market-status-events.md)) | `latest-prices` |
| Circuit state | Closed / Open / Half-open per upstream | Heartbeat payload |

The UI shows the three side by side; an adapter can be "running" while data is stale, and that is exactly the state an operator needs to see.

### Consequences

- Good, because the Azure resource stays the source of truth for running state.
- Good, because tuning happens at runtime and is auditable (App Configuration history, kept 7 days on the Free tier; command messages).
- Risk: the App Configuration Free tier allows 1,000 requests per day per store and returns HTTP 429 until midnight UTC once exhausted ([tiers and quotas](https://learn.microsoft.com/azure/azure-app-configuration/faq#which-app-configuration-tier-should-i-use)). Mitigation: the configuration provider's refresh interval is set so that all adapter apps together stay below the quota (for example, one sentinel check per app every 5 minutes is 288 requests per day per app); exhaustion degrades to the last loaded values, not to a failure.
- Bad, because there are two control paths to understand; documented in the "Adapter operations" runbook.

### Confirmation

- Runbook exercise: stop adapter, observe heartbeat stop and staleness alert, restart, observe recovery.
- Changing retry count in App Configuration is reflected in the next heartbeat's reported policy.

## Pros and Cons of the Options

### Two-level control
- Good, because no inbound endpoint on adapters is needed and least privilege is preserved.
- Bad, because there are more moving parts.

### Direct HTTP to adapters
- Good, because it is simple to explain.
- Bad, because timer functions are not long-running services; each adapter would need an exposed and secured endpoint.

### Redeploy
- Good, because there is nothing to build.
- Bad, because it fails D2 and D3.

## More Information

Sources (checked 2026-11-04):

- Disable functions with `AzureWebJobs.<FUNCTION_NAME>.Disabled`: https://learn.microsoft.com/azure/azure-functions/disable-function
- Flex Consumption site updates (rolling updates): https://learn.microsoft.com/azure/azure-functions/flex-consumption-site-updates
- App Configuration tiers, quotas and revision history: https://learn.microsoft.com/azure/azure-app-configuration/faq#which-app-configuration-tier-should-i-use
- HTTP resilience with `Microsoft.Extensions.Http.Resilience`: https://learn.microsoft.com/dotnet/core/resilience/http-resilience
