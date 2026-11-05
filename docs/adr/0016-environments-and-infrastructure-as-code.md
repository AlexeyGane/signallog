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
- Region: **Sweden Central** for every environment resource (checks in [0006](0006-compute-hosting.md) and [0010](0010-api-management-ingestion-gateway.md)). Exception: Static Web Apps offers few regions; its region only hosts the managed Functions API and staging environments, while static assets are distributed globally ([Static Web Apps FAQ](https://learn.microsoft.com/azure/static-web-apps/faq#how-do-i-ensure-my-app-is-deployed-to-a-specific-azure-region)), so the closest offered region (West Europe) is used ([0015](0015-ui-and-real-time-push.md)).
- The resource group `VisualStudioOnline-<id>` in the subscription belongs to the Azure DevOps organization's billing link ([0003](0003-application-lifecycle-management.md)); it is not managed by SignalLog's IaC and must not be deleted.
- Naming: `<type>-signallog-<env>[-<qualifier>]` following the Cloud Adoption Framework abbreviations.

### Pipeline integration

- PR: `az deployment group what-if` output posted as a PR comment ([0004](0004-ci-cd-platform.md)).
- `main`: deploy `dev`; `prod` deploys after manual approval on the GitHub Environment.

### Consequences

- Good, because it is first-party, supports new resource types and API versions as soon as they are published, and keeps no state file ([Bicep overview](https://learn.microsoft.com/azure/azure-resource-manager/bicep/overview), [Terraform and Bicep compared](https://learn.microsoft.com/azure/developer/terraform/comparing-terraform-and-bicep)).
- Good, because what-if in PRs makes infrastructure changes reviewable like code.
- Bad, because the skills are less portable than Terraform; acceptable given D3.

### Confirmation

- Deleting and recreating `dev` from `main` succeeds with no manual steps (quarterly exercise).

## Pros and Cons of the Options

### Bicep
- Good, because it is native, stateless and well integrated with what-if.
- Bad, because it is Azure-only.

### Terraform
- Good, because it is multi-cloud and widely used (author's assessment); its AzAPI provider also reaches new Azure features immediately.
- Bad, because a state backend must be secured and maintained; multi-cloud is not a requirement.

### Portal + export
- Good, because it is fast to start.
- Bad, because it is not reviewable or repeatable.

## More Information

Sources (checked 2026-11-04):

- What is Bicep (support for all resource types and API versions): https://learn.microsoft.com/azure/azure-resource-manager/bicep/overview
- Comparing Terraform and Bicep (state, Azure coverage, what-if versus plan): https://learn.microsoft.com/azure/developer/terraform/comparing-terraform-and-bicep
- Bicep what-if: https://learn.microsoft.com/azure/azure-resource-manager/bicep/deploy-what-if
- Deployment stacks: https://learn.microsoft.com/azure/azure-resource-manager/bicep/deployment-stacks
- Azure Verified Modules: https://azure.github.io/Azure-Verified-Modules/
- Cloud Adoption Framework, resource abbreviations: https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations
