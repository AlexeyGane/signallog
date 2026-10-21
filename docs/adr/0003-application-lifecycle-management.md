# 0003 — Application lifecycle management

| Field | Value |
|---|---|
| Status | Accepted (amended 2026-10-18: work item hierarchy) |
| Date | 2026-10-11 |
| Deciders | Solution Architect, Key Developer *(one person, see README)* |
| Related | [0001](0001-documentation-platform.md), [0002](0002-source-control-platform.md), [0004](0004-ci-cd-platform.md) |
| Traces to | NFR-GOV-01 (requirement-to-release traceability) |

## Context and Problem Statement

The project must demonstrate an enterprise SDLC: planned work, a visible flow of delivery, and traceability from a business goal down to the deployment that delivered it. Which tools manage work, and how is work linked to code?

## Decision Drivers

- D1 — Mature hierarchy (Epic → Feature → Story) and portfolio views (Delivery Plans).
- D2 — Kanban board with WIP limits for a Scrumban flow.
- D3 — Traceability Epic → … → Pull Request → Build → Deployment.
- D4 — Free ([0000](0000-cost-optimization-strategy.md)).

## Considered Options

1. GitHub (code, CI/CD) + Azure Boards (work management)
2. GitHub + GitHub Projects
3. Azure DevOps full stack
4. GitHub + Jira

## Decision Outcome

**Chosen option:** Option 1, because Azure Boards provides the deepest hierarchy and planning features (D1, D2) and integrates with GitHub through the Azure Boards app (D3) at no cost (D4).

### Weighted evaluation

| Criterion (weight) | GitHub + Boards | GitHub + Projects | Azure DevOps | GitHub + Jira |
|---|---|---|---|---|
| Hierarchy and planning (35%) | 5 | 3 | 5 | 5 |
| Code/PR experience and visibility (25%) | 5 | 5 | 3 | 5 |
| Traceability (20%) | 4 | 3 | 5 | 4 |
| Cost (20%) | 5 | 5 | 5 | 2 |
| **Weighted score** | **4.8** | **3.9** | **4.5** | **4.2** |

### Work item hierarchy (Agile process template)

```text
Epic                 business capability, e.g. "Market Data Ingestion"
└── Feature          deliverable increment, e.g. "ICE Futures Europe adapter"
    └── User Story   unit of flow pulled through the Scrumban board
        └── Task     technical step (optional for a solo developer)
Bug                  child of the Story or Feature it affects
Issue (Incident)     not a child: linked to the affected Feature via "Related",
                     to the fixing Bug/Story via "Related"; tagged incident
```

The original ADR placed Bug and Incident directly under Feature and had no Story level. The Story level is restored because the Scrumban board pulls stories, and WIP limits and cycle time are measured on them. Incidents are operational events, not decompositions of a feature, so they are linked rather than parented.

### Traceability chain

```text
ADR / NFR ─► Epic ─► Feature ─► User Story ─► PR (AB#id) ─► Build ─► Deployment ─► Release tag
```

- Commits and PRs reference stories with `AB#<id>`; the Azure Boards GitHub app creates the links.
- Each Feature links to the ADRs and NFRs it implements (Hyperlink field or "Traces to" tag).

### Consequences

- Good, because the hierarchy supports Delivery Plans and portfolio-level reporting.
- Good, because AB# links make traceability automatic rather than manual.
- Bad, because two systems must be configured and kept in sync.

### Confirmation

- Every merged PR references at least one `AB#` item (checked by a PR title lint step in [0004](0004-ci-cd-platform.md)).
- Monthly check: no closed Story without a linked PR.

## Pros and Cons of the Options

### GitHub + Azure Boards
- Good, because it combines the strongest code platform with the strongest work management.
- Bad, because it requires cross-platform integration.

### GitHub + GitHub Projects
- Good, because everything lives in one platform.
- Bad, because hierarchy and portfolio planning are less mature.

### Azure DevOps full stack
- Good, because it offers best native traceability.
- Bad, because it weakens public visibility of the code ([0002](0002-source-control-platform.md)).

### GitHub + Jira
- Good, because Jira is an industry standard.
- Bad, because paid tiers would be needed for comparable features.
