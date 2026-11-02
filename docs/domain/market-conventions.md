# Market conventions

How exchanges divide time: trading sessions, settlement periods, peak windows and indices. Decisions on how SignalLog stores and applies these rules are in [ADR 0017](../adr/0017-time-and-timezones.md) (sections 5 and 6). Facts were checked on the dates given; anything inferred or unconfirmed is marked.

## 1. Instruments in the starter set

Source of truth: `contracts/reference/instruments.json` (added with the replay adapter). Checked 2026-10-30.

| Product | MIC | Code | Quote | Tick | Contract size | Settlement | Session (anchor zone) |
|---|---|---|---|---|---|---|---|
| Brent Crude Futures | IFEU | `BRN` | USD/bbl | 0.01 | 1,000 bbl | EFP, optional cash vs ICE Brent Index | 20:00–18:00 New York (inferred anchor) |
| Dutch TTF Natural Gas Futures | NDEX | `TFM` | EUR/MWh | 0.005 | 1 MW × hours of delivery | physical, TTF | 20:50–18:00 New York (inferred anchor) |
| JKM LNG (Platts) Futures | IFEU | `JKM` | USD/MMBtu | 0.001 | 10,000 MMBtu | cash vs Platts JKM average | 20:50–18:00 New York (inferred anchor) |
| EEX THE Natural Gas Month Futures | XEEE | `G0BM` | EUR/MWh | 0.005 | 1 MW × hours of delivery | physical, THE | 08:00–18:00 Berlin (**unverified**) |

Last trading day rules:

- **Brent:** last business day of the second month preceding the contract month (earlier if that is the business day before Christmas or New Year's Day).
- **TTF:** 18:00 CET two UK business days before the first day of the delivery month.
- **JKM:** 15th calendar day of the month before the contract month, or the preceding business day.
- **THE month:** second exchange day before the first delivery day.

## 2. Power markets: settlement periods and labels

Power is not in the current scope (oil, gas, LNG). These conventions are recorded because they shaped the time model; they become reference data if power products are added.

### European day-ahead (SDAC, EPEX SPOT)

- From delivery day **2025-10-01** the Single Day-Ahead Coupling clears prices per **15-minute** Market Time Unit: 96 periods on a normal day. On EPEX SPOT this covers 11 countries; Great Britain and Switzerland are not part of it.
- Orders of 60, 30 and 15 minutes are still accepted and matched against each other; the clearing price is per quarter-hour.
- A 60-minute price index is the arithmetic average of the four quarter-hour prices of that hour.
- Before 2025-10-01 the auction was hourly. Hourly labels count local hours from 1 to 24; on the long day hour 3 (02:00–03:00) occurs twice and is labelled `3A` and `3B`; on the short day there is no hour 3.
- **Open question:** labels of the quarter-hours inside a repeated hour on the long day (current EPEX file specifications).

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

- Half-hourly settlement periods numbered from the start of the local day (Europe/London) by **elapsed** time: SP1, SP2, …; 48 on a normal day, 46 on the short day, 50 on the long day.
- GB runs its own half-hourly day-ahead auction outside SDAC.

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

1. **Block orders** in the auction: a set of periods offered at one price (classic, linked, exclusive, loop, curtailable blocks). An order mechanism, not a separate price.
2. **Indices (Phelix-DE):** *Day Base* = arithmetic mean of day-ahead clearing prices for periods 00:00–24:00; *Day Peak* = periods from 08:00 (inclusive) to 20:00 (exclusive); *Month Peak* = the same window on weekdays only. Simple averages, not volume-weighted.
3. **Peak futures**, for example ICE German Power Financial Peak Futures: peak = every 15-minute period from 08:00 to 20:00 CET on weekdays, public holidays included; cash settlement = arithmetic mean of those German day-ahead quarter-hour prices; size 1 MW × 12 hours per weekday.

Off-peak (Belgium, Netherlands, Great Britain) = 00:00–08:00 plus 20:00–24:00 CET. The GB "EFA day" runs 23:00–23:00 UK time, which equals 00:00–24:00 CET.

DST does not affect peak windows: 08:00–20:00 never contains a transition, so a peak day always has 12 hours (48 quarter-hours). Base days have 23/24/25 hours (92/96/100 quarter-hours).

**Inferred:** exchange documents write "CET" all year; this is read as the local time of the zone (CET in winter, CEST in summer). Windows are therefore stored with the IANA zone `Europe/Berlin`, not a fixed `+01:00`.

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
| ICE session anchor zone (New York?) | Session boundaries during US/EU mismatch weeks | ICE trading-hours notices around DST changes |
| EEX continuous trading hours for gas futures | Staleness alerts for `G0BM` | EEX trading-hours document (chart not machine-readable) |
| Current EEX product code list | `G0BM` comes from a 2021 ECC circular | EEX product list |
| Quarter-hour labels on the long day (EPEX) | Report labels if power is added | EPEX SPOT sFTP file specifications |
| EEX Phelix-DE Peak futures specification | Only the ICE equivalent was checked | EEX contract specifications |
| Open, licence-clean daily price series for TTF and JKM | Calibration of the replay generator | Regulator publications (e.g. ACER) |

## Sources

- ICE, Brent Crude Futures — https://www.ice.com/products/219/Brent-Crude-Futures (checked 2026-10-30)
- ICE, Dutch TTF Natural Gas Futures — https://www.ice.com/products/27996665/Dutch-TTF-Gas-Futures (checked 2026-10-30)
- ICE, JKM LNG (Platts) Future — https://www.ice.com/products/6753280/JKM-LNG-PLATTS-Future (checked 2026-10-30)
- EEX Contract Specifications 0105a — https://www.eex.com/fileadmin/EEX/Downloads/Rules/Contract_Specifications/20261002_EEX_Contract_Spezifications_0105a_E_FINAL.pdf
- ECC Clearing Circular 13/2021 (THE product codes) — https://www.ecc.de/fileadmin/Global/News/ECC/ECC_Circulars/2021/20210324_ECC_Clearing_Circular_No._13_Further_information_related_to_German_Gas_Market_Merger_on_1_October_2021.pdf
- EPEX SPOT, 15-minute products live on day-ahead markets — https://www.epexspot.com/en/news/15-minute-products-live-epex-spot-day-ahead-markets (checked 2026-11-01)
- EPEX SPOT, 15-minute products in market coupling — https://www.epexspot.com/en/15-minute-products-market-coupling (checked 2026-11-01)
- EPEX SPOT, trading products — https://www.epexspot.com/en/tradingproducts (checked 2026-11-01)
- EPEX SPOT, description of market indices (July 2020) — https://webshop.eex-group.com/sites/default/files/2020-07/EPEX%20SPOT%20Indices%202020-07_5.pdf
- ICE, German Power Financial Peak Futures — https://www.ice.com/products/57609953/German-Power-Financial-Peak-Futures (checked 2026-11-01)
