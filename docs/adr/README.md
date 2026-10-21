# Architecture Decision Records — SignalLog

This folder is the decision log for SignalLog. Format: [MADR 4](https://adr.github.io/madr/) with two project additions: a weighted evaluation table and a **Traces to** field linking each decision to NFRs, C4 elements and Azure Boards work items.

## Conventions

- **File name:** `NNNN-kebab-case-title.md`. Versions live in git history, never in file names (no `-v3`, `-final`, `(2)`).
- **Status lifecycle:** `Proposed` → `Accepted` → (`Deprecated` | `Superseded by NNNN`). An Accepted ADR is never edited in substance; a changed decision gets a new ADR that supersedes it.
- **Minimum content for Accepted:** context, drivers, at least two considered options, outcome, consequences, confirmation. One-line stubs stay `Proposed`.
- **Review:** every ADR change goes through a pull request; CODEOWNERS requires the Solution Architect role.
- **Deciders:** this is a solo project. The Solution Architect and Key Developer roles are held by one person; the roles are kept separate on purpose so that each decision is argued from the architect's perspective (drivers, trade-offs) before being implemented. Template: [template.md](template.md).

## Index

| ADR | Title | Status | Replaces original file |
|---|---|---|---|
| [0000](0000-cost-optimization-strategy.md) | Cost optimization strategy and budget envelope | Proposed (revision) | ADR-000 |
| [0001](0001-documentation-platform.md) | Documentation platform | Accepted | ADR-001 |
| [0002](0002-source-control-platform.md) | Source control platform | Accepted | ADR-002 |
| [0003](0003-application-lifecycle-management.md) | Application lifecycle management | Accepted (amended) | ADR-003 |
| [0004](0004-ci-cd-platform.md) | CI/CD platform | Proposed (revision) | ADR-004 |
| [0005](0005-identity-and-access.md) | Identity and access model | Proposed (revision) | ADR-005 |
| [0006](0006-compute-hosting.md) | Compute and hosting model | Proposed (revision) | ADR-006 + ADR-007 (merged) |
| [0007](0007-observability.md) | Observability platform | Proposed | ADR-008 |
| [0008](0008-data-storage.md) | Operational data store | Proposed (revision) | ADR-009 |
| [0009](0009-event-driven-ingestion.md) | Event-driven ingestion via Azure Service Bus | Proposed | new |
| [0010](0010-api-management-ingestion-gateway.md) | API Management in the ingestion path | Proposed | new |
| [0011](0011-market-data-sourcing-and-licensing.md) | Market data sourcing and licensing | Proposed | new |
| [0012](0012-message-contract-and-versioning.md) | Message contract and versioning | Proposed | new |
| [0013](0013-adapter-control-plane.md) | Adapter control plane | Proposed | new |
| [0014](0014-instrument-domain-model.md) | Instrument domain model | Proposed | new |
| [0015](0015-ui-and-real-time-push.md) | User interface and real-time push | Proposed | new |
| [0016](0016-environments-and-infrastructure-as-code.md) | Environments and infrastructure as code | Proposed | new |
| [0017](0017-time-and-timezones.md) | Time and timezone handling | Proposed | new |

## What changed versus the original ADR files

| Original | Change | Reason |
|---|---|---|
| ADR-000 | Budget expressed per component; guardrail raised | Service Bus Standard alone costs ≈ USD 10/month, which consumed the whole original USD 10 envelope |
| ADR-003 | User Story level added; Incident no longer a child of Feature | Scrumban flow is pulled at story level; incidents relate to features, they do not decompose them |
| ADR-004 | Self-hosted runners removed; OIDC deployment added | Microsoft guidance: never use self-hosted runners with public repositories |
| ADR-005 | Managed identities and workload identity federation replace client secrets | All workloads run in Azure; secrets are avoidable |
| ADR-006/007 | Merged; Linux Consumption replaced by Flex Consumption | .NET 9 is the last version on Linux Consumption; the plan retires on 2028-09-30 |
| ADR-008 | Dangling reference to ADR-012 removed; cost controls moved into the ADR | Referenced ADR did not exist |
| ADR-009 | Cosmos DB kept; rejection rationale for Azure SQL corrected; data model redesigned | SQL is not "low cost efficiency" in general — its free compute allowance (≈ 27.8 vCore-hours/month) does not survive continuous writes. `/commodityCode` had too low cardinality for an unbounded tick history |

The original files in the repository root are left untouched. Once this set is reviewed, delete them so there is a single source of truth.
