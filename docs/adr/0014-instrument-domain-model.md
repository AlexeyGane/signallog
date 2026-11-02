# 0014 — Instrument domain model and delivery periods

| Field | Value |
|---|---|
| Status | Proposed (revision 2) |
| Date | 2026-11-01 |
| Deciders | Solution Architect, Key Developer *(one person, see README)* |
| Related | [0008](0008-data-storage.md), [0011](0011-market-data-sourcing-and-licensing.md), [0012](0012-message-contract-and-versioning.md), [0017](0017-time-and-timezones.md) |
| Traces to | [NFR-DATA-03](../requirements/nfr.md#nfr-data-03) (unambiguous instrument identity), [NFR-DATA-05](../requirements/nfr.md#nfr-data-05) (correct delivery volumes), C4 L3: Domain |
| Domain pages | [Tenors and delivery periods](../domain/tenors-and-delivery-periods.md), [Glossary](../domain/glossary.md), [Domain model](../domain/model.md) |

**Revision 2** (2026-11-01): revision 1 identified contracts only by a delivery month (`yyyy-MM`) and named a single continuous series, front month. Energy venues also list day-ahead, weekend, balance-of-week, balance-of-month, week, quarter, season and calendar-year contracts, and traders refer to them by relative labels (DA, M+1, Q+1, Cal+1). This revision adds a typed delivery period, a grammar for its identifier, and the rule that relative labels are resolved at read time and never stored.

## Context and Problem Statement

"The price of gas" is not a thing. TTF is a gas hub, not an exchange; TTF futures trade on ICE Endex (and a mirrored market on ICE Futures Europe). Each listed contract has its own delivery period and expiry, and front month rolls over time. A model that stores prices per commodity cannot answer "which contract was this?"

The delivery period is not always a month. ICE Endex lists TTF daily products for day-ahead, balance of week, weekend, Saturday, Sunday, working days next week and balance of month, next to up to 156 consecutive month contracts; quarters, seasons and calendar years trade as strips of months. EEX lists power futures as days, weekends, weeks, months, quarters and years, and delivers years and quarters by cascading into shorter periods. Some periods change length with UK bank holidays: the TTF weekend starting Friday 2026-12-25 covers four gas days. How are instruments and their delivery periods identified, and how are labels such as "day-ahead" or "M+1" handled?

## Decision Drivers

- D1 — Every price belongs to exactly one tradable contract.
- D2 — Stable identifiers usable as partition keys ([0008](0008-data-storage.md)).
- D3 — Continuous and relative series (front month, day-ahead, Cal+1) derivable, never stored as fake instruments.
- D4 — Correct units and currencies per product.
- D5 — Every delivery period traded on an in-scope venue is expressible, including periods whose length depends on holidays and DST.
- D6 — A relative label resolves to the same contract for the same instant every time, so resolution is unit-testable with real dates.

## Considered Options

**Instrument identity**

1. Venue → Product → Contract hierarchy with a composite instrument id
2. Commodity-level series (oil, gas, LNG)
3. Vendor identifiers (e.g. exchange symbols) used as-is

**Delivery period representation** (new in revision 2)

- A. Typed delivery period: a kind plus an anchor in ISO 8601 style; the extent is reference data
- B. Explicit date range in the identifier (`2026-12-25_2026-12-28`)
- C. Month only; other periods are out of scope

## Decision Outcome

**Chosen options:** 1 for identity and A for delivery periods.

```text
Venue      ICE Futures Europe | ICE Endex | EEX          (code: ISO 10383 MIC)
Product    e.g. Brent Crude Futures, Dutch TTF Natural Gas Futures, JKM LNG
           currency, unit, tick size, trading calendar, timezone, delivery rule
Contract   one delivery period of a product; kind, extent, last trading day, listing
Commodity  classification tag only: CrudeOil | NaturalGas | LNG
```

### 1. Instrument id

**Instrument id** = `{venueMic}.{productCode}.{deliveryPeriodId}`, for example `NDEX.TFM.2026-12`. MIC codes: `IFEU` (ICE Futures Europe), `NDEX` (ICE Endex), `XEEE` (EEX), from the ISO 10383 registry. The delivery period id never contains a `.`, so the instrument id splits unambiguously on the first two dots. Month ids keep the revision 1 format, so existing ids remain valid.

### 2. Delivery period kinds and identifiers

| Kind | Id format | Example | Extent |
|---|---|---|---|
| Day | `yyyy-MM-dd` | `2026-11-09` | One delivery day of the product (gas day 06:00–06:00, power day 00:00–24:00 local; [0017](0017-time-and-timezones.md)) |
| Weekend | `yyyy-MM-dd-WE` | `2026-11-07-WE` | From the first delivery day given; 2 days, or 3–4 when bank holidays adjoin |
| Balance of week | `yyyy-MM-dd-BOW` | `2026-11-04-BOW` | From the first delivery day given to the end of the working week |
| Week | `YYYY-Www` (ISO week) | `2026-W46` | Seven delivery days, Monday to Sunday |
| Working days of week | `YYYY-Www-WD` | `2026-W46-WD` | Working days of that ISO week, bank holidays excluded |
| Balance of month | `yyyy-MM-dd-BOM` | `2026-11-04-BOM` | From the first delivery day given to the end of the month |
| Month | `yyyy-MM` | `2026-12` | All delivery days of the month |
| Quarter | `yyyy-Qn` | `2027-Q1` | Three months |
| Season | `yyyy-SUM`, `yyyy-WIN` | `2027-SUM`, `2026-WIN` | Summer: April–September of the year; Winter: October of the year to March of the next |
| Gas year | `yyyy-GY` | `2026-GY` | October of the year to September of the next |
| Calendar year | `yyyy` | `2027` | January–December |

- The id names the period; the **extent** (first and last delivery day, inclusive, as `LocalDate`) is stored with the contract in reference data. Kinds whose length depends on a venue holiday calendar (Weekend, BOW, BOM, Working days) are anchored on their first delivery day, so the id is unique without encoding the holidays.
- Start and end instants are never stored: they are computed from the extent and the product's delivery rule with the tzdb, as for any delivery day ([0017](0017-time-and-timezones.md)). Volume follows BR-TIME-01: the weekend starting 2026-10-24 covers 49 hours of TTF delivery, not 48.
- A product lists only the kinds the venue lists for it. Reference data records the listed kinds per product; ingestion rejects an id whose kind the product does not list.

### 3. Listed contracts and strips

- **Listed contract:** the venue publishes prices for the period itself (TTF daily products, EEX quarters and years). It is an instrument.
- **Strip:** the venue registers the trade as a series of shorter contracts (ICE Endex TTF quarters, seasons and calendar years are strips of months). A strip price that a source publishes is stored under the strip's period id with `listing = Strip`, and the reference data records its legs; a strip is never decomposed into invented leg prices.
- **Cascading** (EEX): when a year or quarter contract reaches delivery it is replaced by its quarters and months. Cascading is recorded as reference data (`cascadesInto`); prices before and after the cascade belong to different instruments.

### 4. Relative tenors are labels, not instruments

**Relative tenors** — `DA`, `WE`, `BOW`, `WDNW`, `BOM`, `M+n`, `Q+n`, `SUM+n`/`WIN+n`, `GY+n`, `Cal+n`, and `FM` (front month, the same as `M+1`) — are resolved at read time by a domain service:

```text
ITenorResolver.Resolve(product, tenor, asOf: Instant) -> InstrumentId?
```

- The resolver takes the trading day that contains `asOf` ([0017](0017-time-and-timezones.md)), the product's listed contracts and their last trading days.
- `M+n`, `Q+n`, seasons, gas years and `Cal+n` resolve to the **n-th period of that kind, ordered by start of delivery, that is still tradable at `asOf`** (listed and not past its last trading day; for a strip, every leg tradable). Example: on 2026-11-02 the TTF November 2026 contract expired on 2026-10-29, so `M+1` for TTF is `NDEX.TFM.2026-12`; for Brent, whose January 2027 contract trades until 2026-11-30, `M+1` is `IFEU.BRN.2027-01`.
- `DA`, `WE`, `BOW`, `WDNW` and `BOM` resolve by the venue's rule for that product (for TTF: the day-ahead traded on a Friday is the gas day of the following Monday). These rules are product reference data, not code constants.
- A **continuous series** for a tenor is the sequence of prices of the resolved instrument over time. Roll points are where the resolved instrument changes; they are shown in charts. Prices are not back-adjusted by default; a difference or ratio adjustment is a display option and is labelled as adjusted.
- Neither relative tenors nor continuous series are ever stored as instruments or in `PriceTick.instrumentId`.

### 5. Out of scope in this revision

Power day-ahead **auctions** (EPEX SPOT, SDAC) publish one price per market time unit of a delivery day, not one price per contract. They need a different event shape and are deferred to a separate ADR if power enters scope. Within-day gas is deferred for the same reason.

### Storage

- Reference data lives in the `instruments` container ([0008](0008-data-storage.md)) and in `contracts/reference/` as seed data.
- The partition key `{instrumentId}|{yyyy-MM}` of `price-ticks` is unchanged; the month bucket comes from the tick's event time, so a short-dated contract occupies one or two partitions.

### Consequences

- Good, because the model matches how the market actually works and is defensible in an interview with someone from the domain.
- Good, because ids are stable and high-cardinality, suitable as partition keys, and revision 1 month ids are unchanged.
- Good, because day-ahead, weekend and balance-of-month prices fit the same model as months, and DST-dependent volumes come from the same rule as delivery days.
- Bad, because holiday-dependent extents need a venue holiday calendar as reference data (already required for staleness, [0017](0017-time-and-timezones.md)).
- Bad, because resolution rules must be implemented and tested per product and tenor kind.

### Confirmation

- Unit tests for period id parsing and formatting (round trip for every kind; a `.` in a period id is rejected).
- Unit tests for extents and hours with real dates (Europe/Amsterdam gas days, 1 MW):

| Product | Period | Expected |
|---|---|---|
| TTF | `2026-11-07-WE` | 2 gas days, 48 MWh |
| TTF | `2026-10-24-WE` | 2 gas days, 49 MWh (gas day 2026-10-24 is 25 h) |
| TTF | `2026-12-25-WE` | 4 gas days (25 and 28 December are UK bank holidays), 96 MWh |
| TTF | `2026-10` / `2026-11` / `2027-03` | 745 / 720 / 743 MWh |
| TTF | `2027-Q1` | 2,159 MWh |
| TTF | `2026-WIN` / `2027-SUM` / `2026-GY` | 4,368 / 4,392 / 8,760 MWh |

- Unit tests for tenor resolution: TTF `M+1` at 2026-11-02 → `NDEX.TFM.2026-12`; Brent `M+1` at 2026-11-02 → `IFEU.BRN.2027-01`; TTF `DA` on Friday 2026-11-06 → gas day `2026-11-09`.
- Every tick's `instrumentId` resolves to a reference-data entry whose product lists that period kind (validated in ingestion).

## Pros and Cons of the Options

### 1. Venue → Product → Contract
- Good, because it is correct and extensible.
- Bad, because there is more reference data to maintain.

### 2. Commodity-level series
- Good, because it is simple.
- Bad, because it mixes contracts and has wrong partitioning characteristics.

### 3. Vendor symbols as-is
- Good, because no mapping is needed.
- Bad, because symbol formats differ per venue and vendor and change over time.

### A. Typed delivery period, extent in reference data
- Good, because ids are short, readable by traders (`2027-Q1`, `2026-WIN`) and ISO 8601 where ISO has a form.
- Good, because holiday-dependent extents do not leak into the id.
- Bad, because the id alone does not give the extent; reference data is required to compute volume.

### B. Explicit date range in the id
- Good, because the extent is self-describing.
- Bad, because the kind is lost (a two-day range can be a weekend or a BOW) and ids become long and unfamiliar to domain users.

### C. Month only
- Good, because it needs no new code.
- Bad, because day-ahead and weekend prices, the most watched short-term gas prices, cannot be represented.

## More Information

- ICE Endex, Dutch TTF Natural Gas Daily Futures — contract specification: https://www.ice.com/api/productguide/spec/45436633/pdf (checked 2026-11-01)
- ICE Endex, Dutch TTF Natural Gas Futures — contract specification: https://www.ice.com/api/productguide/spec/27996665/pdf (checked 2026-11-01)
- EEX, Power Futures — maturities and cascading: https://eex.com/en/markets/power/power-futures (checked 2026-11-01)
- Worked examples and open questions: [Tenors and delivery periods](../domain/tenors-and-delivery-periods.md)
