# Business rules

The catalogue of domain rules that SignalLog must obey regardless of technology: how energy is counted, which contract a price belongs to, when data counts as stale. Writing rules and status values are in the [requirements README](README.md); terms are defined in the [glossary](../domain/glossary.md).

**Origin.** Until 2026-11-04 one rule had an identifier (`BR-TIME-01`, defined inside [ADR 0017](../adr/0017-time-and-timezones.md)); the others were stated in ADR decision sections, the [domain model](../domain/model.md) invariants and the domain pages without an identifier. This catalogue gives each of them an identifier and one place. The ADR remains the authority for *why* a rule was chosen; this page states *what* the rule is.

**Business rule versus NFR.** A business rule describes the domain: it would hold in any implementation and a domain expert can check it (a long gas day delivers 25 MWh per MW). A non-functional requirement describes a quality of the system: speed, security, cost ([NFR catalogue](nfr.md)). Several NFRs exist to verify business rules, for example [NFR-DATA-05](nfr.md#nfr-data-05) verifies BR-TIME-01.

## Summary

| ID | Rule (short) | Decided in | Status |
|---|---|---|---|
| [BR-TIME-01](#br-time-01) | Delivered energy = capacity × elapsed duration between UTC boundaries | [0017](../adr/0017-time-and-timezones.md) §3 | Agreed |
| [BR-TIME-02](#br-time-02) | Gas day 06:00–06:00, power day 00:00–24:00 local; labelled by the start date | [0017](../adr/0017-time-and-timezones.md) §3 | Agreed |
| [BR-TIME-03](#br-time-03) | Gap → shift forward; overlap → earlier occurrence | [0017](../adr/0017-time-and-timezones.md) §2 | Agreed |
| [BR-TIME-04](#br-time-04) | Local rules use the zone's local time, never a fixed offset, resolved per date | [0017](../adr/0017-time-and-timezones.md) §1 | Agreed |
| [BR-TIME-05](#br-time-05) | A tick belongs to the trading day of its session | [0017](../adr/0017-time-and-timezones.md) §4 | Agreed |
| [BR-TIME-06](#br-time-06) | Market conventions are effective-dated; the version valid for the delivery date applies | [0017](../adr/0017-time-and-timezones.md) §5 | Agreed |
| [BR-TIME-07](#br-time-07) | Reports are read-time projections that record convention and tzdb versions | [0017](../adr/0017-time-and-timezones.md) §6 | Agreed |
| [BR-TIME-08](#br-time-08) | Peak = 08:00–20:00 local; base = all periods of the delivery day | [0017](../adr/0017-time-and-timezones.md) §5 | Reference (power out of scope) |
| [BR-INST-01](#br-inst-01) | Every price belongs to exactly one contract `{MIC}.{productCode}.{deliveryPeriodId}` | [0014](../adr/0014-instrument-domain-model.md) §1–2 | Agreed |
| [BR-INST-02](#br-inst-02) | A delivery period's extent is reference data; holiday-dependent periods are anchored on their first day | [0014](../adr/0014-instrument-domain-model.md) §2 | Agreed |
| [BR-INST-03](#br-inst-03) | Relative tenors (DA, M+1, Cal+1) are resolved at read time and never stored | [0014](../adr/0014-instrument-domain-model.md) §4 | Agreed |
| [BR-INST-04](#br-inst-04) | M+n, Q+n, seasons, gas years, Cal+n = n-th period still tradable | [0014](../adr/0014-instrument-domain-model.md) §4 | Agreed |
| [BR-INST-05](#br-inst-05) | DA, WE, BOW, WDNW, BOM follow the venue's rule per product | [0014](../adr/0014-instrument-domain-model.md) §4 | Agreed |
| [BR-INST-06](#br-inst-06) | Strip prices are kept as strips; leg prices are never invented; cascaded periods are different instruments | [0014](../adr/0014-instrument-domain-model.md) §3 | Agreed |
| [BR-INST-07](#br-inst-07) | A continuous series rolls when the resolved contract changes; raw prices, no back-adjustment by default | [0014](../adr/0014-instrument-domain-model.md) §4 | Agreed |
| [BR-PRICE-01](#br-price-01) | A price is an exact decimal, a multiple of the product's tick size, with its currency and unit | [0012](../adr/0012-message-contract-and-versioning.md), [0014](../adr/0014-instrument-domain-model.md) | Agreed |
| [BR-PRICE-02](#br-price-02) | The latest price is the one with the newest venue event time, not the last one received | [0009](../adr/0009-event-driven-ingestion.md) | Agreed |
| [BR-PRICE-03](#br-price-03) | Every displayed price shows its source (`LIVE` / `REPLAY`) and its age | [0011](../adr/0011-market-data-sourcing-and-licensing.md), [0015](../adr/0015-ui-and-real-time-push.md) | Agreed |
| [BR-FRESH-01](#br-fresh-01) | Staleness = time since the instrument's last tick | [0013](../adr/0013-adapter-control-plane.md) | Agreed (reference clock Proposed) |
| [BR-FRESH-02](#br-fresh-02) | Staleness counts only while the effective market status is `OPEN` | [0017](../adr/0017-time-and-timezones.md), [0019](../adr/0019-market-status-events.md) | Agreed |
| [BR-FRESH-03](#br-fresh-03) | Effective status = calendar, overridden by reported status since the last session boundary | [0019](../adr/0019-market-status-events.md) | Agreed |
| [BR-FRESH-04](#br-fresh-04) | Market status is never inferred from the absence of ticks | [0019](../adr/0019-market-status-events.md) | Agreed |
| [BR-FRESH-05](#br-fresh-05) | The staleness threshold is set per product from its own tick gaps | [0018](../adr/0018-latency-and-freshness-targets.md) | Proposed |
| [BR-SRC-01](#br-src-01) | Replay is the default source; a live source needs a recorded terms review; no scraping | [0011](../adr/0011-market-data-sourcing-and-licensing.md) | Agreed |
| [BR-SRC-02](#br-src-02) | Only derived statistics from licensed data enter the repository, never raw series | [0011](../adr/0011-market-data-sourcing-and-licensing.md) | Agreed |

## Definitions

### Time and delivery

<a id="br-time-01"></a>
#### BR-TIME-01 — Delivered energy

- **Rule:** delivered energy = capacity × elapsed duration of the delivery period, where the period is bounded by the product's local delivery-day start in the delivery zone and the duration is measured between the two UTC instants. Volumes are computed over settlement periods enumerated in UTC, so no special formula exists for transition days.
- **Example:** 1 MW delivers 24 MWh on a normal day, 23 on a short day, 25 on a long day; TTF October 2026 = 745 MWh per MW; the TTF weekend starting 2026-10-24 = 49 MWh.
- **Decided in:** [ADR 0017](../adr/0017-time-and-timezones.md) §3; extended to all period kinds in [ADR 0014](../adr/0014-instrument-domain-model.md) §2.
- **Verified by:** unit tests with the real-date tables in ADR 0017 and ADR 0014 ([NFR-DATA-05](nfr.md#nfr-data-05)).
- **Status:** Agreed.

<a id="br-time-02"></a>
#### BR-TIME-02 — Delivery day boundaries and labels

- **Rule:** a gas delivery day runs from 06:00 to 06:00 local time of the delivery zone (TTF, THE); a power delivery day runs from 00:00 to 24:00 local time. A delivery day is labelled with the date on which it starts.
- **Example:** gas day 2026-10-24 runs from 2026-10-24 06:00 to 2026-10-25 06:00 and lasts 25 hours, because the October transition falls inside it; gas day 2026-03-28 lasts 23 hours.
- **Decided in:** [ADR 0017](../adr/0017-time-and-timezones.md) §3; [glossary](../domain/glossary.md#time-and-delivery).
- **Verified by:** unit tests of delivery-day enumeration across both transitions.
- **Status:** Agreed.

<a id="br-time-03"></a>
#### BR-TIME-03 — Local times that do not exist or occur twice

- **Rule:** when a local rule is resolved for a date, a time in the spring-forward gap moves forward by the length of the gap, and a time in the fall-back overlap takes the earlier of its two occurrences. Code that must not accept an ambiguous time rejects it instead.
- **Example (Europe/Berlin):** 2026-03-29 02:30 does not exist → 03:30 CEST (`2026-03-29T01:30Z`); 2026-10-25 02:30 occurs twice → the first, 02:30 CEST (`2026-10-25T00:30Z`).
- **Decided in:** [ADR 0017](../adr/0017-time-and-timezones.md) §2.
- **Verified by:** unit tests on both examples.
- **Status:** Agreed. All boundaries used today (06:00, 08:00, 18:00, 20:00, 22:00, 00:00, 00:50) lie outside the transition window; the rule is a safety net for future ones.

<a id="br-time-04"></a>
#### BR-TIME-04 — Local rules are zone rules, resolved per date

- **Rule:** a rule stated in local time (session, delivery-day start, peak window) is stored as a local time plus an IANA zone and resolved to UTC only for a specific date. A fixed offset is never stored as a rule; "CET" in exchange documents means the local time of the zone, CET in winter and CEST in summer.
- **Example:** the ICE Brent session opening at 20:00 New York time is 01:00 UTC in winter and 00:00 UTC in summer; during weeks when US and UK clocks change on different dates it moves by one hour relative to London, while the London-anchored TTF session moves relative to New York; both are expected ([anchor zones](../domain/market-conventions.md#11-session-anchor-zones)).
- **Decided in:** [ADR 0017](../adr/0017-time-and-timezones.md) §1 and §4.
- **Verified by:** unit tests of session resolution in the US/EU mismatch weeks.
- **Status:** Agreed.

<a id="br-time-05"></a>
#### BR-TIME-05 — Trading day

- **Rule:** a tick belongs to the trading day of the session that contains its venue event time, not to its UTC date. Daily bars are keyed by instrument and trading date. A tick outside every session is flagged, not silently assigned.
- **Example:** an ICE Brent session opening on Sunday 20:00 New York time belongs to Monday's trading day; a bar on a transition day covers 21 or 23 hours of a 22-hour session, which is correct.
- **Decided in:** [ADR 0017](../adr/0017-time-and-timezones.md) §4; [domain model](../domain/model.md#invariants), invariant 5.
- **Verified by:** unit tests of trading-day assignment for Sunday sessions and transition days.
- **Status:** Agreed.

<a id="br-time-06"></a>
#### BR-TIME-06 — Effective-dated market conventions

- **Rule:** how a market divides time (zone, delivery-day start, period length, labels, windows) is versioned reference data with a `validFrom` delivery date. A calculation uses the version valid for the delivery date it concerns. What is stored is the rule, not enumerated periods; period labels received from an exchange are stored as received.
- **Example:** the European day-ahead auction moved from 60-minute to 15-minute periods for delivery from 2025-10-01; a report for 2025-09-30 uses the 60-minute version.
- **Decided in:** [ADR 0017](../adr/0017-time-and-timezones.md) §5; [market conventions](../domain/market-conventions.md).
- **Verified by:** unit test selecting the version on either side of a `validFrom` date.
- **Status:** Agreed.

<a id="br-time-07"></a>
#### BR-TIME-07 — Reports are projections

- **Rule:** stored data is UTC only; market-specific views (hour labels such as `3A`/`3B`, GB settlement periods `SP1`–`SP50`, base and peak indices) are computed at read time. Every report row carries the market label, `startUtc`, `endUtc` and the local start with its offset; every report records the convention id, its version and the tzdb version used.
- **Example:** a report recalculated after a tzdb update shows which tzdb version produced each figure.
- **Decided in:** [ADR 0017](../adr/0017-time-and-timezones.md) §6.
- **Verified by:** contract test of the report shape; review of report output.
- **Status:** Agreed.

<a id="br-time-08"></a>
#### BR-TIME-08 — Peak and base windows

- **Rule:** base = every period of the delivery day; peak = periods from 08:00 (inclusive) to 20:00 (exclusive) local time, on weekdays for monthly products. Windows are stored as named windows of a market convention (BR-TIME-06), with the IANA zone, not a fixed offset.
- **Example:** a peak day always has 12 hours (48 quarter-hours), because 08:00–20:00 never contains a transition; a base day has 23, 24 or 25 hours.
- **Decided in:** [ADR 0017](../adr/0017-time-and-timezones.md) §5 (windows as reference data); values in [market conventions](../domain/market-conventions.md#3-peak-base-and-off-peak).
- **Verified by:** unit tests when power products enter scope.
- **Status:** Reference. Power is out of scope; the rule is recorded because it shaped the time model.

### Instruments and delivery periods

<a id="br-inst-01"></a>
#### BR-INST-01 — Instrument identity

- **Rule:** every price belongs to exactly one tradable contract, identified as `{MIC}.{productCode}.{deliveryPeriodId}`. The MIC and product code must exist in reference data, the product must list the period kind, and the period id contains no `.`.
- **Example:** `NDEX.TFM.2026-12` (TTF December 2026 on ICE Endex), `NDEX.TFM.2026-11-07-WE` (TTF weekend). TTF on ICE Endex and a TTF contract on ICE Futures Europe are different instruments.
- **Decided in:** [ADR 0014](../adr/0014-instrument-domain-model.md) §1–2; [domain model](../domain/model.md#invariants), invariant 2.
- **Verified by:** ingestion rejects unknown ids ([NFR-DATA-03](nfr.md#nfr-data-03)).
- **Status:** Agreed.

<a id="br-inst-02"></a>
#### BR-INST-02 — Extent of a delivery period

- **Rule:** the extent of a contract (first and last delivery day, inclusive) is reference data, not derived from its id. Kinds whose length depends on a venue holiday calendar (weekend, balance of week, balance of month, working days) are identified by their first delivery day.
- **Example:** the TTF weekend starting 2026-12-25 covers four gas days, to 2026-12-29 06:00, because 25 and 28 December 2026 are UK bank holidays; its id is `2026-12-25-WE`.
- **Decided in:** [ADR 0014](../adr/0014-instrument-domain-model.md) §2; [tenors and delivery periods](../domain/tenors-and-delivery-periods.md).
- **Verified by:** unit tests of extents and hours ([ADR 0014](../adr/0014-instrument-domain-model.md) Confirmation).
- **Status:** Agreed.

<a id="br-inst-03"></a>
#### BR-INST-03 — Relative tenors are labels

- **Rule:** labels that point to a different contract over time — `DA`, `WE`, `BOW`, `WDNW`, `BOM`, `M+n`, `Q+n`, `SUM+n`/`WIN+n`, `GY+n`, `Cal+n`, `FM` — are resolved at read time for a given instant. They are never stored as instruments or in a tick's instrument id.
- **Example:** "TTF day-ahead" on Friday 2026-11-06 is the contract `NDEX.TFM.2026-11-09`; the stored tick refers to that contract.
- **Decided in:** [ADR 0014](../adr/0014-instrument-domain-model.md) §4.
- **Verified by:** contract schema rejects relative labels in `instrumentId`.
- **Status:** Agreed.

<a id="br-inst-04"></a>
#### BR-INST-04 — Resolving M+n and longer tenors

- **Rule:** `M+n`, `Q+n`, seasons, gas years and `Cal+n` resolve to the n-th period of that kind, ordered by start of delivery, that is still tradable at the given instant (listed and not past its last trading day). A strip is tradable only while every leg is.
- **Example:** on 2026-11-02, TTF `M+1` = `NDEX.TFM.2026-12` (November stopped trading on 2026-10-29), while Brent `M+1` = `IFEU.BRN.2027-01` (December expired on 2026-10-30). "Next calendar month" would be wrong for both.
- **Decided in:** [ADR 0014](../adr/0014-instrument-domain-model.md) §4.
- **Verified by:** unit tests on both examples.
- **Status:** Agreed.

<a id="br-inst-05"></a>
#### BR-INST-05 — Venue rules for short-term tenors

- **Rule:** `DA`, `WE`, `BOW`, `WDNW` and `BOM` resolve by the venue's rule for the product, held as product reference data, not as code constants.
- **Example:** for TTF on ICE Endex the day-ahead traded on a Friday is the gas day of the following Monday, moved past UK bank holidays.
- **Decided in:** [ADR 0014](../adr/0014-instrument-domain-model.md) §4; rules transcribed in [tenors and delivery periods](../domain/tenors-and-delivery-periods.md#2-delivery-periods-on-the-in-scope-venues).
- **Verified by:** unit test: TTF `DA` on 2026-11-06 → `2026-11-09`.
- **Status:** Agreed.

<a id="br-inst-06"></a>
#### BR-INST-06 — Strips and cascading

- **Rule:** a strip price that a source publishes is stored under the strip's own period id with `listing = Strip` and its legs in reference data; prices of the legs are never invented from it. When a venue cascades a year or quarter into shorter periods, prices before and after the cascade belong to different instruments.
- **Example:** an ICE Endex TTF Q1-27 quote is stored as `NDEX.TFM.2027-Q1`, not split into January, February and March prices.
- **Decided in:** [ADR 0014](../adr/0014-instrument-domain-model.md) §3.
- **Verified by:** review of reference data; unit test that a strip has legs and no derived leg prices.
- **Status:** Agreed.

<a id="br-inst-07"></a>
#### BR-INST-07 — Continuous series and rolls

- **Rule:** a continuous series for a tenor is the price of the contract the tenor resolves to over time. It rolls where the resolved contract changes, and roll points are shown. Prices are not back-adjusted by default; a difference- or ratio-adjusted series is a display option and is labelled as adjusted.
- **Example:** TTF `M+1` rolls from November to December 2026 after trading stops on 2026-10-29; the price jump at the roll is real and stays visible.
- **Decided in:** [ADR 0014](../adr/0014-instrument-domain-model.md) §4.
- **Verified by:** unit test of roll points for a replayed month.
- **Status:** Agreed.

### Prices

<a id="br-price-01"></a>
#### BR-PRICE-01 — Exact prices with units

- **Rule:** a price is an exact decimal, never floating point, and a multiple of the product's tick size. It carries the product's currency and unit.
- **Example:** TTF in EUR per MWh with tick 0.005; JKM in USD per MMBtu with tick 0.001; 38.4153 EUR/MWh is not a valid TTF price.
- **Decided in:** [ADR 0012](../adr/0012-message-contract-and-versioning.md) (decimal, currency and unit in the contract); [ADR 0014](../adr/0014-instrument-domain-model.md) (units and currencies per product); [domain model](../domain/model.md#invariants), invariant 3.
- **Verified by:** contract tests; ingestion validation of the tick size.
- **Status:** Agreed.

<a id="br-price-02"></a>
#### BR-PRICE-02 — Latest price

- **Rule:** the latest price of an instrument is the price with the newest venue event time. A tick that arrives late with an older event time is stored in history but does not replace the latest price.
- **Example:** ticks with event times 10:00:05 and 10:00:03 arrive in that order; the latest price stays the 10:00:05 one.
- **Decided in:** [ADR 0009](../adr/0009-event-driven-ingestion.md) (ordering is not relied upon).
- **Verified by:** integration test delivering ticks out of order.
- **Status:** Agreed.

<a id="br-price-03"></a>
#### BR-PRICE-03 — Source and age on every displayed price

- **Rule:** every price shown to a user displays its source (`LIVE` from a licensed source, `REPLAY` from the generator) and its age, so that nothing simulated or old is presented as real and current.
- **Decided in:** [ADR 0011](../adr/0011-market-data-sourcing-and-licensing.md); [ADR 0015](../adr/0015-ui-and-real-time-push.md).
- **Verified by:** UI end-to-end test.
- **Status:** Agreed.

### Freshness

<a id="br-fresh-01"></a>
#### BR-FRESH-01 — Staleness

- **Rule:** the staleness of an instrument is the time since its last tick. It is separate from adapter liveness (the adapter runs) and from latency (how fast a tick arrived).
- **Reference clock — Proposed:** measure from the venue event time of the last tick, not from the time it was received, so that a source replaying old prices after an outage is recognised as stale. To be confirmed when the metric is implemented.
- **Decided in:** [ADR 0013](../adr/0013-adapter-control-plane.md) (health model); metric in [ADR 0007](../adr/0007-observability.md).
- **Verified by:** runbook exercise in ADR 0013.
- **Status:** Agreed; reference clock Proposed.

<a id="br-fresh-02"></a>
#### BR-FRESH-02 — Staleness only while the market is open

- **Rule:** staleness is evaluated, and can raise an alert, only while the instrument's effective market status is `OPEN` (BR-FRESH-03). Outside sessions, on weekends, on venue holidays and during reported halts no staleness is counted.
- **Decided in:** [ADR 0017](../adr/0017-time-and-timezones.md); [ADR 0019](../adr/0019-market-status-events.md); [ADR 0013](../adr/0013-adapter-control-plane.md).
- **Verified by:** a replayed month with a DST weekend, a venue holiday and a halt raises no false alert ([NFR-OPS-02](nfr.md#nfr-ops-02)).
- **Status:** Agreed.

<a id="br-fresh-03"></a>
#### BR-FRESH-03 — Effective market status

- **Rule:** start from the calendar status (`OPEN` inside a session from reference data, `CLOSED` outside). A status reported by the venue after the most recent session boundary replaces it. A reported status never survives a session boundary. When several scopes report, the most specific wins: instrument over product over venue.
- **Example:** if the `OPEN` message after a halt is lost, staleness alerts are suppressed at most until the next scheduled session boundary, not indefinitely.
- **Decided in:** [ADR 0019](../adr/0019-market-status-events.md).
- **Verified by:** unit tests listed in the ADR 0019 Confirmation.
- **Status:** Agreed.

<a id="br-fresh-04"></a>
#### BR-FRESH-04 — No status from silence

- **Rule:** a source reports market status only when it actually publishes it. Status is never inferred from the absence of ticks; a source without status relies on the calendar.
- **Decided in:** [ADR 0019](../adr/0019-market-status-events.md).
- **Verified by:** code review of adapters.
- **Status:** Agreed.

<a id="br-fresh-05"></a>
#### BR-FRESH-05 — Threshold per product

- **Rule:** the staleness threshold is set per product from that product's own in-session tick gaps: p99 of the gaps × 2, at least 1 minute. Until measured, 5 minutes is a placeholder.
- **Example:** Brent front month trades almost continuously; JKM can go several minutes without a trade, so one threshold for both is wrong.
- **Decided in:** [ADR 0018](../adr/0018-latency-and-freshness-targets.md) (calibration procedure).
- **Verified by:** calibration run in ADR 0018.
- **Status:** Proposed until calibrated.

### Sources

<a id="br-src-01"></a>
#### BR-SRC-01 — Permitted sources

- **Rule:** the replay generator is the default source. A live source is enabled only after its terms of use are reviewed and recorded in `docs/legal/data-sources.md`. No adapter scrapes exchange websites.
- **Decided in:** [ADR 0011](../adr/0011-market-data-sourcing-and-licensing.md); background in [market data sources](../domain/market-data-sources.md).
- **Verified by:** pull request checklist for adapter changes ([NFR-LEGAL-01](nfr.md#nfr-legal-01)).
- **Status:** Agreed.

<a id="br-src-02"></a>
#### BR-SRC-02 — Derived statistics only

- **Rule:** licensed price data enters the repository only as derived calibration statistics (price level, volatility, tick intervals). Raw licensed series and data of former employers are never stored in the repository.
- **Decided in:** [ADR 0011](../adr/0011-market-data-sourcing-and-licensing.md); [glossary](../domain/glossary.md#prices-and-data) (calibration parameters); [market data sources](../domain/market-data-sources.md).
- **Verified by:** review of `contracts/reference/` contents.
- **Status:** Agreed.

## Traceability: ADR → business rules

| ADR | Business rules |
|---|---|
| [0007](../adr/0007-observability.md) | FRESH-01 |
| [0009](../adr/0009-event-driven-ingestion.md) | PRICE-02 |
| [0011](../adr/0011-market-data-sourcing-and-licensing.md) | PRICE-03, SRC-01, SRC-02 |
| [0012](../adr/0012-message-contract-and-versioning.md) | PRICE-01 |
| [0013](../adr/0013-adapter-control-plane.md) | FRESH-01, FRESH-02 |
| [0014](../adr/0014-instrument-domain-model.md) | TIME-01, INST-01 … INST-07, PRICE-01 |
| [0015](../adr/0015-ui-and-real-time-push.md) | PRICE-03 |
| [0017](../adr/0017-time-and-timezones.md) | TIME-01 … TIME-08, FRESH-02 |
| [0018](../adr/0018-latency-and-freshness-targets.md) | FRESH-05 |
| [0019](../adr/0019-market-status-events.md) | FRESH-02, FRESH-03, FRESH-04 |

## Open items

| Item | Decision needed |
|---|---|
| BR-FRESH-01 reference clock | Confirm venue event time as the reference when the staleness metric is implemented |
| BR-FRESH-05 thresholds | Calibration run per ADR 0018 |
| BR-TIME-08 | Becomes Agreed only if power products enter scope |
