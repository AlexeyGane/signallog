# 0004 — CI/CD platform

| Field | Value |
|---|---|
| Status | Accepted 2026-11-05 (revision of original ADR-004) |
| Date | 2026-10-18 |
| Deciders | Solution Architect, Key Developer *(one person, see README)* |
| Supersedes | ADR-004 (original one-line version) |
| Related | [0002](0002-source-control-platform.md), [0005](0005-identity-and-access.md), [0016](0016-environments-and-infrastructure-as-code.md) |
| Traces to | NFR-SEC-03 (supply chain), NFR-DEL-01 (automated, repeatable deployment) |

## Context and Problem Statement

Build, test, quality gates, infrastructure deployment and application deployment must be automated and repeatable. The original ADR allowed self-hosted runners. The repository is public ([0002](0002-source-control-platform.md)). GitHub recommends self-hosted runners only for private repositories, because a fork of a public repository can run code on the runner's machine through a pull request ([GitHub Docs, add self-hosted runners](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/add-runners)).

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

GitHub Actions authenticates with **OpenID Connect workload identity federation** to a dedicated **user-assigned managed identity** per environment (`id-signallog-github-<env>`, declared in Bicep, [0016](0016-environments-and-infrastructure-as-code.md)), scoped by federated credential to the repository, branch and GitHub Environment. No client secret is stored in GitHub ([0005](0005-identity-and-access.md)).

A managed identity is chosen over an Entra ID app registration (decided 2026-11-05): it is an Azure resource that is created, role-assigned and removed with the environment's Bicep, needs no permission to register applications in the directory, and supports federated credentials for GitHub Actions ([Microsoft Learn](https://learn.microsoft.com/entra/workload-id/workload-identity-federation-create-trust-user-assigned-managed-identity)). An app registration remains the fallback if a scenario needs a multi-tenant application.

### Action pinning

Every action, including first-party `actions/*`, is referenced by its **full-length commit SHA** with the release in a trailing comment:

```yaml
- uses: actions/checkout@fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09 # v5.1.0
```

- A tag such as `@v5` is a movable pointer: the maintainer moves it to each new release, and an attacker who compromises the action's repository can move it to malicious code (the `tj-actions/changed-files` incident, CVE-2025-30066, March 2025, printed runner secrets to public logs this way). A commit SHA identifies content and cannot be moved; GitHub's [secure use reference](https://docs.github.com/en/actions/reference/security/secure-use) recommends pinning to a full-length commit SHA. Since 2026-10-14 the same page names [workflow dependency lockfiles](https://docs.github.com/en/actions/concepts/security/workflow-dependency-lockfiles) (public preview) as the stronger option that supersedes per-file SHA pinning; see *More Information*.
- Updates arrive as Dependabot pull requests (`github-actions` ecosystem, weekly, prefix `ci(deps)`), which change the SHA and the version comment together. A major-version upgrade is a separate, reviewed pull request.
- The repository's *Allowed actions and reusable workflows* policy has **Require actions to be pinned to a full-length commit SHA** enabled, so a workflow that references a tag or branch fails.
- The SHA is taken from the action's own repository (`git ls-remote --tags https://github.com/<owner>/<repo>`), never from a fork.

### Consequences

- Good, because fork pull requests run only on ephemeral GitHub-hosted machines.
- Good, because there are no cloud secrets to rotate or leak.
- Bad, because GitHub-hosted runners cannot reach private endpoints; deployments rely on the public management plane, and data-plane steps (e.g. database migrations) run from inside Azure (a deployment-time Function or a migration bundle executed by the app on startup).

### Confirmation

- Repository settings: no self-hosted runners registered; "Require approval for fork pull request workflows" enabled.
- No secrets of type client secret in repository or environment secrets.
- Repository Actions policy: "Require actions to be pinned to a full-length commit SHA" enabled; every `uses:` line in `.github/workflows` references a 40-character SHA.

## Pros and Cons of the Options

### GitHub-hosted runners + OIDC
- Good, because they are isolated, ephemeral and free for public repositories.
- Bad, because there is no network line of sight to private resources.

### Self-hosted runners
- Good, because they offer private network access and faster cached builds.
- Bad, because they are a code-execution vector for public repositories; GitHub recommends them only for private repositories.

### Azure Pipelines
- Good, because it has a mature release model.
- Bad, because it splits CI from the code platform without a clear benefit here.

## More Information

- GitHub changelog, Actions policy supports blocking and SHA pinning (2025-08-15): https://github.blog/changelog/2025-08-15-github-actions-policy-now-supports-blocking-and-sha-pinning-actions/
- GitHub Advisory GHSA-mrrh-fwg8-r2c3 (tj-actions/changed-files): https://github.com/advisories/GHSA-mrrh-fwg8-r2c3
- GitHub Docs, add self-hosted runners (recommendation for private repositories only): https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/add-runners
- GitHub Docs, secure use reference (SHA pinning, lockfiles): https://docs.github.com/en/actions/reference/security/secure-use
- GitHub Docs, workflow dependency lockfiles (`.github/workflows/actions.lock`, public preview): https://docs.github.com/en/actions/concepts/security/workflow-dependency-lockfiles
- GitHub changelog, workflow lockfiles in public preview (2026-10-14): https://github.blog/changelog/2026-10-14-github-actions-workflow-lockfiles-in-public-preview/
- Microsoft Learn, Explore runners — security considerations (secondary): https://learn.microsoft.com/training/modules/introduction-to-github-actions/8-explore-runners
- Review trigger: workflow dependency lockfiles reach general availability. Then decide whether the lockfile replaces SHA pinning in workflow files; until then, SHA pinning stays.
- Sources checked 2026-11-04.
