# 0002 — Source control platform

| Field | Value |
|---|---|
| Status | Accepted |
| Date | 2026-10-09 (expanded 2026-10-18) |
| Deciders | Solution Architect, Key Developer *(one person, see README)* |
| Related | [0003](0003-application-lifecycle-management.md), [0004](0004-ci-cd-platform.md) |
| Traces to | NFR-SEC-03 (supply-chain security), NFR-MNT-01 (reviewability) |

## Context and Problem Statement

The code, IaC and documentation need a hosted Git platform that supports protected branches, mandatory reviews, dependency scanning and a public profile that employers can browse.

## Decision Drivers

- D1 — Public visibility of the repository and contribution history.
- D2 — Branch protection, required reviews, CODEOWNERS.
- D3 — Built-in supply-chain security (dependency alerts, secret scanning).
- D4 — Free for a public repository.

## Considered Options

1. GitHub
2. Azure Repos
3. GitLab.com

## Decision Outcome

**Chosen option:** GitHub, because it is where employers look (D1) and its free tier for public repositories covers D2–D4.

Configuration baseline:

- Single repository (monorepo): `src/`, `tests/`, `infra/`, `docs/`.
- `main` protected: pull request required, linear history, status checks required, no force push.
- Trunk-based development with short-lived feature branches named `feature/AB<id>-short-name`.
- Conventional Commits; commit and PR titles reference Azure Boards items with `AB#<id>` ([0003](0003-application-lifecycle-management.md)).
- CODEOWNERS: `docs/adr/` and `infra/` require the Solution Architect role.
- Dependabot (NuGet, GitHub Actions), secret scanning and push protection enabled.

### Consequences

- Good, because the public repository is itself part of the portfolio.
- Good, because `AB#` links give end-to-end traceability to Azure Boards.
- Bad, because a solo developer cannot approve their own pull requests. The `main` ruleset therefore requires a pull request with **0 approvals** and does **not** enforce code-owner review; quality is enforced by required status checks (CI, analyzers, tests) and a self-review checklist in the PR template. CODEOWNERS documents ownership only. Revisit when a second contributor joins.

### Confirmation

Branch protection and security settings are exported or codified and checked in the quarterly review.

## Pros and Cons of the Options

### GitHub
- Good, because of ecosystem, visibility and free security features for public repos.
- Bad, because work management lives in a second tool (accepted in [0003](0003-application-lifecycle-management.md)).

### Azure Repos
- Good, because it lives next to Azure Boards.
- Bad, because public visibility and community presence are weaker.

### GitLab.com
- Good, because it has strong built-in CI.
- Bad, because it is less common in Microsoft-centric hiring contexts.
