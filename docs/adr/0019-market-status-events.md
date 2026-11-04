# 0019 — Market status events

| Field | Value |
|---|---|
| Status | Proposed |
| Date | 2026-11-03 |
| Deciders | Solution Architect, Key Developer *(both roles held by one person — see README)* |
| Supersedes | — |
| Related | [0008](0008-data-storage.md), [0009](0009-event-driven-ingestion.md), [0010](0010-api-management-ingestion-gateway.md), [0011](0011-market-data-sourcing-and-licensing.md), [0012](0012-message-contract-and-versioning.md), [0013](0013-adapter-control-plane.md), [0015](0015-ui-and-real-time-push.md), [0017](0017-time-and-timezones.md), [0018](0018-latency-and-freshness-targets.md) |
| Traces to | [NFR-OPS-02](../requirements/nfr.md#nfr-ops-02) (data freshness alerting), [NFR-MNT-02](../requirements/nfr.md#nfr-mnt-02) (backward-compatible evolution), [NFR-DATA-01](../requirements/nfr.md#nfr-data-01) (idempotent processing); C4 L2: Messaging, Operational Store, Web UI |
| Domain pages | [Market data sources](../domain/market-data-sources.md), [Time and delivery](../domain/time-and-delivery.md) |

## Context and Problem Statement

Staleness of an instrument is evaluated only while its trading session is open ([0013](0013-adapter-control-plane.md), [0017](0017-time-and-timezones.md)), and sessions come from reference data. Reference data describes the plan, not what happened: a venue can halt a product, delay an open or close early. During a halt no ticks arrive, so the staleness alert fires although nothing is wrong with SignalLog; the operator learns nothing and starts distrusting the alert.

Every market data layer reviewed in [Market data sources](../domain/market-data-sources.md) carries market status next to trades and quotes; the vendor schema used as a reference has a dedicated `Status` schema. SignalLog's contract has only `PriceTick`. Should market status be part of the contract, and how does it change staleness?

## Decision Drivers

- D1 — No staleness alert while the venue reports the market as not trading ([NFR-OPS-02](../requirements/nfr.md#nfr-ops-02)).
- D2 — A lost or delayed status message must not suppress alerts indefinitely.
- D3 — Existing consumers of `PriceTick` keep working unchanged ([NFR-MNT-02](../requirements/nfr.md#nfr-mnt-02)).
- D4 — Works with replay as the default source ([0011](0011-market-data-sourcing-and-licensing.md)), and with a live source that publishes status, without a special case for either.
- D5 — No new cost line ([0000](0000-cost-optimization-strategy.md)).

## Considered Options

1. **Separate event type `signallog.market.status.v1` on its own topic `market-status`**
2. Separate event type on the existing `price-ticks` topic
3. A status field inside `PriceTick`
4. No status events; sessions from reference data only (current state)

## Decision Outcome

**Chosen option:** Option 1, because status has a different shape, scope and lifetime from a price and must not reach consumers that only understand prices (D3), while a topic in the existing namespace costs nothing extra (D5).

### Weighted evaluation

*Expert judgement (one assessor), not a measurement.* Rebuilt on 2026-11-04 under the [weighted evaluation method](README.md#weighted-evaluation-method). The first version scored "Clear contract" and "Effort", which are not drivers, and left out D2 and D4; its weights were chosen after the options were known.

Weights (swing weighting, fixed before scoring):

| Criterion | Driver | Weight | Why this weight |
|---|---|---|---|
| No staleness alert during a venue halt | D1 | 40 | The reason for this ADR; the worst case is a false alert at every halt |
| Lost status cannot suppress alerts indefinitely | D2 | 30 | The worst case is a real outage hidden for days; rare but severe |
| Existing `PriceTick` consumers unchanged | D3 | 20 | The worst case is a breaking change, but consumers are few and all in this repository |
| Same path for replay and live status | D4 | 10 | Live sources are not in scope yet ([0011](0011-market-data-sourcing-and-licensing.md)) |

Scale anchors:

| Criterion | 1 | 3 | 5 |
|---|---|---|---|
| No alert during a halt | An alert fires during every halt | Suppressed only for scheduled breaks, or late | Suppressed for the whole venue-reported halt |
| Lost status bounded | A lost message can suppress alerts without limit | Suppression bounded by a known limit (the next session boundary) | No message loss can suppress alerts |
| Consumers unchanged | Breaking change to `PriceTick` | Consumers must ignore new message types or fields | No change for any existing subscriber |
| Same path replay and live | Live status cannot be used | Works with adapter-specific translation | One code path for both |

| Criterion (weight) | 1. Own type and topic | 2. Own type on `price-ticks` | 3. Field in `PriceTick` | 4. Sessions only |
|---|---|---|---|---|
| No alert during a halt (40) | 5 | 5 | 2 | 1 |
| Lost status bounded (30) | 3 | 3 | 3 | 5 |
| Consumers unchanged (20) | 5 | 3 | 3 | 5 |
| Same path replay and live (10) | 5 | 5 | 3 | 1 |
| **Weighted score** | **4.40** | **4.00** | **2.60** | **3.00** |

Option 3 scores low on halts because a status carried on ticks cannot report a halt: a halt is precisely the period without ticks.

Drivers not scored: D5 (no new cost); all four options stay inside the existing Service Bus and Cosmos DB resources.

Sensitivity:

- Option 1 scores at least as well as Options 2 and 3 on every criterion, so no weights put either of them ahead.
- Option 4 wins only if the weight of D2 exceeds twice the weights of D1 and D4 combined (with D1 = 40 and D4 = 10, D2 would need more than 100 points, which is impossible out of 100; even if D1 alone were halved, D2 would need more than 60). That would mean a bounded suppression until the next session boundary is worse than a false alert at every halt, which contradicts D1. The result is robust.
- Not scored, because it is not a driver: effort. Option 1 is the most work (a topic, two subscriptions, a container, a schema); Option 4 is none. See *Consequences*.

### Event

```json
{
  "specversion": "1.0",
  "id": "0192a8f5-1d0e-7c44-8a2b-3e9f6d1c0a55",
  "source": "/adapters/replay",
  "type": "signallog.market.status.v1",
  "time": "2026-11-03T13:30:00.120Z",
  "dataschema": "https://signallog.example/schemas/market-status/v1.json",
  "traceparent": "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01",
  "data": {
    "scope": { "venueMic": "NDEX", "productCode": "TFM" },
    "status": "PAUSED",
    "reason": "VENUE_HALT",
    "eventTimeUtc": "2026-11-03T13:30:00.000Z",
    "sourceKind": "REPLAY"
  }
}
```

- **Envelope rules** are those of [0012](0012-message-contract-and-versioning.md): UUIDv7 `id` used as `MessageId` and document id, `traceparent`, UTC timestamps ([0017](0017-time-and-timezones.md)), JSON Schema validated at the gateway ([0010](0010-api-management-ingestion-gateway.md)).
- **Scope** is a venue, a product on a venue, or one instrument: `venueMic` is required; `productCode` and `instrumentId` narrow it. The most specific scope wins. Venues usually halt a product or a market segment, rarely one contract.
- **Status values:** `PRE_OPEN`, `OPEN`, `PAUSED`, `CLOSED`. `reason` is optional and free of logic: `SCHEDULED`, `VENUE_HALT`, `EARLY_CLOSE`, `UNKNOWN`.
- A status event states a transition at `eventTimeUtc`; it does not carry an end time.

### Effective status and staleness

The **effective status** of an instrument at instant *t* combines the calendar and the reported status:

1. Start from the **calendar status**: `OPEN` inside a session from reference data, `CLOSED` outside it ([0017](0017-time-and-timezones.md)).
2. If the most specific scope has a **reported status** whose `eventTimeUtc` lies after the most recent session boundary before *t*, the reported status replaces the calendar status.
3. A reported status never survives a session boundary. At each scheduled open or close the calendar takes over again until a new status event arrives.

Staleness is evaluated, and the `signallog.instrument.staleness_seconds` metric is emitted ([0007](0007-observability.md), [0018](0018-latency-and-freshness-targets.md)), only while the effective status is `OPEN`.

Rule 3 answers D2: if the `OPEN` message after a halt is lost, alerts are suppressed at most until the next scheduled boundary, not forever. The reverse case — a venue that stays closed on a day the calendar says open — is still reported as stale after the threshold, which is the desired outcome because reference data is wrong and needs correcting.

### Transport and storage

| Element | Decision |
|---|---|
| Topic | `market-status` in the existing Service Bus namespace ([0009](0009-event-driven-ingestion.md)), duplicate detection on `MessageId` (10 minutes), same delivery semantics as `price-ticks` |
| Subscriptions | `persist` → ingestion function; `live-push` → SignalR broadcaster ([0015](0015-ui-and-real-time-push.md)) |
| Ingress | same gateway and ingress function; the function routes by CloudEvents `type` to the matching topic |
| Container | `market-status` in Cosmos DB ([0008](0008-data-storage.md)): partition key `/scopeId`, document id `scopeId` (for example `NDEX.TFM`), one document per scope, upserted only when the incoming `eventTimeUtc` is newer. No history is kept; the event log in Application Insights is the audit trail |
| UI | the status badge (`Open`, `Paused`, `Closed`) is shown next to each price, so that a frozen price during a halt is explained on screen |

### Producers

- **Replay adapter:** emits `OPEN` and `CLOSED` at every scheduled session boundary and injects occasional `PAUSED` → `OPEN` pairs as a fault scenario, next to gaps and duplicates ([0011](0011-market-data-sourcing-and-licensing.md)). This makes the halt path testable and visible in the demo.
- **Live adapters:** emit status only when their source provides it. A source without status relies on the calendar; no adapter invents status from the absence of ticks.

### Consequences

- Good, because a venue halt no longer produces a false staleness alert, and the UI explains why a price is not moving.
- Good, because `PriceTick` and its consumers are unchanged; status is a new type on a new topic.
- Good, because the replay adapter can demonstrate halts, a scenario operators recognise.
- Bad, because ingestion and the UI handle a second event type, and the gateway validates a second schema.
- Bad, because the effective-status rule must be implemented once and used everywhere staleness is evaluated (domain service `IMarketStatusResolver`).
- Risk: a source reports `CLOSED` by mistake during a session and hides a real outage until the next boundary (mitigation: the operator sees the reported status and its source on the admin view; heartbeat and liveness are still alerted independently, [0013](0013-adapter-control-plane.md)).

### Confirmation

- Unit tests for the effective-status rule with real dates, at least: a halt inside a session (no staleness while `PAUSED`); a lost `OPEN` after a halt (staleness resumes at the next session boundary); an early close; a status event older than the last boundary (ignored); scope precedence (instrument over product over venue).
- Contract tests for `market-status/v1.json` with valid and invalid samples ([NFR-SEC-04](../requirements/nfr.md#nfr-sec-04)).
- Integration test: a replayed `PAUSED` → `OPEN` pair produces no staleness alert and shows the badge in the browser.
- The replayed month in the [0017](0017-time-and-timezones.md) confirmation includes at least one halt.

## Pros and Cons of the Options

### 1. Own event type and topic
- Good, because consumers subscribe only to what they understand, and status can be retained and replayed independently.
- Bad, because there is one more topic, subscription set and schema to operate.

### 2. Own event type on `price-ticks`
- Good, because there is no new topic.
- Bad, because every existing subscriber receives messages it does not understand and needs a filter or a type check; a consumer written for prices alone breaks.

### 3. Status field inside `PriceTick`
- Good, because it is the smallest contract change.
- Bad, because a halt is the absence of ticks, so a field on ticks cannot announce it; it also mixes per-instrument prices with per-product state.

### 4. Sessions from reference data only
- Good, because it needs no new code.
- Bad, because every venue halt or early close raises a false staleness alert.

## More Information

- Market status as a separate data layer across venues: [Market data sources](../domain/market-data-sources.md), section 3.
- Review trigger: a live source with its own status feed is enabled; check its status values map onto the four values above without loss.
