# Time and delivery

Decisions: [ADR 0017](../adr/0017-time-and-timezones.md). Terms: [glossary](glossary.md). Recorded from the design discussion of 2026-11-01.

## 1. The principle

> **Instants are stored in UTC. Rules are stored in local time with an IANA zone. Labels of periods are dates without time.**

UTC makes every stored moment unambiguous, but it does not remove daylight saving from the domain: sessions, gas days, power days and market reports are all defined by local clocks. Those rules are resolved to UTC for a specific date at the moment they are used, never in advance.

## 2. DST transitions used in the examples

| Date | Zone | Local change | UTC instant |
|---|---|---|---|
| 2026-03-29 | Europe/Berlin, Europe/Amsterdam | 02:00 CET → 03:00 CEST (gap 02:00–02:59) | 01:00Z |
| 2026-03-29 | Europe/London | 01:00 GMT → 02:00 BST (gap 01:00–01:59) | 01:00Z |
| 2026-10-25 | Europe/Berlin, Europe/Amsterdam | 03:00 CEST → 02:00 CET (02:00–02:59 twice) | 01:00Z |
| 2026-10-25 | Europe/London | 02:00 BST → 01:00 GMT (01:00–01:59 twice) | 01:00Z |
| 2026-11-01 | America/New_York | 02:00 EDT → 01:00 EST | 06:00Z |

The EU and the UK change at the same UTC instant but at different local times. The US changes on different dates, which creates weeks when ICE sessions move by one hour relative to London (about three weeks in March, one week from late October to early November).

## 3. Gaps and overlaps

Policy: lenient resolution (NodaTime `InZoneLeniently`).

**Overlap — Berlin, 2026-10-25.** Local 02:00–02:59 happens twice:

| UTC | Offset | Berlin clock |
|---|---|---|
| 00:00Z | +02:00 | 02:00 (first) |
| 00:30Z | +02:00 | **02:30 (first)** |
| 01:00Z | +01:00 | 02:00 (second) |
| 01:30Z | +01:00 | **02:30 (second)** |
| 02:00Z | +01:00 | 03:00 |

"02:30 on 25 October" resolves to the **earlier** occurrence, `00:30Z`. An event scheduled at 02:30 happens once, not twice.

**Gap — Berlin, 2026-03-29.** Local 02:00–02:59 does not exist:

| UTC | Offset | Berlin clock |
|---|---|---|
| 00:30Z | +01:00 | 01:30 |
| 01:00Z | +02:00 | 03:00 (clock jumps from 02:00) |
| 01:30Z | +02:00 | 03:30 |

"02:30 on 29 March" is shifted forward by the length of the gap: 03:30 CEST, `01:30Z`.

```csharp
DateTimeZone berlin = DateTimeZoneProviders.Tzdb["Europe/Berlin"];
new LocalDateTime(2026, 10, 25, 2, 30).InZoneLeniently(berlin).ToInstant(); // 2026-10-25T00:30:00Z
new LocalDateTime(2026, 3, 29, 2, 30).InZoneLeniently(berlin).ToInstant();  // 2026-03-29T01:30:00Z
new LocalDateTime(2026, 10, 25, 2, 30).InZoneStrictly(berlin);              // throws AmbiguousTimeException
```

None of SignalLog's current boundaries (06:00, 08:00, 18:00, 20:00, 22:00, 00:00, 00:50) fall into a transition window; the policy is a safety net for future rules.

## 4. Delivery volume — BR-TIME-01

> Delivered energy = capacity × elapsed duration of the delivery period between its two UTC boundaries.

Gas delivery days run from 06:00 to 06:00 local time. The transition at 02:00/03:00 therefore falls into the gas day **labelled with the previous date**:

| Gas day | Starts (local → UTC) | Ends (local → UTC) | Length | 1 MW delivers |
|---|---|---|---|---|
| 2026-03-28 (short) | 06:00 CET → 05:00Z | 06:00 CEST next day → 04:00Z | 23 h | 23 MWh |
| 2026-06-15 (normal) | 06:00 CEST → 04:00Z | 06:00 CEST → 04:00Z | 24 h | 24 MWh |
| 2026-10-24 (long) | 06:00 CEST → 04:00Z | 06:00 CET next day → 05:00Z | 25 h | 25 MWh |

