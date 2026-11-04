# 0017 — Time, timezones and delivery periods

| Field | Value |
|---|---|
| Status | Proposed (revision 2) |
| Date | 2026-11-01 (revision 1: 2026-10-18) |
| Deciders | Solution Architect, Key Developer *(one person, see README)* |
| Related | [0007](0007-observability.md), [0008](0008-data-storage.md), [0012](0012-message-contract-and-versioning.md), [0013](0013-adapter-control-plane.md), [0014](0014-instrument-domain-model.md) |
| Domain documentation | [Time and delivery](../domain/time-and-delivery.md), [Market conventions](../domain/market-conventions.md), [Glossary](../domain/glossary.md) |
| Traces to | NFR-DATA-04 (unambiguous timestamps), NFR-DATA-05 (correct delivery volumes on DST days), NFR-OPS-02 (staleness only during sessions) |

## Context and Problem Statement

Venues in London, Amsterdam and Leipzig, and the ICE trading platform whose sessions follow New York time, all have their own daylight-saving transitions. Users may sit in any timezone. Staleness alerts must fire only while a market is open. Delivery products (gas, power) are defined in local time, so a delivery day lasts 23, 24 or 25 hours, and market reports (EPEX, GB settlement) label periods by local time. Mixing local and UTC times, or storing `DateTime` without an offset, leads to off-by-one-hour bugs twice a year; resolving local times differently on different hosts leads to results that cannot be reproduced.

Revision 2 records the decisions taken on 2026-11-01: delivery-volume rule, local-time resolution policy, market periods and windows as versioned reference data, read-time projections, and the choice of NodaTime.

## Decision Drivers

- D1 — Unambiguous instants everywhere in storage and messages.
- D2 — Correct trading sessions, delivery days and volumes across DST changes, including the weeks when US and EU transitions differ.
- D3 — Identical results on every host (developer Windows machine, CI on Linux, Azure Functions on Linux).
- D4 — Testable time-dependent logic with a fake clock.
- D5 — Prefer an industry-standard library over custom date arithmetic, provided its dependency risks are contained.

## Considered Options

1. UTC instants; local rules with IANA zones; BCL types (`DateTimeOffset`, `DateOnly`, `TimeZoneInfo`) and custom resolution code
2. UTC instants; local rules with IANA zones; **NodaTime** inside the domain, BCL types at the boundaries
3. Venue local time stored with each tick
4. Server local time

## Decision Outcome

**Chosen option:** Option 2.

### 1. Representation

| Concept | Stored / transported as | In the domain (NodaTime) | Example |
|---|---|---|---|
| Instant of an event (tick, heartbeat) | ISO 8601 UTC string; `DateTimeOffset` with zero offset in .NET | `Instant` | `2026-10-25T00:30:00Z` |
| Rule defined in local time (session, delivery-day start, peak window) | local time + IANA zone id | `LocalTime` + `DateTimeZone` | `20:00`, `America/New_York` |
| Label of a period (trading day, delivery day, delivery month) | ISO date without time | `LocalDate`, `YearMonth` | `2026-10-24` |
| Length of an interval | ISO 8601 duration or seconds | `Duration` | `PT25H` |

- Local rules are **never converted to UTC in advance**. They are resolved for a specific date when used.
- Two timestamps per tick: `eventTimeUtc` (venue) and CloudEvents `time` (adapter produced) ([0012](0012-message-contract-and-versioning.md)); ingestion records `receivedTimeUtc`. Their differences feed latency metrics ([0007](0007-observability.md)).
- Each product carries an IANA zone, a session definition and a delivery-day start in reference data ([0014](0014-instrument-domain-model.md)). Fixed offsets (`+01:00`) are never stored as rules: exchange documents that say "CET" mean the local time of the zone, CET in winter and CEST in summer.

### 2. Resolving local times (gaps and overlaps)

When a local rule is resolved for a date, the local time may not exist (spring-forward gap) or may occur twice (fall-back overlap). The policy is NodaTime's *lenient* resolver (`InZoneLeniently`):

| Case | Example (Europe/Berlin) | Result |
|---|---|---|
| Gap | 2026-03-29 02:30 does not exist | shifted forward by the gap: 03:30 CEST = `2026-03-29T01:30Z` |
| Overlap | 2026-10-25 02:30 occurs twice | the **earlier** occurrence: 02:30 CEST = `2026-10-25T00:30Z` |

