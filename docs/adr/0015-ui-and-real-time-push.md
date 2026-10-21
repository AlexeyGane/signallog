# 0015 — User interface and real-time push

| Field | Value |
|---|---|
| Status | Proposed |
| Date | 2026-10-18 |
| Deciders | Solution Architect, Key Developer *(one person, see README)* |
| Related | [0000](0000-cost-optimization-strategy.md), [0005](0005-identity-and-access.md), [0006](0006-compute-hosting.md), [0009](0009-event-driven-ingestion.md), [0013](0013-adapter-control-plane.md) |
| Traces to | NFR-PERF-01 (tick-to-screen latency), NFR-SEC-02, C4 L2: Web UI |

## Context and Problem Statement

Users watch current prices; administrators control adapters ([0013](0013-adapter-control-plane.md)). Prices change every few seconds, so polling the database per user is wasteful and laggy. Which UI technology, hosting and push mechanism fit a .NET team, the budget and the serverless backend?

## Decision Drivers

- D1 — C#/.NET end to end (shared contracts with the backend).
- D2 — Live updates without per-client polling.
- D3 — Entra ID sign-in with Viewer / Admin roles ([0005](0005-identity-and-access.md)).
- D4 — Free hosting ([0000](0000-cost-optimization-strategy.md)).

## Considered Options

1. Blazor WebAssembly on Azure Static Web Apps (Free) + Azure SignalR Service (Free, serverless mode) fed by a Functions subscriber
2. Blazor Server on App Service
3. Blazor WebAssembly with client polling of the Query API
4. React/TypeScript SPA

## Decision Outcome

**Chosen option:** Option 1.

- The `live-push` subscription on `price-ticks` ([0009](0009-event-driven-ingestion.md)) triggers a function that broadcasts to SignalR groups per instrument via the SignalR output binding.
- The UI subscribes to the groups of the instruments on screen; initial state comes from `latest-prices` through the Query API.
- Admin pages call the Admin API; the `SignalLog.Admin` role is enforced server-side, the UI only hides controls.
- Every price displays its source badge (`LIVE` / `REPLAY`, [0011](0011-market-data-sourcing-and-licensing.md)) and its age.

### Consequences

- Good, because the stack is one language with shared contract types.
- Good, because push scales with the number of instruments, not with users × polling rate.
- Bad, because the SignalR Free tier has small connection and message quotas; enough for a demo, and the quota numbers must be checked against the current pricing page and recorded in [0000](0000-cost-optimization-strategy.md).
- Bad, because WebAssembly has a larger first download than server rendering.

### Confirmation

- End-to-end test: a replayed tick appears in the browser within the NFR latency target.
- Authorization test: a Viewer token cannot call admin endpoints.

## Pros and Cons of the Options

### Blazor WASM + SWA + SignalR serverless
- Good, because it is free, .NET-native and push-based.
- Bad, because of Free-tier quotas.

### Blazor Server
- Good, because it has built-in real-time over its own circuit.
- Bad, because it needs an always-on host, conflicting with the budget.

### WASM + polling
- Good, because it is simplest.
- Bad, because it is laggy and wasteful; weak demonstration of event-driven design.

### React SPA
- Good, because it is the market standard for front ends.
- Bad, because it adds a second language and toolchain to a .NET-focused portfolio.
