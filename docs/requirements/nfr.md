# Non-functional requirements

The catalogue of quality requirements referenced by the [ADRs](../adr/README.md). Writing rules and status values are in the [requirements README](README.md).

**Origin.** The identifiers below were introduced in the ADRs' *Traces to* fields when the ADRs were rewritten in October 2026; this catalogue (2026-11-01) is the first place where they are defined. Where two ADRs used one identifier with different short labels, the definition below covers both meanings (noted under *Labels in ADRs*). Targets that no ADR had fixed are marked **Proposed**; where they come from and how they are replaced by measured values is decided in [ADR 0018](../adr/0018-latency-and-freshness-targets.md).

## Summary

| ID | Title | Area / quality characteristic | Target (short) | Status | Addressed by |
|---|---|---|---|---|---|
| [NFR-COST-01](#nfr-cost-01) | Monthly run cost | Cost optimization (WAF) | ≤ USD 20/month; ≤ USD 30 in demo window | Agreed | [0000](../adr/0000-cost-optimization-strategy.md), [0006](../adr/0006-compute-hosting.md), [0007](../adr/0007-observability.md), [0008](../adr/0008-data-storage.md) |
| [NFR-PERF-01](#nfr-perf-01) | Tick-to-screen latency | Performance efficiency — time behaviour | p95 ≤ 3 s | Proposed | [0015](../adr/0015-ui-and-real-time-push.md), [0018](../adr/0018-latency-and-freshness-targets.md) |
| [NFR-PERF-02](#nfr-perf-02) | Tick-to-store latency | Performance efficiency — time behaviour | p95 ≤ 2 s warm; p99 ≤ 10 s with cold starts | Proposed | [0006](../adr/0006-compute-hosting.md), [0007](../adr/0007-observability.md), [0018](../adr/0018-latency-and-freshness-targets.md) |
| [NFR-SEC-01](#nfr-sec-01) | No static secrets | Security — confidentiality | 0 secrets in code, config or pipelines for Azure access | Agreed | [0005](../adr/0005-identity-and-access.md), [0010](../adr/0010-api-management-ingestion-gateway.md) |
| [NFR-SEC-02](#nfr-sec-02) | Least privilege | Security — authorization | Every role assignment declared in IaC at the narrowest scope | Agreed | [0005](../adr/0005-identity-and-access.md), [0015](../adr/0015-ui-and-real-time-push.md), [0016](../adr/0016-environments-and-infrastructure-as-code.md) |
| [NFR-SEC-03](#nfr-sec-03) | Supply-chain security | Security — integrity | No known high/critical vulnerability merged; dependencies and actions monitored | Agreed | [0002](../adr/0002-source-control-platform.md), [0004](../adr/0004-ci-cd-platform.md) |
| [NFR-SEC-04](#nfr-sec-04) | Input validation at the boundary | Security — integrity | 100 % of ingress messages schema-validated before enqueue | Agreed | [0010](../adr/0010-api-management-ingestion-gateway.md) |
| [NFR-REL-01](#nfr-rel-01) | No tick loss | Reliability — fault tolerance | 0 accepted ticks lost | Agreed | [0009](../adr/0009-event-driven-ingestion.md) |
| [NFR-REL-02](#nfr-rel-02) | Resilience policies | Reliability — fault tolerance | Timeout, retry with jitter and circuit breaker on every upstream call | Agreed | [0013](../adr/0013-adapter-control-plane.md) |
| [NFR-OPS-01](#nfr-ops-01) | End-to-end tracing | Operational excellence — observability | ≥ 99 % of stored ticks carry trace context end to end | Proposed | [0007](../adr/0007-observability.md), [0018](../adr/0018-latency-and-freshness-targets.md) |
| [NFR-OPS-02](#nfr-ops-02) | Data freshness alerting | Operational excellence — monitoring | Alert ≤ 5 min after staleness breach while open; 0 alerts out of session or during venue halts | Proposed | [0007](../adr/0007-observability.md), [0013](../adr/0013-adapter-control-plane.md), [0017](../adr/0017-time-and-timezones.md), [0018](../adr/0018-latency-and-freshness-targets.md), [0019](../adr/0019-market-status-events.md) |
| [NFR-OPS-03](#nfr-ops-03) | Operator can stop and start a source | Operational excellence — operability | ≤ 2 min, no deployment | Agreed | [0013](../adr/0013-adapter-control-plane.md) |
| [NFR-MNT-01](#nfr-mnt-01) | Reviewability | Maintainability — analysability | 100 % of changes to `main` via PR with green checks | Agreed | [0002](../adr/0002-source-control-platform.md) |
| [NFR-MNT-02](#nfr-mnt-02) | Backward-compatible evolution | Maintainability — modifiability | No consumer breaks on a minor contract version | Agreed | [0012](../adr/0012-message-contract-and-versioning.md) |
| [NFR-DATA-01](#nfr-data-01) | Idempotent processing | Reliability — data integrity | N deliveries of one event → exactly 1 stored tick | Agreed | [0008](../adr/0008-data-storage.md), [0009](../adr/0009-event-driven-ingestion.md), [0012](../adr/0012-message-contract-and-versioning.md) |
| [NFR-DATA-02](#nfr-data-02) | History retention | Functional suitability — completeness | Raw ticks 90 days; daily bars indefinitely | Agreed | [0008](../adr/0008-data-storage.md) |
| [NFR-DATA-03](#nfr-data-03) | Unambiguous instrument identity | Functional suitability — correctness | 100 % of stored ticks resolve to one contract | Agreed | [0014](../adr/0014-instrument-domain-model.md) |
| [NFR-DATA-04](#nfr-data-04) | Unambiguous timestamps | Functional suitability — correctness | 100 % of stored and transported timestamps are UTC instants | Agreed | [0017](../adr/0017-time-and-timezones.md) |
| [NFR-DATA-05](#nfr-data-05) | Correct delivery volumes on DST days | Functional suitability — correctness | Volumes equal capacity × elapsed hours on 23/24/25-hour days | Agreed | [0014](../adr/0014-instrument-domain-model.md), [0017](../adr/0017-time-and-timezones.md) |
| [NFR-LEGAL-01](#nfr-legal-01) | Licensed data only | Compliance | 0 sources enabled without a recorded terms review | Agreed | [0011](../adr/0011-market-data-sourcing-and-licensing.md) |
| [NFR-GOV-01](#nfr-gov-01) | Requirement-to-release traceability | Governance | 100 % of merged PRs linked to a work item | Agreed | [0003](../adr/0003-application-lifecycle-management.md) |
| [NFR-DOC-01](#nfr-doc-01) | Public, versioned documentation | Maintainability — documentation | Docs built strictly and published from `main` | Agreed | [0001](../adr/0001-documentation-platform.md) |
| [NFR-DEMO-01](#nfr-demo-01) | Demo always works | Reliability — availability (demo) | Demo runs with no live source; smoke test green before every demo | Agreed | [0011](../adr/0011-market-data-sourcing-and-licensing.md) |
| [NFR-DEL-01](#nfr-del-01) | Automated, repeatable deployment and environments | Operational excellence — deployment | Environment from scratch with 0 manual portal steps | Agreed | [0004](../adr/0004-ci-cd-platform.md), [0016](../adr/0016-environments-and-infrastructure-as-code.md) |

## Definitions

### Cost

<a id="nfr-cost-01"></a>
#### NFR-COST-01 — Monthly run cost

- **Scenario:** in any calendar month of normal operation, all Azure resources of the `dev` and `prod` environments together incur charges.
- **Target:** ≤ USD 20 per month in normal operation; ≤ USD 30 per month in a declared demo window. Allocation per component is in [ADR 0000](../adr/0000-cost-optimization-strategy.md).
- **Verification:** Azure Cost Management budget at USD 20 with actual-cost alerts at 50 %, 80 % and 100 % and a forecast alert at 100 %; a separate USD 30 budget enabled for the demo window; monthly cost review against the ADR 0000 allocation.
- **Status:** Agreed (target set in ADR 0000).

### Performance

<a id="nfr-perf-01"></a>
#### NFR-PERF-01 — Tick-to-screen latency

- **Scenario:** an adapter publishes a tick while a user has the price page open; the system is warm (no cold start in the path).
- **Target:** p95 ≤ 3 s, p99 ≤ 5 s from the CloudEvents `time` set by the adapter to the price being rendered in the browser, measured over one hour of replay. **Proposed** — engineering estimate; origin and calibration in [ADR 0018](../adr/0018-latency-and-freshness-targets.md).
- **Verification:** end-to-end test in `dev` named in [ADR 0015](../adr/0015-ui-and-real-time-push.md): a replayed tick appears in the browser within the target; the browser reports render time as a custom metric.
- **Status:** Proposed.

<a id="nfr-perf-02"></a>
#### NFR-PERF-02 — Tick-to-store latency

- **Scenario:** an adapter publishes a tick; the ingestion function stores it.
- **Target:** p95 ≤ 2 s while warm; p99 ≤ 10 s including Flex Consumption cold starts; measured as `signallog.tick.age_seconds` at the moment of storage ([ADR 0007](../adr/0007-observability.md)). **Proposed** — engineering estimate; origin and calibration in [ADR 0018](../adr/0018-latency-and-freshness-targets.md).
- **Verification:** Application Insights query over a 24-hour replay run; metric alert when p95 over 15 minutes exceeds 5 s.
- **Status:** Proposed.

### Security

<a id="nfr-sec-01"></a>
#### NFR-SEC-01 — No static secrets

- **Scenario:** a workload or pipeline needs to access an Azure resource.
- **Target:** access uses managed identities or OpenID Connect workload identity federation; 0 client secrets, connection strings with keys, or SAS tokens in code, configuration or GitHub secrets for Azure access. Third-party API keys, when unavoidable, live only in Key Vault ([ADR 0005](../adr/0005-identity-and-access.md), [ADR 0011](../adr/0011-market-data-sourcing-and-licensing.md)).
- **Verification:** GitHub secret scanning with push protection; IaC review that disables local (key) authentication on Service Bus, Cosmos DB and Storage where supported; periodic check that the app registrations have no client secrets.
- **Status:** Agreed.

<a id="nfr-sec-02"></a>
#### NFR-SEC-02 — Least privilege

- **Scenario:** an identity (workload, pipeline, operator, user of the web UI) performs an action.
- **Target:** every Azure role assignment is declared in Bicep at the narrowest scope that works (resource rather than resource group, resource group rather than subscription); no workload identity holds Owner or Contributor; UI administration endpoints require the admin role ([ADR 0015](../adr/0015-ui-and-real-time-push.md)).
- **Verification:** IaC review in the pull request; quarterly comparison of `az role assignment list` with the Bicep declarations.
- **Status:** Agreed.

<a id="nfr-sec-03"></a>
#### NFR-SEC-03 — Supply-chain security

- **Scenario:** a dependency (NuGet package, GitHub Action) has a published vulnerability or is changed upstream.
- **Target:** no pull request merges with a known high or critical vulnerability (NuGet audit `NU1903`/`NU1904` fail the build); Dependabot monitors NuGet and GitHub Actions; secret scanning and push protection are on; CodeQL runs on pull requests ([ADR 0002](../adr/0002-source-control-platform.md), [ADR 0004](../adr/0004-ci-cd-platform.md)).
- **Verification:** CI build (NuGet audit, `TreatWarningsAsErrors`); repository security settings; CodeQL workflow.
- **Known gap:** third-party actions are pinned to major tags (`@v5`), not to commit SHAs. Pinning by SHA is recommended by GitHub for third-party actions; to be decided when the deploy workflow is added.
- **Status:** Agreed.

<a id="nfr-sec-04"></a>
#### NFR-SEC-04 — Input validation at the boundary

- **Scenario:** a producer sends a message to the ingestion gateway.
- **Target:** 100 % of messages are validated against the JSON Schema of their contract version before they are enqueued; an invalid message is rejected with HTTP 400 and a reason, is never enqueued, and is logged ([ADR 0010](../adr/0010-api-management-ingestion-gateway.md), [ADR 0012](../adr/0012-message-contract-and-versioning.md)).
- **Verification:** contract tests with valid and invalid samples per schema version; integration test against the ingress function.
- **Status:** Agreed.

### Reliability

<a id="nfr-rel-01"></a>
#### NFR-REL-01 — No tick loss

- **Scenario:** the ingestion consumer is unavailable or fails while producers keep publishing.
- **Target:** 0 accepted ticks lost. A tick is *accepted* once the ingress returns 202; after that it is either stored or in the dead-letter queue, where it raises an alert.
- **Verification:** chaos test from [ADR 0009](../adr/0009-event-driven-ingestion.md): stop the ingestion function for 30 minutes, restart it, reconcile published and stored counts; alert on dead-letter count > 0.
- **Status:** Agreed.

<a id="nfr-rel-02"></a>
#### NFR-REL-02 — Resilience policies

- **Scenario:** an upstream source is slow, returns errors or is down.
- **Target:** every outbound call from an adapter has a timeout, retry with exponential backoff and jitter, and a circuit breaker (`Microsoft.Extensions.Http.Resilience`); a failing adapter does not affect other adapters; policy parameters change without redeployment ([ADR 0013](../adr/0013-adapter-control-plane.md)).
- **Verification:** unit tests with a fault-injecting handler; heartbeat shows circuit state.
- **Status:** Agreed.

### Operability

<a id="nfr-ops-01"></a>
#### NFR-OPS-01 — End-to-end tracing

- **Scenario:** an operator investigates one tick.
- **Target:** in normal operation, ≥ 99 % of stored ticks carry a valid W3C `traceparent` that was propagated from the adapter through the gateway, Service Bus and ingestion (CloudEvents distributed tracing extension). During calibration, with sampling off, ≥ 99 % of stored ticks also have a complete end-to-end trace in Application Insights. Split into two measures because trace sampling ([ADR 0007](../adr/0007-observability.md)) makes full trace retention impossible in normal operation ([ADR 0018](../adr/0018-latency-and-freshness-targets.md)). **Proposed** percentage.
- **Verification:** query over stored documents for the `traceparent` field; Application Insights query joining stored `eventId` with traces during the 24-hour calibration run.
- **Status:** Proposed.

<a id="nfr-ops-02"></a>
#### NFR-OPS-02 — Data freshness alerting

- **Labels in ADRs:** "data freshness alerting" ([0007](../adr/0007-observability.md)); "staleness only during sessions" ([0017](../adr/0017-time-and-timezones.md)). Both are this requirement.
- **Scenario:** an instrument stops receiving ticks.
- **Target:** an alert fires within 5 minutes after the instrument's staleness exceeds its threshold (5 minutes as a placeholder until the per-product threshold is measured) **while its effective market status is `OPEN`** (trading session from reference data, overridden by venue-reported status, [0019](../adr/0019-market-status-events.md)); 0 alerts fire outside sessions, on weekends, on venue holidays or during a reported venue halt. Implemented as a metric alert evaluated every minute over a 5-minute window. **Proposed** — thresholds and their calibration in [ADR 0018](../adr/0018-latency-and-freshness-targets.md).
- **Verification:** replay a full month including a DST weekend and a venue holiday and count alerts (confirmation in [ADR 0017](../adr/0017-time-and-timezones.md)); runbook exercise from [ADR 0013](../adr/0013-adapter-control-plane.md).
- **Status:** Proposed.

<a id="nfr-ops-03"></a>
#### NFR-OPS-03 — Operator can stop and start a source

- **Scenario:** an operator must stop a misbehaving source or start it again.
- **Target:** the operator stops or starts a source from the admin UI without a deployment; the change takes effect within 2 minutes (function app restart included) and is recorded with the operator's identity.
- **Verification:** runbook exercise from [ADR 0013](../adr/0013-adapter-control-plane.md): stop, observe heartbeat stop and staleness alert, restart, observe recovery.
- **Status:** Agreed.

### Maintainability

<a id="nfr-mnt-01"></a>
#### NFR-MNT-01 — Reviewability

- **Scenario:** a change is proposed to `main`.
- **Target:** 100 % of changes reach `main` through a pull request with all required status checks green, a Conventional Commits title and the self-review checklist completed; squash merge keeps one commit per change ([ADR 0002](../adr/0002-source-control-platform.md)).
- **Verification:** branch ruleset on `main`; `pr-title` job in CI.
- **Status:** Agreed.

<a id="nfr-mnt-02"></a>
#### NFR-MNT-02 — Backward-compatible evolution

- **Scenario:** a message contract gains a field or changes.
- **Target:** a minor version adds optional fields only, and every consumer of the major version keeps working; a breaking change introduces a new major event type that runs in parallel with the old one until consumers have moved ([ADR 0012](../adr/0012-message-contract-and-versioning.md)).
- **Verification:** consumer tests run against samples of every published minor version; schema compatibility check in CI (planned).
- **Status:** Agreed.

### Data

<a id="nfr-data-01"></a>
#### NFR-DATA-01 — Idempotent processing

- **Scenario:** the same event is delivered more than once (producer retry, Service Bus redelivery).
- **Target:** N deliveries of one `eventId` produce exactly one stored tick and one UI update per consumer. The UUIDv7 `eventId` is the Service Bus `MessageId` and the Cosmos DB document id ([ADR 0008](../adr/0008-data-storage.md), [ADR 0009](../adr/0009-event-driven-ingestion.md), [ADR 0012](../adr/0012-message-contract-and-versioning.md)).
- **Verification:** integration test that delivers one event three times and asserts one document.
- **Status:** Agreed.

<a id="nfr-data-02"></a>
#### NFR-DATA-02 — History retention

- **Scenario:** a user asks for history of a contract.
- **Target:** raw ticks are kept for 90 days (container TTL); daily bars per trading day are kept indefinitely ([ADR 0008](../adr/0008-data-storage.md)).
- **Verification:** TTL setting in IaC; test that bars are produced from the change feed for every trading day with ticks.
- **Status:** Agreed.

<a id="nfr-data-03"></a>
#### NFR-DATA-03 — Unambiguous instrument identity

- **Scenario:** a tick is stored or a price is shown.
- **Target:** 100 % of stored ticks carry an `instrumentId` of the form `{MIC}.{productCode}.{deliveryPeriodId}` that resolves to exactly one contract in reference data, whose product lists that delivery period kind; relative tenors (`DA`, `M+1`, `Cal+1`) never appear in stored data ([ADR 0014](../adr/0014-instrument-domain-model.md)).
- **Verification:** ingestion rejects unknown ids (integration test); unit tests for id parsing and tenor resolution with real dates.
- **Status:** Agreed.

<a id="nfr-data-04"></a>
#### NFR-DATA-04 — Unambiguous timestamps

- **Scenario:** any timestamp is stored, transported or logged.
- **Target:** 100 % are instants in UTC, written as ISO 8601 with `Z`; local times exist only in reference-data rules and display labels; time-dependent code reads time only through `TimeProvider` ([ADR 0017](../adr/0017-time-and-timezones.md)).
- **Verification:** banned-API analyzer (`RS0030` as error) for `DateTime.Now`, `DateTime.UtcNow`, `DateTime.Today`, `DateTimeOffset.Now`, `DateTimeOffset.UtcNow`; contract schema requires the `Z` suffix.
- **Status:** Verified (analyzer active in CI).

<a id="nfr-data-05"></a>
#### NFR-DATA-05 — Correct delivery volumes on DST days

- **Scenario:** a volume or a number of hours is computed for a delivery period that contains a daylight-saving transition.
- **Target:** delivered energy equals capacity × elapsed duration between the period's UTC boundaries ([BR-TIME-01](business-rules.md#br-time-01)): 1 MW delivers 23, 24 or 25 MWh per day, and periods of any kind follow from their extent ([ADR 0017](../adr/0017-time-and-timezones.md), [ADR 0014](../adr/0014-instrument-domain-model.md)).
- **Verification:** unit tests with the real-date tables in ADR 0017 and ADR 0014 (for example, TTF October 2026 = 745 MWh, weekend starting 2026-10-24 = 49 MWh).
- **Status:** Agreed.

### Compliance and governance

<a id="nfr-legal-01"></a>
#### NFR-LEGAL-01 — Licensed data only

- **Scenario:** a data source is enabled or price data enters the repository.
- **Target:** 0 sources enabled without an entry in `docs/legal/data-sources.md` (source, terms URL, permitted use, review date); 0 raw licensed price series stored in the repository; every price shown carries its source kind (`LIVE` or `REPLAY`) ([ADR 0011](../adr/0011-market-data-sourcing-and-licensing.md)).
- **Verification:** pull request checklist for adapter changes; review of `contracts/reference/` contents.
- **Status:** Agreed.

<a id="nfr-gov-01"></a>
#### NFR-GOV-01 — Requirement-to-release traceability

- **Scenario:** a reviewer asks why a change exists and which release contains it.
- **Target:** 100 % of merged pull requests reference an Azure Boards work item (`AB#<id>`); every User Story belongs to a Feature and every Feature to an Epic; Features reference the ADRs and NFRs they implement ([ADR 0003](../adr/0003-application-lifecycle-management.md)).
- **Verification:** `pr-title` CI job. **Current state:** the `AB#` check reports a warning instead of failing until the Azure DevOps organization exists; it returns to an error after the Azure Boards GitHub app is connected.
- **Status:** Agreed.

### Documentation, demo and delivery

<a id="nfr-doc-01"></a>
#### NFR-DOC-01 — Public, versioned documentation

- **Scenario:** a reader opens the project documentation.
- **Target:** all documentation lives in the repository, changes through pull requests together with the code it describes, builds with `mkdocs build --strict` without warnings and is published to GitHub Pages from `main` ([ADR 0001](../adr/0001-documentation-platform.md)).
- **Verification:** `docs.yml` workflow (planned in [ADR 0004](../adr/0004-ci-cd-platform.md)).
- **Status:** Agreed.

<a id="nfr-demo-01"></a>
#### NFR-DEMO-01 — Demo always works

- **Scenario:** the system is demonstrated while live sources are unavailable, rate-limited or not licensed.
- **Target:** the demo runs end to end on the replay adapter alone; a smoke test against `prod` passes before every demo ([ADR 0011](../adr/0011-market-data-sourcing-and-licensing.md)).
- **Verification:** smoke test workflow (planned); replay is the default source in every environment.
- **Status:** Agreed.

<a id="nfr-del-01"></a>
#### NFR-DEL-01 — Automated, repeatable deployment and environments

- **Labels in ADRs:** "automated, repeatable deployment" ([0004](../adr/0004-ci-cd-platform.md)); "repeatable environments" ([0016](../adr/0016-environments-and-infrastructure-as-code.md)). Both are this requirement.
- **Scenario:** an environment is created, changed or rebuilt.
- **Target:** an environment is created from scratch by the pipeline from Bicep with 0 manual portal steps; a second deployment of an unchanged commit reports no changes in `what-if`; application artefacts are built once and promoted from `dev` to `prod`.
- **Verification:** `iac.yml` and `deploy.yml` workflows (planned); periodic tear-down and rebuild of `dev`.
- **Status:** Agreed.

## Traceability: ADR → NFR

| ADR | NFRs |
|---|---|
| [0000](../adr/0000-cost-optimization-strategy.md) | COST-01 |
| [0001](../adr/0001-documentation-platform.md) | DOC-01 |
| [0002](../adr/0002-source-control-platform.md) | SEC-03, MNT-01 |
| [0003](../adr/0003-application-lifecycle-management.md) | GOV-01 |
| [0004](../adr/0004-ci-cd-platform.md) | SEC-03, DEL-01 |
| [0005](../adr/0005-identity-and-access.md) | SEC-01, SEC-02 |
| [0006](../adr/0006-compute-hosting.md) | COST-01, PERF-02 |
| [0007](../adr/0007-observability.md) | OPS-01, OPS-02, COST-01 |
| [0008](../adr/0008-data-storage.md) | COST-01, DATA-01, DATA-02 |
| [0009](../adr/0009-event-driven-ingestion.md) | REL-01, DATA-01 |
| [0010](../adr/0010-api-management-ingestion-gateway.md) | SEC-01, SEC-04 |
| [0011](../adr/0011-market-data-sourcing-and-licensing.md) | LEGAL-01, DEMO-01 |
| [0012](../adr/0012-message-contract-and-versioning.md) | MNT-02, DATA-01 |
| [0013](../adr/0013-adapter-control-plane.md) | OPS-03, REL-02 |
| [0014](../adr/0014-instrument-domain-model.md) | DATA-03, DATA-05 |
| [0015](../adr/0015-ui-and-real-time-push.md) | PERF-01, SEC-02 |
| [0016](../adr/0016-environments-and-infrastructure-as-code.md) | DEL-01, SEC-02 |
| [0017](../adr/0017-time-and-timezones.md) | DATA-04, DATA-05, OPS-02 |
| [0018](../adr/0018-latency-and-freshness-targets.md) | PERF-01, PERF-02, OPS-01, OPS-02 |
| [0019](../adr/0019-market-status-events.md) | OPS-02, MNT-02, DATA-01 |

## Open items

| Item | Decision needed |
|---|---|
| PERF-01, PERF-02, OPS-01, OPS-02 targets | Run the calibration procedure in [ADR 0018](../adr/0018-latency-and-freshness-targets.md) (User Story "Latency and freshness baseline") once the Azure environment exists; then mark Agreed |
| SEC-03 action pinning | Pin third-party actions by commit SHA, or accept major tags with Dependabot updates |
| GOV-01 `AB#` check | Restore to error after the Azure DevOps organization is connected |
