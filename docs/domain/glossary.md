# Glossary

The [ubiquitous language](../standards/concepts-and-sources.md#ubiquitous-language) of SignalLog. Terms are used with exactly these meanings in code (type and member names), documents and discussions. Code names are given in `monospace` where a type exists or is planned.

## Markets and instruments

| Term | Definition |
|---|---|
| **Venue** (`Venue`) | A trading venue (exchange or segment) identified by its MIC. Examples: ICE Futures Europe, ICE Endex, European Energy Exchange. |
| **MIC** | Market Identifier Code, [ISO 10383](https://www.iso20022.org/market-identifier-codes): a four-letter code that identifies a venue worldwide. Used by regulators (MiFID II reporting), FIX and market-data vendors. `IFEU` = ICE Futures Europe, `NDEX` = ICE Endex, `XEEE` = EEX. |
| **Product** (`Product`) | A standardised contract type on a venue: Brent Crude Futures, Dutch TTF Natural Gas Futures. Defines currency, unit, tick size, contract size, session, delivery rules. Identified by a product code unique within its venue. |
| **Product code** | The venue's short code for a product: `BRN` (Brent, ICE), `TFM` (TTF, ICE Endex), `JKM` (JKM LNG, ICE), `G0BM` (THE gas month, EEX). Not globally unique; combined with the MIC it is. |
| **Contract** | One delivery period of a product, for example Brent January 2027 or the TTF weekend starting 2026-11-07. Has a period kind, an extent (first and last delivery day) and an expiry (last trading day). |
| **Instrument** (`InstrumentId`) | What a price refers to: venue + product + delivery period. Identifier format `{MIC}.{productCode}.{deliveryPeriodId}`, for example `NDEX.TFM.2026-12` or `NDEX.TFM.2026-11-09` (ADR 0014). |
| **Continuous series** | The prices of the contract a relative tenor resolves to, over time; it rolls from one contract to the next. Never stored as an instrument (ADR 0014). |
| **Tenor** | The length and position of a delivery period: day, weekend, month, quarter, season, year. Used both for absolute periods (`2027-Q1`) and relative labels (`Q+1`). |
| **Delivery period id** (`DeliveryPeriodId`) | The text form of an absolute delivery period: `2026-11-09`, `2026-11-07-WE`, `2026-11-04-BOM`, `2026-W46`, `2026-12`, `2027-Q1`, `2026-WIN`, `2026-GY`, `2027`. Contains no `.` (ADR 0014). |
| **Extent** | First and last delivery day of a period, inclusive. Stored with the contract because weekend, BOW and BOM lengths depend on bank holidays. |
| **Relative tenor** (`RelativeTenor`) | A label that points to a different contract over time: `DA`, `WE`, `BOM`, `M+n`, `Q+n`, `Cal+n`. Resolved at read time by `ITenorResolver`; never stored. |
| **Front month** (`FM`, `M+1`) | The first month contract still tradable at a given instant. Not the next calendar month: on 2026-11-02 it is December 2026 for TTF and January 2027 for Brent. |
| **Day-ahead** (`DA`) | For TTF, the gas day of the next weekday after UK bank holidays. For power, also the name of the daily auction (out of scope). |
| **Weekend** (`WE`) | Gas delivery from Saturday 06:00 to Monday 06:00, extended to 3–4 days by adjoining UK bank holidays. |
| **Balance of week / month** (`BOW`, `BOM`) | The remaining delivery days of the current week or month, from a start set by the venue rule. |
| **Working days next week** (`WDNW`) | Gas delivery Monday 06:00 to Saturday 06:00 of next week, bank holidays excluded. |
| **Season** | Summer: April–September. Winter: October to March of the following year. |
| **Gas year** | October to September of the following year. |
| **Strip** | A set of consecutive contracts traded at one price, for example a TTF quarter as three months. Its legs are the underlying contracts. |
| **Cascading** | EEX power mechanism by which a year or quarter contract is replaced by its shorter periods as delivery approaches. |
| **Roll** | The instant at which a relative tenor starts resolving to a different contract. Shown in charts; prices are not back-adjusted by default. |
| **Commodity** | Classification tag only: `CrudeOil`, `NaturalGas`, `LNG`. |
| **Hub** | A pricing or delivery location, not an exchange. European gas hubs are **virtual trading points**: gas changes owner inside a transmission network, not at a physical site. TTF (Netherlands) and THE (Germany) are virtual gas hubs; contracts on them trade on exchanges. |
| **TTF** | Title Transfer Facility: the virtual trading point of the Dutch gas transmission network, operated by Gasunie Transport Services (GTS). ICE Endex TTF futures are delivered by transfer of rights in gas at this point. The main gas price benchmark of continental Europe. |
| **THE** | Trading Hub Europe: the virtual trading point of the single German gas market area, operating since 2021-10-01, when the GASPOOL and NetConnect Germany market areas merged. |
| **JKM** | Japan Korea Marker: a daily price assessment by S&P Global Commodity Insights (Platts) for spot LNG cargoes delivered ex-ship (DES) into Japan, South Korea, China and Taiwan. **Not a hub**: nothing is delivered at "JKM"; JKM futures on ICE settle in cash against the Platts JKM average. |
| **DES** | Delivered Ex-Ship: the seller delivers the LNG cargo to the buyer's import terminal and bears the transport risk until unloading. |
| **Tick size** | The minimum price increment of a product, for example EUR 0.005/MWh for TTF. |
| **Contract size** | The quantity of one lot: 1,000 barrels (Brent), 10,000 MMBtu (JKM), 1 MW for every hour of the delivery period (TTF, THE). |
| **Settlement method** | Physical delivery (TTF, THE), delivery by Exchange of Futures for Physical with optional cash settlement (Brent), or cash settlement against an index (JKM). |
| **Last trading day** | The day a contract stops trading, defined by a product rule, for example "last business day of the second month preceding the contract month" (Brent). |

## Prices and data

| Term | Definition |
|---|---|
| **Tick** (`PriceTick`) | One observed price for one instrument at one instant: price, currency, unit, price type, venue timestamp, source kind. |
| **Price type** | `LAST` (last trade), `SETTLE` (official settlement price), `BID`, `ASK`. |
| **Settlement price** | The official end-of-day price published by the venue, used for margining and cash settlement. |
| **Source kind** | `LIVE` (from a licensed live source) or `REPLAY` (generated by the replay adapter). Shown on every price in the UI (ADR 0011). |
| **Replay** | Deterministic synthetic price generation calibrated on real reference statistics, used as the default data source (ADR 0011). |
| **Calibration parameters** | Statistics derived from a permitted public source (price level, volatility) that drive the replay generator. Raw licensed price series are never stored in the repository. |
| **Reference data** | Facts about venues, products and market conventions, transcribed from public specifications with source and date. No prices. |
| **Staleness** | Time since the last tick of an instrument, evaluated only while its effective market status is `OPEN` (ADR 0013, ADR 0017, ADR 0019). |
| **Market status** (`MarketStatus`) | A venue-reported state of a venue, product or instrument: `PRE_OPEN`, `OPEN`, `PAUSED`, `CLOSED`. Published as event `signallog.market.status.v1` (ADR 0019). |
| **Effective status** | The calendar status from trading sessions, replaced by a reported market status received since the last session boundary. Never survives a session boundary (ADR 0019). |
| **Index** | An aggregate of market prices over a window, for example Phelix-DE Day Peak = arithmetic mean of German day-ahead prices for periods from 08:00 to 20:00. |

## Time and delivery

| Term | Definition |
|---|---|
| **Instant** (`Instant`) | A point on the global time line, independent of any time zone. Stored as UTC. |
| **Local time** (`LocalDateTime`, `LocalTime`) | A reading of a wall clock without a zone. Ambiguous on its own. |
| **Time zone** (`DateTimeZone`) | An IANA zone such as `Europe/Berlin`: the rules that map local time to instants, including daylight saving. Never a fixed offset. |
| **Offset** | The difference between local time and UTC at a given instant: +01:00 (CET), +02:00 (CEST). Changes twice a year in zones with DST. |
| **DST transition** | The instant when a zone's offset changes. In the EU and UK it happens at 01:00 UTC on the last Sunday of March and of October; in the US on the second Sunday of March and the first Sunday of November. |
| **Gap** (skipped time) | Local times that do not exist on a spring-forward day, for example 02:00–02:59 in Berlin on 2026-03-29. |
| **Overlap** (ambiguous time) | Local times that occur twice on a fall-back day, for example 02:00–02:59 in Berlin on 2026-10-25. |
| **Lenient resolution** | The policy for gaps and overlaps (ADR 0017): a time in a gap moves forward by the length of the gap; a time in an overlap takes the earlier occurrence. |
| **Short day / long day** | A delivery day of 23 or 25 hours because it contains a DST transition. |
| **Delivery day** | The period over which a daily quantity is delivered. Gas: 06:00–06:00 local time. Power: 00:00–24:00 local time. |
| **Gas day** | The gas delivery day, 06:00 to 06:00 local time (CET/CEST). The gas day *labelled* 2026-10-24 runs from 06:00 on 24 October to 06:00 on 25 October and lasts 25 hours. |
| **Delivery period** | The span covered by a contract: a day, a month, a quarter, a season or a year, made of delivery days. |
| **Delivery slot** (`DeliverySlot`) | One period of delivery enumerated in UTC, with its local start time for labelling. The unit in which volumes are computed. |
| **Settlement period / MTU** | Market Time Unit: the smallest period for which a market clears a price. 60, 30 or 15 minutes. The European day-ahead auction uses 15 minutes from delivery 2025-10-01; GB uses 30 minutes. |
| **Trading session** (`TradingSession`) | The hours during which a product can be traded, defined in local time of an anchor zone, for example 20:00–18:00 New York time for ICE Brent futures and 00:50–22:00 London time for ICE TTF and JKM futures ([anchor zones](market-conventions.md#11-session-anchor-zones)). |
| **Trading day** (`LocalDate`) | The business date a session belongs to. An ICE session opening on Sunday evening belongs to Monday's trading day. |
| **Market convention** (`MarketConvention`) | Versioned reference data describing how a market divides time: zone, delivery-day start, period length, label scheme, windows. |
| **Window** | A named subset of periods in local time: Base (all periods), Peak (08:00–20:00, weekdays for monthly products), Off-peak. |
| **Settlement calendar** (`ISettlementCalendar`) | Domain service that enumerates the periods of a delivery day for a market convention and labels them (`SP1`–`SP50`, `3A`/`3B`). |
| **Projection** | A read-time view computed from UTC data and a convention, for example an EPEX-style hourly report. Never stored as the source of truth. |
| **tzdb** | The IANA Time Zone Database. NodaTime embeds a copy; its version is recorded in reports. |

## Volumes and units

| Term | Definition |
|---|---|
| **MW** | Megawatt: a rate of energy flow (capacity). |
| **MWh** | Megawatt-hour: an amount of energy. 1 MW for 1 hour = 1 MWh. |
| **Business rule** (`BR-*`) | A rule of the domain that holds in any implementation and that a domain expert can check, identified as `BR-<AREA>-<NN>`. Catalogued in [business rules](../requirements/business-rules.md). |
| **BR-TIME-01** | Delivered energy = capacity × elapsed duration of the delivery period. 1 MW delivers 24 / 23 / 25 MWh on a normal / short / long day ([ADR 0017](../adr/0017-time-and-timezones.md), [catalogue](../requirements/business-rules.md#br-time-01)). |
| **bbl** | Barrel of crude oil, 42 US gallons = 158.987 litres ([NIST SP 811](https://www.nist.gov/pml/special-publication-811)). Brent prices are quoted in USD per barrel. |
| **MMBtu** | Million British thermal units, an energy unit for gas and LNG. 1 MMBtu = 10⁶ Btu (International Table Btu, 1 Btu = 1,055.056 J, [NIST SP 811](https://www.nist.gov/pml/special-publication-811)) ≈ 1.055 GJ ≈ 293.07 kWh. JKM is quoted in USD per MMBtu. |

## Sources

- Engineering and methodology concepts used across the documents, with their primary sources: [Concepts and their sources](../standards/concepts-and-sources.md).
- Units: NIST Special Publication 811, *Guide for the Use of the International System of Units*, Appendix B — https://www.nist.gov/pml/special-publication-811
- Venue codes: ISO 10383 Market Identifier Codes — https://www.iso20022.org/market-identifier-codes
- Market-specific definitions (gas day, products, hubs) cite their sources on the domain pages: [market conventions](market-conventions.md), [tenors and delivery periods](tenors-and-delivery-periods.md), [market data sources](market-data-sources.md).
