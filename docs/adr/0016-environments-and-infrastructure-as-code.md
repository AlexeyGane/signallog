# 0016 — Environments and infrastructure as code

| Field | Value |
|---|---|
| Status | Proposed |
| Date | 2026-10-18 |
| Deciders | Solution Architect, Key Developer *(one person, see README)* |
| Related | [0000](0000-cost-optimization-strategy.md), [0004](0004-ci-cd-platform.md), [0005](0005-identity-and-access.md), [0008](0008-data-storage.md) |
| Traces to | NFR-DEL-01 (repeatable environments), NFR-SEC-02 |

## Context and Problem Statement

Every Azure resource, role assignment and alert must be reproducible from the repository, and changes must be reviewable before they are applied. How many environments exist, and which tool defines them?

## Decision Drivers

- D1 — Everything in code, including RBAC, budgets and alerts.
- D2 — Preview of changes in pull requests.
- D3 — Azure-only platform; no multi-cloud requirement.
- D4 — Minimal cost for a second environment.

## Considered Options

1. Bicep with Azure Verified Modules where they fit; deployment stacks per environment
2. Terraform (azurerm / azapi)
3. Portal configuration with exported templates

## Decision Outcome

**Chosen option:** Option 1, Bicep.

### Environments

| Environment | Scope | Purpose | Data source |
|---|---|---|---|
| `local` | developer machine | inner loop | Cosmos DB emulator, Azurite, Service Bus emulator or a dev namespace |
| `dev` | resource group `rg-signallog-dev` | integration, PR previews of IaC | Replay adapter |
| `prod` | resource group `rg-signallog-prod` | public demo | Replay + permitted live adapters ([0011](0011-market-data-sourcing-and-licensing.md)) |

- One subscription, two resource groups. The single free-tier Cosmos DB account is shared: databases `signallog-dev` and `signallog-prod` under database-level throughput, or `dev` uses the emulator only ([0008](0008-data-storage.md)).
- `dev` resources that carry a fixed charge (Service Bus Standard) are shared with `prod` through separate topics, or `dev` is deployed on demand and torn down; the choice is recorded in [0000](0000-cost-optimization-strategy.md).
- Naming: `<type>-signallog-<env>[-<qualifier>]` following the Cloud Adoption Framework abbreviations.

### Pipeline integration

- PR: `az deployment group what-if` output posted as a PR comment ([0004](0004-ci-cd-platform.md)).
- `main`: deploy `dev`; `prod` deploys after manual approval on the GitHub Environment.

### Consequences

- Good, because it is first-party, has day-zero support for new resource types and no state file to manage.
- Good, because what-if in PRs makes infrastructure changes reviewable like code.
- Bad, because the skills are less portable than Terraform; acceptable given D3.

### Confirmation

- Deleting and recreating `dev` from `main` succeeds with no manual steps (quarterly exercise).

## Pros and Cons of the Options

### Bicep
- Good, because it is native, stateless and well integrated with what-if.
- Bad, because it is Azure-only.

### Terraform
- Good, because it is multi-cloud and an industry standard.
- Bad, because a state backend must be secured and maintained; multi-cloud is not a requirement.

### Portal + export
- Good, because it is fast to start.
- Bad, because it is not reviewable or repeatable.
