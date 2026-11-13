# 0002 — Source control platform

| Field | Value |
|---|---|
| Status | Accepted (revision 3, 2026-11-13) |
| Date | 2026-10-09 (expanded 2026-10-18) |
| Deciders | Solution Architect, Key Developer *(one person, see README)* |
| Related | [0003](0003-application-lifecycle-management.md), [0004](0004-ci-cd-platform.md) |
| Traces to | NFR-SEC-03 (supply-chain security), NFR-MNT-01 (reviewability) |

**Revision 2** (2026-11-07): the decision is unchanged. The revision records how the `main` ruleset implements it: which status checks are required, the review gate that takes the place of an approval, the value chosen for an undocumented ruleset parameter, and where the settings are kept as code ([Ruleset on `main`](#ruleset-on-main-revision-2)).

**Revision 3** (2026-11-13): the decision is unchanged. The review gate moves from the owner's machine to GitHub: a workflow opens a review thread for every changed file and the ruleset requires every conversation to be resolved, in place of a commit status set by a script that read the owner's Viewed marks ([Review gate](#review-gate-revision-3)).

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
| Required status checks | `pr-title` and `build` from `ci.yml`, `review-threads` from `review-threads.yml` (all GitHub Actions) | CI must be green; the review gate takes the place of an approval (revision 3) |
| `require_extra_approval_for_unattributed_changes` | `true` | see below |

- **Checks are matched by name**, so names are unique across workflows: the documentation job is named `site`, not `build`. `site` is not required, because it runs only when the documentation changes and a pull request without such changes would wait for it forever.
- **Review gate.** Every changed file gets a review thread, and every thread must be resolved before the merge ([Review gate](#review-gate-revision-3), [change workflow, section 5](../standards/change-workflow.md#5-review-gate-a-resolved-thread-per-file)).
- **Unattributed changes.** The ruleset API parameter `require_extra_approval_for_unattributed_changes` is, by its name and behaviour, the option GitHub Docs call (**Inferred**: the documentation names the option in the web interface, not the API parameter) *Require an additional approval for unattributed Copilot pull requests* (public preview, on by default; checked 2026-11-07): when Copilot opens a pull request that is not attributed to a person, the ruleset requires one approval more than configured, and the setting **has no effect when the ruleset requires zero approvals** ([available rules for rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)). The parameter is still missing from GitHub's REST API description ([github/rest-api-description#7246](https://github.com/github/rest-api-description/issues/7246)), and one report describes pull requests held back by it with zero required approvals ([rjmurillo/ai-agents#6144](https://github.com/rjmurillo/ai-agents/issues/6144)); that report contradicts GitHub Docs, and the documentation is taken as authoritative. It matches this repository: pull requests #22 to #24, with commits signed by the owner and a `Co-Authored-By: Claude` trailer, merged without an extra approval. **Decision: keep it `true`** (GitHub's default). With 0 approvals it changes nothing today; if approvals are ever required, for example when a second contributor joins, a Copilot pull request without a person behind it will need one more.

### Review gate (revision 3)

Revision 2 required a commit status, `review/all-files-viewed`, that a script on the owner's machine set once the owner had marked every file as Viewed. It worked for pull requests the change scripts opened and failed for the others: a Dependabot pull request could be merged only after the owner ran a second script for it by hand. The Viewed mark belongs to each user, and GitHub returns it only to that user: the GraphQL field `viewerViewedState` answers for whoever is signed in (**Observed** while revision 2 was in use), so no workflow can read the owner's marks without the owner's personal access token, and marking a file as Viewed triggers no event a workflow could react to (**Inferred**: none is listed among the [events that trigger workflows](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows); checked 2026-11-13).

**Decision.** The gate uses what GitHub already enforces: the ruleset rule *Require conversation resolution before merging* (`required_review_thread_resolution`, [available rules for rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)), on since revision 2. The workflow `review-threads` runs on every push to a pull request and opens one file-level review comment per changed file ([`subject_type: file`](https://docs.github.com/en/rest/pulls/comments#create-a-review-comment-for-a-pull-request)); the owner reads the file and resolves its thread. Each comment records, in a hidden marker, the git blob id of the file it asks to review, so a later push opens a new thread only for a file whose content changed after its thread was resolved, replies in a thread that is still open, and resolves the threads of files that left the pull request. The job's check `review-threads` is required, so a pull request cannot be merged in the moment between a push and the threads for it.

| Option | Works for Dependabot | Needs a token | Re-review after a push |
|---|---|---|---|
| A. Commit status from the owner's Viewed marks (revision 2) | only with a second script run by hand | the owner's `gh` session | GitHub clears Viewed on changed files |
| B. The same status set by a workflow with a personal access token | yes | a personal access token as a secret, which Dependabot runs cannot read: they get only Dependabot secrets | as A |
| **C. A thread per file, conversation resolution required** | **yes** | **none: the workflow's `GITHUB_TOKEN`** | **only files whose blob changed** |

- Good, because every pull request, Dependabot's included, passes the same gate with no script on the owner's machine and no stored token. Runs started by Dependabot get a read-only `GITHUB_TOKEN` unless the workflow asks for more with the `permissions` key ([GitHub Docs](https://docs.github.com/en/code-security/reference/supply-chain-security/troubleshoot-dependabot/dependabot-on-actions), checked 2026-11-13); the workflow asks for `pull-requests: write` and `contents: read` only.
- Good, because the review is visible on the pull request: each file shows whether its thread is resolved and which commit it was reviewed at.
- Bad, because a pull request carries one comment per file; a large change is noisy. Accepted for a repository where changes are kept small (one story, one change).
- Bad, because, as in revision 2, the gate guards against forgetting a file, not against deliberate bypass: anyone with write access can resolve a thread unread.
- The workflow runs the version of its script in the pull request with a write token. Pull requests here come from the owner and Dependabot; a pull request from a fork gets a read-only token and its run fails, which blocks the merge instead of skipping the gate.

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

Sources (checked 2026-11-04; revision 2 sources checked 2026-11-07; revision 3 sources checked 2026-11-13):

- GitHub Docs, approving a pull request with required reviews ("Pull request authors cannot approve their own pull requests"): https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/reviewing-changes-in-pull-requests/approving-a-pull-request-with-required-reviews
- GitHub changelog, push protection available on public repositories for free (2023-05-09): https://github.blog/changelog/2023-05-09-secret-scannings-push-protection-is-available-on-public-repositories-for-free
- GitHub Docs, working with secret scanning and push protection: https://docs.github.com/en/code-security/secret-scanning/working-with-secret-scanning-and-push-protection
- GitHub REST API description, issue #7246: rule parameters `require_extra_approval_for_unattributed_changes`, `ignore_approvals_from_contributors` and `actor_controlled_merging` missing from the schema (revision 2): https://github.com/github/rest-api-description/issues/7246
- rjmurillo/ai-agents, issue #6144: pull requests waiting on the ruleset's extra approval for unattributed changes (revision 2): https://github.com/rjmurillo/ai-agents/issues/6144
- GitHub Docs, available rules for rulesets (required status checks, merge methods, conversation resolution): https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets
- GitHub Docs, troubleshooting failures when Dependabot triggers existing workflows (read-only `GITHUB_TOKEN`, the `permissions` key; revision 3): https://docs.github.com/en/code-security/reference/supply-chain-security/troubleshoot-dependabot/dependabot-on-actions
- GitHub REST API, create a review comment for a pull request (`subject_type`; revision 3): https://docs.github.com/en/rest/pulls/comments#create-a-review-comment-for-a-pull-request
- GitHub Docs, events that trigger workflows (revision 3): https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows
