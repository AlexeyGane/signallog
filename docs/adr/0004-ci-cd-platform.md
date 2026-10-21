# 0004 — CI/CD platform

| Field | Value |
|---|---|
| Status | Proposed (revision of original ADR-004, Accepted) |
| Date | 2026-10-18 |
| Deciders | Solution Architect, Key Developer *(one person, see README)* |
| Supersedes | ADR-004 (original one-line version) |
| Related | [0002](0002-source-control-platform.md), [0005](0005-identity-and-access.md), [0016](0016-environments-and-infrastructure-as-code.md) |
| Traces to | NFR-SEC-03 (supply chain), NFR-DEL-01 (automated, repeatable deployment) |

## Context and Problem Statement

Build, test, quality gates, infrastructure deployment and application deployment must be automated and repeatable. The original ADR allowed self-hosted runners. The repository is public ([0002](0002-source-control-platform.md)), and Microsoft's guidance is unambiguous: self-hosted runners must never be used with public repositories, because anyone who can open a pull request can execute code on the runner's host.

## Decision Drivers

- D1 — No code from untrusted pull requests may execute on infrastructure we own.
- D2 — No long-lived cloud credentials stored in CI.
- D3 — Quality gates enforced before merge.
- D4 — Free for a public repository.

## Considered Options

1. GitHub Actions with GitHub-hosted runners and OIDC to Azure
2. GitHub Actions with self-hosted runners
3. Azure Pipelines

## Decision Outcome

**Chosen option:** Option 1.

### Pipelines

| Workflow | Trigger | Steps |
|---|---|---|
| `ci.yml` | pull request, push to `main` | restore, build with analyzers (banned-API rule `RS0030` as error, [0012](0012-message-contract-and-versioning.md), [0017](0017-time-and-timezones.md)), unit tests, coverage gate, `dotnet format --verify-no-changes`, PR title lint (Conventional Commits + `AB#`) |
| `iac.yml` | changes under `infra/` | Bicep lint, `what-if` on PR, deploy on `main` ([0016](0016-environments-and-infrastructure-as-code.md)) |
| `deploy.yml` | push to `main`, manual for prod | build artefacts once, deploy to dev, then prod behind a GitHub Environment with required approval |
| `docs.yml` | changes under `docs/` | `mkdocs build --strict`, publish to GitHub Pages ([0001](0001-documentation-platform.md)) |
| `codeql.yml` | schedule, pull request | CodeQL analysis for C# |

### Authentication to Azure

GitHub Actions authenticates with **OpenID Connect workload identity federation** to a dedicated Entra ID app registration (or user-assigned managed identity) per environment, scoped by federated credential to the repository, branch and GitHub Environment. No client secret is stored in GitHub ([0005](0005-identity-and-access.md)).

### Consequences

- Good, because fork pull requests run only on ephemeral GitHub-hosted machines.
- Good, because there are no cloud secrets to rotate or leak.
- Bad, because GitHub-hosted runners cannot reach private endpoints; deployments rely on the public management plane, and data-plane steps (e.g. database migrations) run from inside Azure (a deployment-time Function or a migration bundle executed by the app on startup).

### Confirmation

- Repository settings: no self-hosted runners registered; "Require approval for fork pull request workflows" enabled.
- No secrets of type client secret in repository or environment secrets.

## Pros and Cons of the Options

### GitHub-hosted runners + OIDC
- Good, because they are isolated, ephemeral and free for public repositories.
- Bad, because there is no network line of sight to private resources.

### Self-hosted runners
- Good, because they offer private network access and faster cached builds.
- Bad, because they are a code-execution vector for public repositories (Microsoft: never use with public repositories).

### Azure Pipelines
- Good, because it has a mature release model.
- Bad, because it splits CI from the code platform without a clear benefit here.

## More Information

- Microsoft Learn, Explore runners — security considerations: https://learn.microsoft.com/training/modules/introduction-to-github-actions/8-explore-runners
