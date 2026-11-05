# Architecture Decision Records — SignalLog

This folder is the decision log for SignalLog ([what an ADR is](../standards/concepts-and-sources.md#adr)). Format: [MADR 4](https://adr.github.io/madr/) with two project additions: a weighted evaluation table and a **Traces to** field linking each decision to NFRs ([catalogue](../requirements/nfr.md)), C4 elements and Azure Boards work items. The domain rules that decisions establish are catalogued in [business rules](../requirements/business-rules.md).

## Conventions

- **File name:** `NNNN-kebab-case-title.md`. Versions live in git history, never in file names (no `-v3`, `-final`, `(2)`).
- **Status lifecycle:** `Proposed` → `Accepted` → (`Deprecated` | `Superseded by NNNN`). An Accepted ADR is never edited in substance; a changed decision gets a new ADR that supersedes it.
- **Minimum content for Accepted:** context, drivers, at least two considered options, outcome, consequences, confirmation. One-line stubs stay `Proposed`.
- **Review:** every ADR change goes through a pull request; CODEOWNERS requires the Solution Architect role.
- **Sources:** concepts and definitions link to [Concepts and their sources](../standards/concepts-and-sources.md) or cite their own source. Every statement about an external product, standard or organisation (a capability, limit, price, date or recommendation) links to its primary source, in place or under *More Information*, with the date it was checked. "Microsoft recommends" or "GitHub documents" without a link is not accepted in review. A judgement that is the author's own is worded as such ("author's assessment"), not as a fact.
- **Weighted evaluation:** optional; when used, it follows the method below.
- **Deciders:** this is a solo project. The Solution Architect and Key Developer roles are held by one person; the roles are kept separate on purpose so that each decision is argued from the architect's perspective (drivers, trade-offs) before being implemented. Template: [template.md](template.md).

## Weighted evaluation method

Adopted 2026-11-04, after a review of the tables in ADR 0018 and 0019 found four weaknesses: criteria that did not match the decision drivers, weights chosen after the options were known, a 1–5 scale without definitions used as if it were a measurement, and no check of how robust the result was. A [weighted table](../standards/concepts-and-sources.md#weighted-sum) is a way to make expert judgement visible and arguable; it does not turn judgement into a measurement. The method below makes its weak points explicit.

1. **Criteria come from drivers, one to one.** Each criterion row names its driver (`D1`, `D2`, …). A concern that is not a driver, such as effort, is not scored; if it matters, it is added as a driver before the options are listed. A driver on which all options score the same is left out of the table, with a sentence saying so.
2. **Weights are fixed before any option is scored**, by [swing weighting](../standards/concepts-and-sources.md#swing-weighting): for each driver, picture the difference between the worst and the best plausible outcome, rank those differences, then share 100 points in proportion to them. One line per weight says why. The weights are not changed after scoring; if they must change, the change and its reason are recorded.
3. **The scale has anchors.** For each criterion, write what scores 1, 3 and 5 mean in observable terms before scoring. 2 and 4 lie between the anchors.
4. **Sensitivity is stated.** Below the table, state which options the winner dominates (scores at least as well on every criterion, so no weights can change the order) and, for each option it does not dominate, the weight condition under which that option would win. If a plausible change of weights flips the result, the table does not decide; the outcome is argued from the drivers alone.
5. **The table is labelled** "Expert judgement (one assessor), not a measurement". On a solo project the assessor and the decider are the same person, which is the main limitation; anchors and the sensitivity line are the mitigation.
6. **A dominating winner is suspicious.** If the chosen option dominates every alternative, say what the table leaves out (for example effort, when it is not a driver), so the table does not read as a post-hoc justification.

Tables written before 2026-11-04 (ADR 0001, 0003, 0008) carry a note that they predate this method. Accepted ADRs keep their tables unchanged; a table is rebuilt only when its ADR is revised.

## Index

| ADR | Title | Status | Replaces original file |
|---|---|---|---|
| [0000](0000-cost-optimization-strategy.md) | Cost optimization strategy and budget envelope | Proposed (revision) | ADR-000 |
| [0001](0001-documentation-platform.md) | Documentation platform | Superseded by 0020 | ADR-001 |
| [0002](0002-source-control-platform.md) | Source control platform | Accepted | ADR-002 |
| [0003](0003-application-lifecycle-management.md) | Application lifecycle management | Accepted (amended) | ADR-003 |
| [0004](0004-ci-cd-platform.md) | CI/CD platform | Accepted (revision) | ADR-004 |
| [0005](0005-identity-and-access.md) | Identity and access model | Accepted (revision) | ADR-005 |
| [0006](0006-compute-hosting.md) | Compute and hosting model | Accepted (revision) | ADR-006 + ADR-007 (merged) |
| [0007](0007-observability.md) | Observability platform | Accepted | ADR-008 |
| [0008](0008-data-storage.md) | Operational data store | Proposed (revision) | ADR-009 |
| [0009](0009-event-driven-ingestion.md) | Event-driven ingestion via Azure Service Bus | Proposed | new |
| [0010](0010-api-management-ingestion-gateway.md) | API Management in the ingestion path | Accepted | new |
| [0011](0011-market-data-sourcing-and-licensing.md) | Market data sourcing and licensing | Accepted | new |
| [0012](0012-message-contract-and-versioning.md) | Message contract and versioning | Accepted | new |
| [0013](0013-adapter-control-plane.md) | Adapter control plane | Accepted | new |
| [0014](0014-instrument-domain-model.md) | Instrument domain model and delivery periods | Accepted (revision 2) | new |
| [0015](0015-ui-and-real-time-push.md) | User interface and real-time push | Accepted | new |
| [0016](0016-environments-and-infrastructure-as-code.md) | Environments and infrastructure as code | Proposed | new |
| [0017](0017-time-and-timezones.md) | Time, timezones and delivery periods | Accepted (revision 2) | new |
| [0018](0018-latency-and-freshness-targets.md) | Latency and freshness targets: provisional values and calibration | Accepted | new |
| [0019](0019-market-status-events.md) | Market status events | Accepted | new |
| [0020](0020-documentation-site.md) | Documentation site: Zensical on GitHub Pages | Proposed | new (supersedes 0001) |

## What changed versus the original ADR files

| Original | Change | Reason |
|---|---|---|
| ADR-000 | Budget expressed per component; guardrail raised | Service Bus Standard alone costs ≈ USD 10/month, which consumed the whole original USD 10 envelope |
| ADR-003 | User Story level added; Incident no longer a child of Feature | Scrumban flow is pulled at story level; incidents relate to features, they do not decompose them |
| ADR-004 | Self-hosted runners removed; OIDC deployment added | GitHub recommends self-hosted runners only for private repositories, because a fork of a public repository can run code on the runner through a pull request ([GitHub Docs](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/add-runners)) |
| ADR-005 | Managed identities and workload identity federation replace client secrets | All workloads run in Azure; secrets are avoidable |
| ADR-006/007 | Merged; Linux Consumption replaced by Flex Consumption | .NET 9 is the last version on Linux Consumption ([supported languages](https://learn.microsoft.com/azure/azure-functions/supported-languages)); the plan retires on 2028-09-30 ([Consumption plan](https://learn.microsoft.com/azure/azure-functions/consumption-plan)) |
| ADR-008 | Dangling reference to ADR-012 removed; cost controls moved into the ADR | Referenced ADR did not exist |
| ADR-009 | Cosmos DB kept; rejection rationale for Azure SQL corrected; data model redesigned | SQL is not "low cost efficiency" in general — its free compute allowance (≈ 27.8 vCore-hours/month, [free offer](https://learn.microsoft.com/azure/azure-sql/database/free-offer)) does not survive continuous writes. `/commodityCode` had too low cardinality for an unbounded tick history |

The original files in the repository root are left untouched. Once this set is reviewed, delete them so there is a single source of truth.
