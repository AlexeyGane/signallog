# 0017 — Time and timezone handling

| Field | Value |
|---|---|
| Status | Proposed |
| Date | 2026-10-18 |
| Deciders | Solution Architect, Key Developer *(one person, see README)* |
| Related | [0007](0007-observability.md), [0012](0012-message-contract-and-versioning.md), [0013](0013-adapter-control-plane.md), [0014](0014-instrument-domain-model.md) |
| Traces to | NFR-DATA-04 (unambiguous timestamps), NFR-OPS-02 (staleness only during sessions) |

## Context and Problem Statement

Three venues trade on European calendars with their own local times and daylight-saving transitions; users may sit in any timezone; staleness alerts must only fire while a market is open. Mixing local and UTC times, or storing `DateTime` without offset, leads to off-by-one-hour bugs twice a year. How is time represented?

## Decision Drivers

- D1 — Unambiguous instants everywhere in storage and messages.
- D2 — Correct trading-session evaluation across DST changes.
- D3 — Testable time-dependent logic.

## Considered Options

1. UTC instants everywhere; venue timezones (IANA ids) only for session logic; `TimeProvider` for testability
2. Venue local time stored with each tick
3. Server local time

## Decision Outcome

**Chosen option:** Option 1.

- Storage and messages: ISO 8601 UTC (`Z`). In .NET: `DateTimeOffset` with zero offset; never `DateTime` with `Kind.Unspecified`.
- Two timestamps per tick: `eventTimeUtc` (venue) and CloudEvents `time` (adapter produced) ([0012](0012-message-contract-and-versioning.md)); ingestion records `receivedTimeUtc`. Their differences feed latency metrics ([0007](0007-observability.md)).
- Each product carries an IANA timezone id and a trading calendar ([0014](0014-instrument-domain-model.md)). Session checks convert "now" into the venue timezone using IANA ids (cross-platform since .NET 6).
- All time-dependent code takes `TimeProvider` (built into .NET 8+), so DST transitions and session boundaries are unit-tested with a fake clock (`FakeTimeProvider` from `Microsoft.Extensions.TimeProvider.Testing`). Production registers `TimeProvider.System` once in the composition root.
- Enforced at compile time with the same `BannedApiAnalyzers` setup as [0012](0012-message-contract-and-versioning.md) (`RS0030` raised to error). Entries in `BannedSymbols.txt`:

```text
// ADR 0017 — time
P:System.DateTime.Now;Use TimeProvider.GetUtcNow() — ADR 0017
P:System.DateTime.UtcNow;Use TimeProvider.GetUtcNow() — ADR 0017
P:System.DateTime.Today;Use TimeProvider and the venue timezone — ADR 0017
P:System.DateTimeOffset.Now;Use TimeProvider.GetUtcNow() — ADR 0017
P:System.DateTimeOffset.UtcNow;Use TimeProvider.GetUtcNow() — ADR 0017
```
- The UI converts to the viewer's local time for display and shows the venue time on hover.

### Consequences

- Good, because there is one rule to follow and DST bugs become testable.
- Bad, because trading calendars (holidays) must be maintained as reference data.

### Confirmation

- Unit tests cover the spring-forward and fall-back weekends for each venue timezone.
- A build containing `DateTime.Now`, `DateTime.UtcNow`, `DateTime.Today`, `DateTimeOffset.Now` or `DateTimeOffset.UtcNow` fails with `RS0030`.
- Staleness alerts do not fire on weekends or venue holidays in a replayed month.

## Pros and Cons of the Options

### UTC + IANA for sessions
- Good, because it is unambiguous and testable.
- Bad, because calendars need maintenance.

### Venue local time
- Good, because it matches exchange documents.
- Bad, because comparisons across venues are error-prone.

### Server local time
- Good, because it requires no conversion code.
- Bad, because it depends on host configuration and is wrong on any cloud host.
