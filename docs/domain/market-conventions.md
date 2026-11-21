# Market conventions

How exchanges divide time: trading sessions, settlement periods, peak windows and indices. Decisions on how SignalLog stores and applies these rules are in [ADR 0017](../adr/0017-time-and-timezones.md) (sections 5 and 6). Terms are explained in the [glossary](glossary.md); the sources are in the [bibliography](../references/index.md), with the date each was checked. Anything inferred or unconfirmed is marked.

## 1. Instruments in the starter set

Source of truth: `contracts/reference/instruments.json` (added with the replay adapter). The rows follow the exchanges' product pages and specifications.[^ice-brn][^ice-tfm][^ice-jkm][^eex-contract-specifications-0105a]

| Product | MIC | Code | Quote | Tick | Contract size | Settlement | Session (anchor zone) |
|---|---|---|---|---|---|---|---|
| Brent Crude Futures | IFEU | `BRN` | USD/[bbl](../standards/concepts-and-sources.md#units) | 0.01 | 1,000 bbl | EFP, optional cash vs ICE Brent Index | 20:00–18:00 New York (**Inferred** anchor, section 1.1) |
| Dutch TTF Natural Gas Futures | NDEX | `TFM` | EUR/MWh | 0.005 | 1 MW × hours of delivery | physical, TTF | 00:50–22:00 London (**Inferred** anchor, section 1.1) |
| JKM LNG (Platts) Futures | IFEU | `JKM` | USD/MMBtu | 0.001 | 10,000 MMBtu | cash vs Platts JKM average[^spglobal-jkm] | 00:50–22:00 London (**Inferred** anchor, section 1.1) |
| EEX THE Natural Gas Month Futures | XEEE | `G0BM`[^ecc-circular-2021-13] | EUR/MWh | 0.005 | 1 MW × hours of delivery | physical, THE[^trading-hub-europe-2021-10-01] | 08:00–18:00 Berlin (**unverified**) |

Last trading day rules:

- **Brent:** last business day of the second month preceding the contract month (earlier if that is the business day before Christmas or New Year's Day).[^ice-brn]
- **TTF:** 18:00 CET two UK business days before the first day of the delivery month.[^ice-tfm]
- **JKM:** 15th calendar day of the month before the contract month, or the preceding business day.[^ice-jkm]
- **THE month:** second exchange day before the first delivery day.[^eex-contract-specifications-0105a]

### 1.1 Session anchor zones

ICE product pages give each session in New York, London and Singapore time without naming the zone it is defined in.[^ice-brn][^ice-tfm][^ice-jkm] Twice a year US and UK clocks change on different dates ([time and delivery](time-and-delivery.md#2-dst-transitions-used-in-the-examples)); in those weeks only the anchor column keeps its value. The pages were read on 2026-10-30, when London was already on GMT and New York still on EDT (four hours apart), and on 2026-11-07, when both were on standard time (five hours apart):

| Product | New York, 2026-10-30 | New York, 2026-11-07 | London, 2026-11-07 | Column that stayed fixed |
|---|---|---|---|---|
| Brent (`BRN`) | 20:00–18:00 | 20:00–18:00 | 01:00–23:00 | New York |
| TTF (`TFM`) | 20:50–18:00 | 19:50–17:00 | 00:50–22:00 | London |
| JKM (`JKM`) | 20:50–18:00 | 19:50–17:00 | 00:50–22:00 | London |

A London-anchored 00:50 open is 20:50 in New York while the clocks are four hours apart and 19:50 when they are five hours apart, which is what the TTF and JKM pages showed; the Brent open stayed at 20:00 New York. **Inferred:** Brent is anchored to New York, TTF and JKM to London, because ICE does not state the anchor. The record of 2026-10-30 had all three in New York time; the TTF and JKM rows were wrong. London and Amsterdam change clocks on the same dates, so for TTF the two zones cannot be told apart; London is used because ICE publishes London times.

The pages state the Sunday open in different zones: Brent at 23:00 London (pre-open 22:00), TTF and JKM at 17:50 ET (pre-open 17:40). Both are recorded as published; which zone a Sunday open follows in a mismatch week is an open question (section 5).

## 2. Power markets: settlement periods and labels

Power is not in the current scope (oil, gas, LNG). These conventions are recorded because they shaped the time model; they become reference data if power products are added.

### European day-ahead (SDAC, EPEX SPOT)

- From delivery day **2025-10-01** the Single Day-Ahead Coupling clears prices per **15-minute** Market Time Unit: 96 periods on a normal day. On EPEX SPOT this covers 11 countries; Great Britain and Switzerland are not part of it.[^epex-2025-09-30-15-minute]
- 60-minute contracts remain available to trading members; the clearing price is per quarter-hour.[^epex-2025-09-30-15-minute]
- **Unverified:** whether EPEX SPOT publishes a 60-minute index after 2025-10-01 and how. One data vendor computes EPEX 60-minute values as the average of the four quarter-hour prices.[^montel-15-minute-sdac]
- Before 2025-10-01 the auction was hourly. Hourly labels count local hours from 1 to 24; on the long day hour 3 (02:00–03:00) occurs twice and is labelled `3A` and `3B`; on the short day there is no hour 3. Quarter-hours inside the repeated hour are labelled `3A Q1` to `3A Q4` and `3B Q1` to `3B Q4`.[^epex-sftp-specifications]

Example, Berlin, delivery day 2026-10-25 (25 hours, 22:00Z on 24 Oct to 23:00Z on 25 Oct), hourly labels:

| Hour | UTC | Local |
|---|---|---|
| 2 | 23:00Z | 01:00 (+02:00) |
| 3A | 00:00Z | 02:00 (+02:00) |
| 3B | 01:00Z | 02:00 (+01:00) |
| 4 | 02:00Z | 03:00 (+01:00) |
| 24 | 22:00Z | 23:00 (+01:00) |

Delivery day 2026-03-29 (23 hours, 23:00Z on 28 Mar to 22:00Z on 29 Mar): hour 2 = 00:00Z (01:00 CET), no hour 3, hour 4 = 01:00Z (03:00 CEST).

### Great Britain settlement periods

- Half-hourly settlement periods numbered from the start of the local day (Europe/London) by **elapsed** time: SP1, SP2, …; 48 on a normal day, 46 on the short day, 50 on the long day.[^elexon-2023-10-29-long-day][^elexon-2022-03-27-short-day]
- GB runs its own half-hourly day-ahead auction outside SDAC.[^epex-trading-products][^epex-2025-09-30-15-minute]

Example, long day 2026-10-25 (02:00 BST → 01:00 GMT at 01:00Z):

| Period | UTC | Local |
|---|---|---|
| SP3 | 00:00Z | 01:00 BST (+01:00) |
| SP4 | 00:30Z | 01:30 BST (+01:00) |
| SP5 | 01:00Z | 01:00 GMT (+00:00), repeated hour |
| SP6 | 01:30Z | 01:30 GMT (+00:00), repeated hour |
| SP7 | 02:00Z | 02:00 GMT |
| SP50 | 23:30Z | 23:30 GMT |

Short day 2026-03-29: SP2 = 00:30Z (00:30 GMT), SP3 = 01:00Z (02:00 BST), …, SP46.

## 3. Peak, base and off-peak

There is no separate "peak price" in the day-ahead auction: each period has one clearing price per bidding zone, and peak periods are expensive because of supply and demand, not because of product rules. "Peak" exists in three other forms, all built on the same period prices:

1. **Block orders** in the auction: a set of periods offered at one price (classic, linked, exclusive, loop, curtailable blocks).[^epex-trading-products] An order mechanism, not a separate price.
2. **Indices (Phelix-DE):** *Day Base* = arithmetic mean of day-ahead clearing prices for periods 00:00–24:00; *Day Peak* = periods from 08:00 (inclusive) to 20:00 (exclusive); *Month Peak* = the same window on weekdays only. Simple averages, not volume-weighted.[^epex-indices-2020-07]
3. **Peak futures**, for example ICE German Power Financial Peak Futures: peak = every 15-minute period from 08:00 to 20:00 CET on weekdays, public holidays included; cash settlement = arithmetic mean of those German day-ahead quarter-hour prices; size 1 MW × 12 hours per weekday.[^ice-german-power-peak]

Off-peak (Belgium, Netherlands, Great Britain) = 00:00–08:00 plus 20:00–24:00 CET. The GB "EFA day" runs 23:00–23:00 UK time, which equals 00:00–24:00 CET.[^epex-indices-2020-07]

DST does not affect peak windows: 08:00–20:00 never contains a transition, so a peak day always has 12 hours (48 quarter-hours). Base days have 23/24/25 hours (92/96/100 quarter-hours).

**Inferred:** exchange documents write "CET" all year; this is read as the local time of the zone (CET in winter, CEST in summer). Windows are therefore stored with the [IANA zone](../standards/concepts-and-sources.md#tzdb) `Europe/Berlin`, not a fixed `+01:00`.

## 4. How SignalLog stores conventions

A market convention is reference data with effective-dated versions (ADR 0017, section 5). Planned file `contracts/reference/market-conventions.json`:

```json
{
  "conventionId": "epex-de-day-ahead",
  "timeZone": "Europe/Berlin",
  "deliveryDayStart": "00:00",
  "versions": [
    { "validFrom": "2015-01-01", "periodLength": "PT60M", "labelScheme": "epex-hourly" },
    { "validFrom": "2025-10-01", "periodLength": "PT15M", "labelScheme": "epex-quarter-hourly" }
  ],
  "windows": [
    { "name": "Base", "from": "00:00", "to": "24:00", "days": "All" },
    { "name": "Peak", "from": "08:00", "to": "20:00", "days": "Mon-Fri" }
  ]
}
```

- `validFrom` is a local delivery date, because markets announce changes by delivery day.
- The first version's `validFrom` above is a placeholder; the real start of hourly trading is not relevant to SignalLog's data and need not be researched.
- Periods are enumerated from the convention at read time by an `ISettlementCalendar`; exchange-provided labels, when received, are stored as received.

## 5. Open questions

| Question | Why it matters | Where to look |
|---|---|---|
| Confirm the inferred session anchors (section 1.1) and the zone of the Sunday opens | Session boundaries and staleness alerts during US/UK mismatch weeks | ICE product pages between 2027-03-14 and 2027-03-28, when US clocks have changed and UK clocks have not; ICE trading-hours notices |
| EEX continuous trading hours for gas futures | Staleness alerts for `G0BM` | EEX trading-hours document (chart not machine-readable) |
| Current EEX product code list | `G0BM` comes from a 2021 ECC circular; the 2026 contract specifications were read without their table of codes | EEX product list |
| EEX Phelix-DE Peak futures specification | Only the ICE equivalent was checked | EEX contract specifications |
| Open, licence-clean daily price series for TTF and JKM | Calibration of the replay generator | Regulator publications (e.g. ACER) |

[^ice-brn]: [ICE, Brent Crude Futures](../references/index.md#ice-brn).
[^ice-tfm]: [ICE, TTF futures on ICE Endex](../references/index.md#ice-tfm).
[^ice-jkm]: [ICE, JKM LNG (Platts) Future](../references/index.md#ice-jkm).
[^eex-contract-specifications-0105a]: [EEX contract specifications 0105a](../references/index.md#eex-contract-specifications-0105a), sections 1.2.1.1 (1 MW), 1.2.5 (volume), B.1 (tick) and C.1.2 (last trading day).
[^spglobal-jkm]: [S&P Global, JKM explained](../references/index.md#spglobal-jkm): the Platts benchmark for spot LNG cargoes delivered ex-ship into Japan, South Korea, China and Taiwan.
[^ecc-circular-2021-13]: [ECC Clearing Circular 13/2021](../references/index.md#ecc-circular-2021-13).
[^trading-hub-europe-2021-10-01]: [Trading Hub Europe, 2021-10-01](../references/index.md#trading-hub-europe-2021-10-01): the German market area THE started on that day.
[^epex-2025-09-30-15-minute]: [EPEX SPOT, 2025-09-30](../references/index.md#epex-2025-09-30-15-minute).
[^montel-15-minute-sdac]: [Montel, transition to 15-minute day-ahead auctions](../references/index.md#montel-15-minute-sdac).
[^epex-sftp-specifications]: [EPEX SPOT sFTP file specifications](../references/index.md#epex-sftp-specifications).
[^elexon-2023-10-29-long-day]: [Elexon, long clock change day 2023](../references/index.md#elexon-2023-10-29-long-day): 50 settlement periods, SP3 and SP4 at 01:00 and 01:30 BST.
[^elexon-2022-03-27-short-day]: [Elexon, short clock change day 2022](../references/index.md#elexon-2022-03-27-short-day): 46 settlement periods, SP3 at 02:00 BST.
[^epex-trading-products]: [EPEX SPOT, trading products](../references/index.md#epex-trading-products): block orders; GB half-hourly day-ahead auction.
[^epex-indices-2020-07]: [EPEX SPOT Indices, 2020-07](../references/index.md#epex-indices-2020-07), sections 2.3 and 2.7 to 2.9.
[^ice-german-power-peak]: [ICE, German Power Financial Peak Futures](../references/index.md#ice-german-power-peak).
