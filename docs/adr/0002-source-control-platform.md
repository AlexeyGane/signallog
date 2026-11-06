# 0002 — Source control platform

| Field | Value |
|---|---|
| Status | Accepted (revision 2, 2026-11-07) |
| Date | 2026-10-09 (expanded 2026-10-18) |
| Deciders | Solution Architect, Key Developer *(one person, see README)* |
| Related | [0003](0003-application-lifecycle-management.md), [0004](0004-ci-cd-platform.md) |
| Traces to | NFR-SEC-03 (supply-chain security), NFR-MNT-01 (reviewability) |

**Revision 2** (2026-11-07): the decision is unchanged. The revision records how the `main` ruleset implements it: which status checks are required, the review gate that takes the place of an approval, the value chosen for an undocumented ruleset parameter, and where the settings are kept as code ([Ruleset on `main`](#ruleset-on-main-revision-2)).

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
- Trunk-based development with short-lived branches named `<type>/AB<id>-short-name`, squash merges and releases by tag. The operating procedure is the [Branching and release standard](../standards/branching-and-release.md).
- Conventional Commits; commit and PR titles reference Azure Boards items with `AB#<id>` ([0003](0003-application-lifecycle-management.md)).
- CODEOWNERS: `docs/adr/` and `infra/` require the Solution Architect role.
- Dependabot (NuGet, GitHub Actions), secret scanning and push protection enabled.

### Consequences

- Good, because the public repository is itself part of the portfolio.
- Good, because `AB#` links give end-to-end traceability to Azure Boards.
- Bad, because a solo developer cannot approve their own pull requests. The `main` ruleset therefore requires a pull request with **0 approvals** and does **not** enforce code-owner review; quality is enforced by required status checks (CI, analyzers, tests) and a self-review checklist in the PR template. CODEOWNERS documents ownership only. Revisit when a second contributor joins.

### Ruleset on `main` (revision 2)

The settings are kept as code in [`eng/github/repository.settings.psd1`](https://github.com/AlexeyGane/signallog/blob/main/eng/github/repository.settings.psd1) and applied by `eng/github/Initialize-GitHubSettings.ps1`; `-Check` lists every difference from GitHub and changes nothing. The ruleset `main-protection` on the default branch:

| Rule | Value | Why |
|---|---|---|
| Deletion, force push | blocked | `main` keeps its history |
| Linear history, merge method | required; squash only | one commit per change ([branching standard](../standards/branching-and-release.md)) |
| Pull request | required, **0 approvals**, review threads resolved | authors cannot approve their own pull requests (consequence above) |
| Required status checks | `pr-title` and `build` from `ci.yml` (GitHub Actions); commit status `review/all-files-viewed` | CI must be green; the review gate takes the place of an approval |
| `require_extra_approval_for_unattributed_changes` | `true` | see below |

- **Checks are matched by name**, so names are unique across workflows: the documentation job is named `site`, not `build`. `site` is not required, because it runs only when the documentation changes and a pull request without such changes would wait for it forever.
- **Review gate.** The owner marks every changed file as Viewed; a script on the owner's machine, which reads the owner's Viewed marks, sets `review/all-files-viewed` to success ([change workflow, section 5](../standards/change-workflow.md#5-review-gate-every-file-viewed)). For a pull request no change script created, for example from Dependabot, `eng/github/Watch-ReviewGate.ps1 -Number <n>` runs the gate alone.
- **Unattributed changes.** The ruleset API parameter `require_extra_approval_for_unattributed_changes` is, by its name and behaviour, the option GitHub Docs call (**Inferred**: the documentation names the option in the web interface, not the API parameter) *Require an additional approval for unattributed Copilot pull requests* (public preview, on by default; checked 2026-11-07): when Copilot opens a pull request that is not attributed to a person, the ruleset requires one approval more than configured, and the setting **has no effect when the ruleset requires zero approvals** ([available rules for rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)). The parameter is still missing from GitHub's REST API description ([github/rest-api-description#7246](https://github.com/github/rest-api-description/issues/7246)), and one report describes pull requests held back by it with zero required approvals ([rjmurillo/ai-agents#6144](https://github.com/rjmurillo/ai-agents/issues/6144)); that report contradicts GitHub Docs, and the documentation is taken as authoritative. It matches this repository: pull requests #22 to #24, with commits signed by the owner and a `Co-Authored-By: Claude` trailer, merged without an extra approval. **Decision: keep it `true`** (GitHub's default). With 0 approvals it changes nothing today; if approvals are ever required, for example when a second contributor joins, a Copilot pull request without a person behind it will need one more.

### Confirmation

Branch protection and security settings are codified in `eng/github/repository.settings.psd1`; `Initialize-GitHubSettings.ps1 -Check` reports no difference, run after every settings change and in the quarterly review. The settings module is covered by Pester tests in CI.

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

## More Information

Sources (checked 2026-11-04; revision 2 sources checked 2026-11-07):

- GitHub Docs, approving a pull request with required reviews ("Pull request authors cannot approve their own pull requests"): https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/reviewing-changes-in-pull-requests/approving-a-pull-request-with-required-reviews
- GitHub changelog, push protection available on public repositories for free (2023-05-09): https://github.blog/changelog/2023-05-09-secret-scannings-push-protection-is-available-on-public-repositories-for-free
- GitHub Docs, working with secret scanning and push protection: https://docs.github.com/en/code-security/secret-scanning/working-with-secret-scanning-and-push-protection
- GitHub REST API description, issue #7246: rule parameters `require_extra_approval_for_unattributed_changes`, `ignore_approvals_from_contributors` and `actor_controlled_merging` missing from the schema (revision 2): https://github.com/github/rest-api-description/issues/7246
- rjmurillo/ai-agents, issue #6144: pull requests waiting on the ruleset's extra approval for unattributed changes (revision 2): https://github.com/rjmurillo/ai-agents/issues/6144
- GitHub Docs, available rules for rulesets (required status checks, merge methods): https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets
