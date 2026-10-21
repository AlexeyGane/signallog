# 0014 — Instrument domain model

| Field | Value |
|---|---|
| Status | Proposed |
| Date | 2026-10-18 |
| Deciders | Solution Architect, Key Developer *(one person, see README)* |
| Related | [0008](0008-data-storage.md), [0011](0011-market-data-sourcing-and-licensing.md), [0012](0012-message-contract-and-versioning.md), [0017](0017-time-and-timezones.md) |
| Traces to | NFR-DATA-03 (unambiguous instrument identity), C4 L3: Domain |

## Context and Problem Statement

"The price of gas" is not a thing. TTF is a gas hub, not an exchange; TTF futures trade on ICE Endex (and a mirrored market on ICE Futures Europe). Each listed contract has its own delivery period and expiry, and front month rolls over time. A model that stores prices per commodity cannot answer "which contract was this?" How are instruments identified?

## Decision Drivers

- D1 — Every price belongs to exactly one tradable contract.
- D2 — Stable identifiers usable as partition keys ([0008](0008-data-storage.md)).
- D3 — Continuous series (front month) derivable, never stored as a fake instrument.
- D4 — Correct units and currencies per product.

## Considered Options

1. Venue → Product → Contract hierarchy with a composite instrument id
2. Commodity-level series (oil, gas, LNG)
3. Vendor identifiers (e.g. exchange symbols) used as-is

## Decision Outcome

**Chosen option:** Option 1.

```text
Venue      ICE Futures Europe | ICE Endex | EEX          (code: ISO 10383 MIC)
Product    e.g. Brent Crude Futures, Dutch TTF Natural Gas Futures, JKM LNG
           currency, unit, tick size, trading calendar, timezone
Contract   one delivery period of a product, e.g. Dec-2026; expiry date
Commodity  classification tag only: CrudeOil | NaturalGas | LNG
```

- **Instrument id** = `{venueMic}.{productCode}.{deliveryPeriod}` (e.g. `<MIC>.<code>.2026-12`). MIC codes for the three venues are to be confirmed from the ISO 10383 registry before Accepting.
- **Continuous series** (front month, M+1) are computed views over contracts using roll rules per product; they are never stored as instruments.
- Reference data lives in the `instruments` container ([0008](0008-data-storage.md)) and in `contracts/reference/` as seed data.

### Consequences

- Good, because the model matches how the market actually works and is defensible in an interview with someone from the domain.
- Good, because ids are stable and high-cardinality, suitable as partition keys.
- Bad, because roll rules must be implemented per product.

### Confirmation

- Unit tests for roll rules per product.
- Every tick's `instrumentId` resolves to a reference-data entry (validated in ingestion).

## Pros and Cons of the Options

### Venue → Product → Contract
- Good, because it is correct and extensible.
- Bad, because there is more reference data to maintain.

### Commodity-level series
- Good, because it is simple.
- Bad, because it mixes contracts and has wrong partitioning characteristics.

### Vendor symbols as-is
- Good, because no mapping is needed.
- Bad, because symbol formats differ per venue and vendor and change over time.
