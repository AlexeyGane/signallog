# 0018 — Latency and freshness targets: provisional values and calibration

| Field | Value |
|---|---|
| Status | Accepted 2026-11-05 |
| Date | 2026-11-02 |
| Deciders | Solution Architect, Key Developer *(both roles held by one person — see README)* |
| Supersedes | — |
| Related | [0006](0006-compute-hosting.md), [0007](0007-observability.md), [0009](0009-event-driven-ingestion.md), [0013](0013-adapter-control-plane.md), [0015](0015-ui-and-real-time-push.md), [0017](0017-time-and-timezones.md) |
| Traces to | [NFR-PERF-01](../requirements/nfr.md#nfr-perf-01), [NFR-PERF-02](../requirements/nfr.md#nfr-perf-02), [NFR-OPS-01](../requirements/nfr.md#nfr-ops-01), [NFR-OPS-02](../requirements/nfr.md#nfr-ops-02); Azure Boards User Story "Latency and freshness baseline" *(to be created, AB# pending)* |

## Context and Problem Statement

ADRs 0007 and 0015 refer to "the NFR latency target", and ADR 0007 alerts on "staleness > threshold", but no ADR fixed a number. When the NFR catalogue was written (2026-11-01), the numbers for tick-to-store latency, tick-to-screen latency, trace coverage and freshness alerting were filled in as engineering estimates and marked *Proposed*.

These numbers are **not taken from a standard**. No industry standard defines latency for a price-monitoring system that shows prices to people: trading-system latency budgets (microseconds) answer a different question, and exchange rules on delayed data govern licensing, not engineering. The system has not been deployed, so nothing has been measured.

The questions are: which values apply until measurements exist, where each value comes from, and how and when the values are replaced by measured ones without reopening this decision.

## Decision Drivers

- D1 — Every target is traceable to its origin: an estimate, a vendor constraint or a measurement. A reviewer can tell which is which.
- D2 — Targets exist from the start, so that tests, dashboards and alerts are built against something concrete.
- D3 — Targets are replaced by measured values through a defined, repeatable procedure, not by opinion.
- D4 — Staleness thresholds reflect market liquidity per product, not one number for all products.
- D5 — Targets fit the budget ([0000](0000-cost-optimization-strategy.md)): no premium tiers or always-ready instances only to meet an estimate.

## Considered Options

1. **Provisional estimates now, calibrated by a baseline measurement** with a fixed procedure; values live in the NFR catalogue.
2. **No targets until measured**; NFRs stay without numbers.
3. **External benchmark**: adopt published figures from another system or vendor as targets.

## Decision Outcome

**Chosen option:** Option 1, because it gives concrete targets now (D2), labels them honestly (D1) and defines how they become measured values (D3).

### Weighted evaluation

*Expert judgement (one assessor), not a measurement.* Rebuilt on 2026-11-04 under the [weighted evaluation method](README.md#weighted-evaluation-method). The first version scored "Effort", which is not a driver, and left out D4 and D5; its weights were chosen after the options were known.

Weights (swing weighting, fixed before scoring):

| Criterion | Driver | Weight | Why this weight |
|---|---|---|---|
| Traceable origin | D1 | 30 | The reason for this ADR: numbers of unknown origin are what a review board rejects first |
| Targets usable now | D2 | 25 | Without targets, tests and alerts have nothing to check; second only to honesty about origin |
| Defined path to measured values | D3 | 25 | Without it, estimates become permanent; as important as having targets at all |
| Staleness per product | D4 | 10 | Matters, but concerns one NFR out of four |
| Fits the budget | D5 | 10 | No option needs paid tiers by itself; the swing is small |

Scale anchors:

| Criterion | 1 | 3 | 5 |
|---|---|---|---|
| Traceable origin | Origin hidden or misleading | Origin named, no reasoning | Every value labelled estimate, vendor constraint or measurement, with reasoning |
| Targets usable now | No numbers | Numbers for some NFRs | A number for every NFR |
| Defined path to measured values | No reason to ever replace the values | Replacement intended, procedure not written | Repeatable procedure written down |
| Staleness per product | One threshold for all products | Per-product structure, values not derived | Per-product values derived from observed liquidity |
| Fits the budget | Needs paid tiers to meet targets | Might push towards paid tiers | No cost effect |

| Criterion (weight) | 1. Provisional + calibration | 2. No targets until measured | 3. External benchmark |
|---|---|---|---|
| Traceable origin (30) | 5 | 5 ¹ | 2 |
| Targets usable now (25) | 5 | 1 | 3 |
| Defined path to measured values (25) | 5 | 3 | 1 |
| Staleness per product (10) | 4 ² | 3 | 1 |
| Fits the budget (10) | 5 | 5 | 3 |
| **Weighted score** | **4.90** | **3.30** | **2.00** |

¹ Vacuously: with no numbers there is nothing of unknown origin. ² Per-product structure now; derived values only after calibration.

Drivers not scored: none.

Sensitivity: Option 1 scores at least as well as both alternatives on every criterion, so no choice of weights changes the order. Per the method, what the table leaves out: effort, which is not a driver here. Option 1 costs one deliberate measurement run and its repetition after major changes; Option 2 costs nothing now. That cost is recorded under *Consequences* and is the honest argument against the decision.

### Provisional values and their origin

| NFR | Target (provisional) | Origin | What makes it weak |
|---|---|---|---|
| PERF-02 tick-to-store | p95 ≤ 2 s warm; p99 ≤ 10 s including cold starts | **Estimate.** Five hops (APIM → ingress function → Service Bus → ingestion function → Cosmos DB), each assumed at tens to a few hundred milliseconds when warm, total below 1 s; 2 s leaves headroom of about 2×. Cold starts on Flex Consumption ([0006](0006-compute-hosting.md)) take seconds, hence a separate p99. | Per-hop latencies are assumed, not measured. |
| PERF-01 tick-to-screen | p95 ≤ 3 s; p99 ≤ 5 s | **Estimate.** PERF-02 plus SignalR push and browser render ([0015](0015-ui-and-real-time-push.md)). Anchor: must stay below the replay tick interval (a few seconds), otherwise the screen falls more than one tick behind and shows an outdated price as current. | Tick interval of the replay adapter is not yet fixed. |
| OPS-01 trace coverage | ≥ 99 % of stored ticks traceable | **Estimate.** | Conflicts with trace sampling in [0007](0007-observability.md); see *Trace coverage and sampling* below. |
| OPS-02 staleness threshold | 5 min, per product | **Placeholder.** | Depends on liquidity: Brent front month trades almost continuously; JKM can go minutes without a trade. One number for all products is wrong by design. |
| OPS-02 alert delay | alert ≤ 5 min after the threshold is breached, in session | **Vendor constraint.** Azure Monitor alert rules evaluate at most once per minute; log ingestion averages under 10 s but can take minutes, and Microsoft recommends metric alerts when log alerts arrive more than about 4 minutes late or when detecting absent data ([troubleshoot log alerts](https://learn.microsoft.com/azure/azure-monitor/alerts/alerts-troubleshoot-log), [ingestion time](https://learn.microsoft.com/azure/azure-monitor/logs/data-ingestion-time)). 5 min = 1 min evaluation + aggregation window + ingestion margin. | Ingestion delay in our workspace is not measured. |

### Calibration procedure

The User Story "Latency and freshness baseline" runs this procedure once the Azure environment exists ([0016](0016-environments-and-infrastructure-as-code.md)), and again after any change listed under *Review triggers*.

1. Deploy the current `main` to `dev` with replay as the only source and trace sampling **off**.
2. Run replay for 24 hours, including at least one session open and close per product.
3. Record p50, p95 and p99 of `signallog.tick.age_seconds` at storage (PERF-02) and of the browser render metric (PERF-01), separately for warm periods and for the first tick after an idle period (cold start).
4. Per product, record the distribution of gaps between consecutive ticks during sessions. For live sources, use their observed gaps; for replay, the configured interval.
5. Set each target:
   - Latency: observed p95 × 1.5, rounded up to the next 0.5 s; p99 likewise from observed p99. If the result is worse than the provisional value, investigate before accepting it.
   - PERF-01 must also stay below the product's typical tick interval; if it does not, record the gap as a defect, not as a looser target.
   - Staleness threshold per product: observed p99 of in-session gaps × 2, at least 1 minute.
6. Write the measured values into the [NFR catalogue](../requirements/nfr.md) with the date and the commit measured, and set the NFR status to *Agreed*. Store the query and results in `docs/requirements/baselines/` (planned).

The procedure is the decision; the numbers are data. Measured values change the NFR catalogue, not this ADR.

### Trace coverage and sampling

[ADR 0007](0007-observability.md) samples successful request traces to stay inside the Application Insights daily cap. With sampling, at most the sampled share of ticks has a stored trace, so "≥ 99 % of stored ticks traceable" cannot be met as worded. The two are reconciled as follows:

- **Propagation** (always measured): ≥ 99 % of stored ticks carry a valid W3C `traceparent` in the stored document, proving that context crosses every hop. This is the NFR-OPS-01 target in normal operation.
- **Retained traces** (measured during calibration only): with sampling off, ≥ 99 % of stored ticks have a complete end-to-end trace in Application Insights.

### Alerting mechanics for freshness

- Staleness is published as the metric `signallog.instrument.staleness_seconds` ([0007](0007-observability.md)) and alerted by a **metric alert**, not a log search alert, because metric alerts are near real-time and Microsoft recommends them for detecting missing data ([VM alerts guidance](https://learn.microsoft.com/azure/azure-monitor/vm/monitor-virtual-machine-alerts)).
- Evaluation frequency 1 minute, window 5 minutes, one dimension per instrument; the threshold is per product.
- The metric is emitted only while the instrument's effective market status is `OPEN` — the session from reference data ([0017](0017-time-and-timezones.md)), overridden by venue-reported status ([0019](0019-market-status-events.md)) — so the alert cannot fire outside sessions or during a venue halt.

### Consequences

- Good, because every number in the NFR catalogue states where it came from, which is what a review board asks first.
- Good, because tests, dashboards and alerts can be built now and keep working when the numbers change.
- Good, because the conflict between trace sampling and trace coverage is resolved explicitly.
- Bad, because it costs effort that Option 2 does not: one deliberate 24-hour measurement run, repeated after every review trigger.
- Bad, because until calibration the targets may be wrong in either direction; a too-strict target produces failing checks, a too-loose one hides problems.
- Risk: the baseline runs on replay, whose tick pattern is cleaner than a live source (mitigation: repeat calibration for each live adapter before enabling it in `prod`, [0011](0011-market-data-sourcing-and-licensing.md)).
- Risk: the Azure environment is delayed by the subscription billing issue, so provisional values stay in place longer (mitigation: no gate depends on them until the baseline story is done).

### Confirmation

- The NFR catalogue shows, for PERF-01, PERF-02, OPS-01 and OPS-02, either *Proposed* with a reference to this ADR, or *Agreed* with a measurement date and commit.
- The baseline results and queries are in the repository.
- The freshness alert is a metric alert with a per-product threshold (checked in the Bicep for alerts).

## Pros and Cons of the Options

### 1. Provisional estimates with calibration
- Good, because work can start against concrete numbers.
- Good, because the replacement of estimates by measurements is planned, not left to chance.
- Bad, because it requires one deliberate measurement run and its repetition after major changes.

### 2. No targets until measured
- Good, because nothing unproven is written down.
- Bad, because tests and alerts have nothing to check against, and "we will measure later" tends to become "never".

### 3. External benchmark
- Good, because the numbers look authoritative.
- Bad, because no published benchmark matches this architecture and use case; borrowed numbers hide that they were not derived from this system.

## More Information

Review triggers (rerun the calibration procedure):

- a hop is added to or removed from the ingestion path, or a hosting plan changes ([0006](0006-compute-hosting.md), [0009](0009-event-driven-ingestion.md), [0010](0010-api-management-ingestion-gateway.md));
- a live adapter is enabled ([0011](0011-market-data-sourcing-and-licensing.md));
- an Agreed target is breached for two consecutive weeks.

Evidence:

- Azure Monitor, create or edit a log search alert rule (evaluation frequency from 1 minute): https://learn.microsoft.com/azure/azure-monitor/alerts/alerts-create-log-alert-rule
- Azure Monitor, log data ingestion time: https://learn.microsoft.com/azure/azure-monitor/logs/data-ingestion-time
- Azure Monitor, troubleshoot log search alerts (prefer metric alerts for latency-sensitive and missing-data alerts): https://learn.microsoft.com/azure/azure-monitor/alerts/alerts-troubleshoot-log
- Azure Monitor, VM alerts guidance (metric alerts recommended to detect absence of a heartbeat): https://learn.microsoft.com/azure/azure-monitor/vm/monitor-virtual-machine-alerts