All boundaries used by SignalLog (06:00, 08:00, 18:00, 20:00, 20:50, 00:00) lie outside the transition window, so the policy is a safety net; it is fixed here so that any future rule inside the window behaves predictably. Code that must not accept an ambiguous time uses `InZoneStrictly`.

### 3. Delivery volume — business rule BR-TIME-01

This and the other time rules of this ADR are catalogued as BR-TIME-01 … BR-TIME-08 in [business rules](../requirements/business-rules.md#time-and-delivery).

> **Delivered energy = capacity × elapsed duration of the delivery period**, where the period is bounded by the product's local delivery-day start in the delivery zone, and elapsed duration is measured between the two UTC instants.

| Delivery day | Elapsed hours | 1 MW delivers |
|---|---|---|
| Normal | 24 | 24 MWh |
| Short (spring forward) | 23 | 23 MWh |
| Long (fall back) | 25 | 25 MWh, one local hour occurs twice |

- Gas delivery days run 06:00–06:00 local time (TTF, THE), so the transition at 03:00 falls into the delivery day that **started the previous morning**: gas day 2026-10-24 has 25 hours, gas day 2026-03-28 has 23 hours. Power delivery days run 00:00–24:00 local time.
- A monthly product is the sum of its delivery days (October 2026: 745 MWh per MW).
- Generalisation: volumes are computed over **settlement periods enumerated in UTC** (60, 30 or 15 minutes). Counting real periods gives 23/24/25 hours, 46/48/50 half-hours (GB) and 92/96/100 quarter-hours without a special formula.

### 4. Trading day

- A tick belongs to the **trading day of its session**, not to its UTC date. An ICE session opening on Sunday 20:00 New York time belongs to Monday's trading day.
- Daily OHLC bars ([0008](0008-data-storage.md)) are keyed by `instrumentId + tradingDate`. A bar on a transition day covers 21 or 23 hours of a 22-hour session; that is correct, not an anomaly.
- Session open and close are resolved to UTC per trading date. During the weeks when US and EU clocks change on different dates, ICE sessions move by one hour relative to London; this is expected behaviour, not an error.

### 5. Market periods and windows are versioned reference data

- What is stored is the **rule**, not the enumerated periods. A market convention holds: IANA zone, delivery-day start, a history of versions (`validFrom` as a local delivery date, period length, label scheme) and named windows (Base, Peak, Off-peak) in local time with weekday filters.
- Versions are effective-dated because markets change their rules: the EPEX day-ahead auction moved from 60-minute to 15-minute periods for delivery from 2025-10-01.
- Conventions live in `contracts/reference/` next to the instrument reference data, change through pull requests, and are loaded into the reference-data store at deployment.
- Periods are **computed** from the convention when needed. Exceptions: period labels received from an exchange are stored as received (first-hand source, alongside `startUtc`/`endUtc`); a materialised calendar table for BI tools may be generated, and is always derived and disposable.

### 6. Reports are read-time projections

- Storage contains UTC data only. Market-specific views (EPEX `3A`/`3B` hours, GB settlement periods `SP1`–`SP50`, base/peak indices) are computed at read time by settlement calendars in `SignalLog.Domain` and served by the Query API ([0006](0006-compute-hosting.md)).
- Every report row carries the market label, `startUtc`, `endUtc` and the local start time with its offset, so it can be reconciled without further conversion.
- Every report records the `conventionId`, the convention version and the **tzdb version** used (`TzdbDateTimeZoneSource.Default.VersionId`), so a recalculated report can be explained.
- Frequently used reports may later be materialised through the Cosmos DB change feed (same pattern as `daily-bars`); that is an optimisation, not the design.

### 7. NodaTime and its boundaries

- NodaTime is used **only in `SignalLog.Domain`** (and the projects that compute reports). Contracts, JSON Schemas, CloudEvents and Cosmos DB documents use ISO 8601 strings and `DateTimeOffset`; consumers do not need NodaTime.
- "Now" comes from `TimeProvider` (built into .NET 8+); production registers `TimeProvider.System` once in the composition root, tests use `FakeTimeProvider`. NodaTime receives the time through an adapter `TimeProviderClock : IClock`.
- The time-zone provider is `DateTimeZoneProviders.Tzdb`: the IANA database embedded in the NodaTime package, so every host uses the same rules (D3).

### 8. Keeping time-zone rules current

- tzdb updates arrive with NodaTime package updates proposed by Dependabot; the DST test suite runs on every update.
- If a rule change cannot wait for a package release, a newer `.nzd` file published by the NodaTime project can be loaded with `TzdbDateTimeZoneSource.FromStream`.
- Stored history is unaffected by rule changes because it is in UTC; only future local-to-UTC resolutions change.

### 9. Enforcement

Same `BannedApiAnalyzers` setup as [0012](0012-message-contract-and-versioning.md) (`RS0030` raised to error). Entries in `BannedSymbols.txt`:

```text
// ADR 0017 — time
P:System.DateTime.Now;Use TimeProvider.GetUtcNow() — ADR 0017
P:System.DateTime.UtcNow;Use TimeProvider.GetUtcNow() — ADR 0017
P:System.DateTime.Today;Use TimeProvider and the venue timezone — ADR 0017
P:System.DateTimeOffset.Now;Use TimeProvider.GetUtcNow() — ADR 0017
P:System.DateTimeOffset.UtcNow;Use TimeProvider.GetUtcNow() — ADR 0017
P:NodaTime.SystemClock.Instance;Inject IClock backed by TimeProvider (TimeProviderClock) — ADR 0017
```

The NodaTime entry is added together with the package reference, in the pull request that introduces NodaTime.

### Consequences

- Good, because instants are unambiguous and local rules are resolved once, in one place, with an explicit policy.
- Good, because NodaTime's types make "instant" versus "local time" a compile-time distinction, and its resolvers replace custom, untested code.
- Good, because the embedded tzdb gives identical results on Windows, Linux and in CI.
- Good, because reports for any market convention can be added without migrating data.
- Bad, because NodaTime adds a dependency with a small core maintainer team; mitigated by keeping it inside the domain behind BCL types at every boundary.
- Bad, because tzdb freshness now depends on updating the package; mitigated by Dependabot and the `.nzd` fallback.
- Bad, because trading calendars (holidays) and market conventions must be maintained as reference data.

### Confirmation

Unit tests with `FakeTimeProvider` for `America/New_York`, `Europe/London`, `Europe/Amsterdam` and `Europe/Berlin`:

- Gas day 2026-10-24 has 25 hours, gas day 2026-03-28 has 23 hours, a normal day 24; volume for 1 MW is 25 / 23 / 24 MWh; October 2026 is 745 MWh.
- On the long day two hourly slots start at local 02:00 (offsets +02:00 and +01:00); on the short day none does.
- Gap and overlap resolution return the instants in section 2.
- A tick at 22:30 New York time on a Sunday belongs to Monday's trading day.
- During a week when US and EU clocks differ, the ICE session opens one hour earlier in London time.
- GB settlement calendar yields 46 / 48 / 50 periods; EPEX hourly calendar yields `3A`/`3B` on the long day and no hour 3 on the short day.
- Staleness alerts do not fire outside sessions, on weekends or on venue holidays in a replayed month.
- A build containing `DateTime.Now`, `DateTime.UtcNow`, `DateTime.Today`, `DateTimeOffset.Now`, `DateTimeOffset.UtcNow` or (once NodaTime is referenced) `SystemClock.Instance` fails with `RS0030`.

## Pros and Cons of the Options

### UTC + IANA + BCL with custom resolution
- Good, because there are no extra dependencies and the types are familiar.
- Bad, because zone rules come from the operating system (Windows registry, Linux `tzdata`) and can differ between hosts.
- Bad, because there is no gap/overlap policy (`TimeZoneInfo.ConvertTimeToUtc` throws on invalid times and silently picks one offset for ambiguous ones); it would have to be written and tested here.

### UTC + IANA + NodaTime in the domain
- Good, because it is the de facto standard for date and time in .NET, with explicit types, resolvers and an embedded tzdb.
- Bad, because it is an additional dependency whose types must be kept out of contracts.

### Venue local time
- Good, because it matches exchange documents.
- Bad, because comparisons across venues are error-prone and local times are ambiguous on transition days.

### Server local time
- Good, because it requires no conversion code.
- Bad, because it depends on host configuration and is wrong on any cloud host.

## More Information

- NodaTime: https://nodatime.org/
- IANA Time Zone Database: https://www.iana.org/time-zones
- EPEX SPOT, 15-minute products in market coupling: https://www.epexspot.com/en/15-minute-products-market-coupling