A month is the sum of its days: October 2026 = 31 × 24 + 1 = 745 MWh per MW; March 2026 = 743 MWh per MW.

The rule is the same for power with a 00:00–24:00 delivery day, and for any settlement period: counting real periods in UTC gives 23/24/25 hours, 46/48/50 half-hours, 92/96/100 quarter-hours.

### Computing it: hourly slots in UTC

```csharp
public sealed record DeliverySlot(Instant StartUtc, Duration Length, ZonedDateTime StartLocal);

public static IEnumerable<DeliverySlot> HourlySlots(LocalDate gasDay, DateTimeZone zone)
{
    LocalTime dayStart = new(6, 0);
    Instant start = gasDay.At(dayStart).InZoneLeniently(zone).ToInstant();
    Instant end = gasDay.PlusDays(1).At(dayStart).InZoneLeniently(zone).ToInstant();

    for (Instant t = start; t < end; t += Duration.OneHour)
    {
        yield return new DeliverySlot(t, Duration.OneHour, t.InZone(zone));
    }
}
```

Each UTC instant maps to exactly one local time, so no gap or overlap ever needs resolving inside the loop; only the two 06:00 boundaries are resolved, and they are never ambiguous.

### "How much gas was delivered between 02:00 and 03:00 local time?"

Group the UTC slots by their local start hour.

**Long day — gas day 2026-10-24, Berlin, 1 MW:**

| Slot (UTC) | Local start | Offset |
|---|---|---|
| 23:00Z (24 Oct) | 01:00 | +02:00 |
| **00:00Z (25 Oct)** | **02:00** | **+02:00** |
| **01:00Z (25 Oct)** | **02:00** | **+01:00** |
| 02:00Z (25 Oct) | 03:00 | +01:00 |

Two slots start at local 02:00 → **2 MWh**; 1 MWh in the first (+02:00), 1 MWh in the second (+01:00). The day totals 25 slots.

**Short day — gas day 2026-03-28, Berlin, 1 MW:**

| Slot (UTC) | Local start | Offset |
|---|---|---|
| 00:00Z (29 Mar) | 01:00 | +01:00 |
| **01:00Z (29 Mar)** | **03:00** | **+02:00** |

No slot starts at local 02:00 → **0 MWh**: the hour did not exist. The day totals 23 slots.

**At an instant ("at 02:30")** the question is about flow, not volume: 1 MW at every instant of delivery. On the long day local 02:30 is two instants; on the short day it does not exist, and the system answers so rather than silently shifting it.

## 5. Trading sessions and trading days

- Sessions are stored as local times in an anchor zone and resolved per trading date.
- ICE sessions do not share one anchor zone. **Inferred** from ICE product pages read on 2026-10-30 and 2026-11-07: Brent is anchored to New York (20:00–18:00, next day), TTF and JKM to London (00:50–22:00). Evidence and the open check are in [market conventions](market-conventions.md#11-session-anchor-zones). The earlier inference that all ICE energy sessions follow New York time held for Brent only.
- In the weeks when US and UK clocks change on different dates, a New York-anchored session moves by one hour against London and a London-anchored one against New York.
- The 22-hour Brent session (20:00–18:00 New York) lasts 21 or 23 hours on a transition night.
- A tick belongs to the trading day of the session containing it: Sunday 22:30 New York time belongs to Monday.
- Daily bars are keyed by trading day, not by UTC date.

## 6. Where conversions happen

```text
Storage (Cosmos DB)            UTC only: ticks, slots, daily bars. No local labels.
SignalLog.Domain (NodaTime)    Session, delivery-day and settlement-calendar logic. Pure functions, unit tested.
Query API                      Applies a market convention at read time and returns labelled rows.
UI / exports                   Show the market label and local time with offset; charts use UTC on the axis.
```

## 7. Library choice in brief

NodaTime is used inside the domain because it separates instants from local times in the type system, ships resolvers for gaps and overlaps, and embeds the IANA database so that Windows, Linux and CI give identical answers. Rule changes by governments affect every option equally (someone must ship new tzdb data); with NodaTime the update is a reviewed pull request with the DST test suite, not an operating-system patch outside our control. Full reasoning and the rejected options are in [ADR 0017](../adr/0017-time-and-timezones.md).
