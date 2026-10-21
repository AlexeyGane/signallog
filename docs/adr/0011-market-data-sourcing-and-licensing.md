# 0011 — Market data sourcing and licensing

| Field | Value |
|---|---|
| Status | Proposed |
| Date | 2026-10-18 |
| Deciders | Solution Architect, Key Developer *(one person, see README)* |
| Related | [0012](0012-message-contract-and-versioning.md), [0013](0013-adapter-control-plane.md), [0014](0014-instrument-domain-model.md) |
| Traces to | NFR-LEGAL-01 (licensed data only), NFR-DEMO-01 (demo always works) |

## Context and Problem Statement

The platform monitors futures prices for crude oil, natural gas and LNG on ICE Futures Europe, ICE Endex and EEX. Exchange market data is licensed. Real-time and delayed data are normally distributed under exchange or vendor agreements, and website terms of use commonly restrict automated extraction and redistribution. A portfolio project that scrapes exchange websites demonstrates a legal and operational risk, not engineering maturity. It is also fragile: page changes break it, and a demo can fail at the worst moment. Where does price data come from?

## Decision Drivers

- D1 — Only data whose terms of use permit this use.
- D2 — The demo must work at any time, including weekends and outside trading hours.
- D3 — The adapter architecture must be real: pluggable sources behind one interface.
- D4 — Zero or near-zero data cost ([0000](0000-cost-optimization-strategy.md)).

## Considered Options

1. Scrape exchange websites
2. Licensed real-time feed from an exchange or vendor
3. **Pluggable adapters:** a Replay/Simulator adapter as the default source, plus adapters for sources whose terms permit API access
4. Synthetic data only

## Decision Outcome

**Chosen option:** Option 3.

- `IMarketDataSource` is the single abstraction; each venue adapter implements it.
- **Replay/Simulator adapter** (default in the demo environment): replays recorded or synthetic tick sequences per instrument with realistic timing, trading sessions ([0017](0017-time-and-timezones.md)) and occasional faults (gaps, duplicates, late ticks) to exercise resilience.
- **Live adapters** are enabled only for sources whose terms have been reviewed and recorded in `docs/legal/data-sources.md` (source, URL of terms, permitted use, date reviewed). An API key, if required, lives in Key Vault ([0005](0005-identity-and-access.md)).
- No adapter scrapes exchange websites.

### Consequences

- Good, because the project demonstrates awareness of data licensing, a real concern in commodity and trading IT.
- Good, because the demo is deterministic and works around the clock; fault injection makes the resilience features visible.
- Bad, because the displayed prices may be simulated; the UI marks the source of every price (`LIVE` / `REPLAY`) so nothing is presented as real when it is not.

### Confirmation

- `docs/legal/data-sources.md` exists and every enabled live adapter has an entry.
- UI shows the source badge per instrument.

## Pros and Cons of the Options

### Scraping
- Good, because it is free and looks real.
- Bad, because it likely breaches terms of use, is brittle and is a red flag for employers.

### Licensed feed
- Good, because it is real, correct and legal.
- Bad, because of cost and contracts far outside a portfolio budget.

### Pluggable adapters with replay
- Good, because it is legal, deterministic and architecturally honest.
- Bad, because data may be simulated.

### Synthetic only
- Good, because it is simplest.
- Bad, because the adapter abstraction is never tested against a real external API.
