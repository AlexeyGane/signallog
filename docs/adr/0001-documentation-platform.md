# 0001 — Documentation platform

| Field | Value |
|---|---|
| Status | Accepted |
| Date | 2026-10-09 (revised 2026-10-18) |
| Deciders | Solution Architect, Key Developer *(one person, see README)* |
| Supersedes | — |
| Related | [0000](0000-cost-optimization-strategy.md), [0002](0002-source-control-platform.md), [0004](0004-ci-cd-platform.md) |
| Traces to | NFR-DOC-01 (public, versioned documentation), Azure Boards Epic "Documentation Portal" |

## Context and Problem Statement

SignalLog needs one place for architecture documentation (C4), ADRs, NFRs, security notes, runbooks and a short technical blog. The documentation is also the main artefact a prospective employer reads, so it must be public, navigable and reviewable. Where should documentation live and how is it published?

## Decision Drivers

- D1 — Docs-as-code: Markdown in the same repository as the code, reviewed in pull requests.
- D2 — Public, searchable site suitable for an employer-facing portfolio.
- D3 — Mermaid diagrams rendered natively.
- D4 — Zero recurring cost ([0000](0000-cost-optimization-strategy.md)).

## Considered Options

1. GitHub repository + MkDocs (Material theme) + GitHub Pages
2. Azure DevOps Wiki
3. Confluence
4. SharePoint

## Decision Outcome

**Chosen option:** Option 1, because it is the only option that satisfies all four drivers at zero cost.

### Weighted evaluation

| Criterion (weight) | MkDocs + Pages | Azure DevOps Wiki | Confluence | SharePoint |
|---|---|---|---|---|
| Docs-as-code and PR review (35%) | 5 | 3 | 2 | 1 |
| Public portfolio presentation (30%) | 5 | 2 | 3 | 2 |
| Diagram support (15%) | 5 | 4 | 3 | 2 |
| Cost (20%) | 5 | 5 | 2 | 3 |
| **Weighted score** | **5.0** | **3.25** | **2.45** | **1.85** |

### Consequences

- Good, because documentation is versioned and reviewed exactly like code.
- Good, because the public site doubles as the project's portfolio entry point.
- Bad, because a docs build and deploy workflow must be maintained ([0004](0004-ci-cd-platform.md)).
- **Risk: Material for MkDocs is in maintenance mode.** Its maintainers committed to critical fixes and security updates for at least 12 months without new features, and recommend migrating to their successor project, Zensical, once it covers the needed features. Mitigation: keep configuration minimal and standard; track Zensical compatibility; reassess at the first quarterly review.

### Confirmation

- `mkdocs build --strict` runs on every pull request touching `docs/`; broken links fail the build.
- The site is published from `main` by a GitHub Actions workflow.

## Pros and Cons of the Options

### MkDocs + GitHub Pages
- Good, because Markdown, PR review, Mermaid and a public site come together for free.
- Bad, because the theme is in maintenance mode (see risk).

### Azure DevOps Wiki
- Good, because it integrates natively with Azure Boards.
- Bad, because it is designed for internal project wikis, not a public portal.

### Confluence
- Good, because it has strong collaboration and search.
- Bad, because it has recurring cost and keeps content outside the repository.

### SharePoint
- Good, because it has mature document management.
- Bad, because it is a poor fit for Markdown and pull-request workflows.

## More Information

- The documentation structure and update rules (which were part of the original ADR-001) are a standard, not a decision; they move to `docs/standards/documentation.md`.
- Material for MkDocs maintenance notice: https://github.com/squidfunk/mkdocs-material/issues/8523
- Review triggers: Material for MkDocs end of security fixes; GitHub Pages limits reached.
