# Desired state of the SignalLog Azure Boards project (ADR 0003).
# Initialize-AzureBoards.ps1 applies this file; it is safe to run repeatedly.
@{
    Project      = @{
        Name        = 'SignalLog'
        Description = 'Cloud-native, event-driven commodity market data platform on Azure (.NET 10). Code: https://github.com/AlexeyGane/signallog'
        Process     = 'Agile'
        # Public projects are not available to new organizations (Azure DevOps Sprint 258/260 release notes).
        Visibility  = 'private'
    }

    # One area per C4 container plus cross-cutting areas. The single team owns the root with children.
    Areas        = @('Architecture', 'Platform', 'Adapters', 'Ingress', 'Ingestion', 'Api', 'Web')

    # Scrumban has no sprints. Monthly iterations are the replenishment and review cadence
    # and give Delivery Plans a calendar. Paths: SignalLog\<yyyy>\<yyyy-MM>.
    Cadence      = @{
        FirstMonth = '2026-11'
        Months     = 6
    }

    Team         = @{
        WorkingDays         = @('monday', 'tuesday', 'wednesday', 'thursday', 'friday')
        # Bugs flow through the board like stories: one branch per Story or Bug (branching standard).
        BugsBehavior        = 'asRequirements'
        BacklogVisibilities = @{
            'Microsoft.EpicCategory'        = $true
            'Microsoft.FeatureCategory'     = $true
            'Microsoft.RequirementCategory' = $true
        }
    }

    # Scrumban board for the requirement level. WIP limits are sized for one person.
    # Column descriptions are shown on the board as the column's Definition of Done.
    Board        = @{
        Name    = 'Stories'
        Columns = @(
            @{ Name = 'Backlog'; Type = 'incoming'; State = 'New'; Limit = 0; Split = $false
               Description = '' }
            @{ Name = 'Ready'; Type = 'inProgress'; State = 'New'; Limit = 3; Split = $false
               Description = 'Definition of Ready: acceptance criteria written; related ADR/NFR linked; small enough to finish within 2 working days.' }
            @{ Name = 'In Progress'; Type = 'inProgress'; State = 'Active'; Limit = 2; Split = $true
               Description = 'Work item Active, branch <type>/AB<id>-<description> from main. Done when the change is implemented, checked and the evidence comment is in the work item.' }
            @{ Name = 'Review'; Type = 'inProgress'; State = 'Resolved'; Limit = 2; Split = $false
               Description = 'Pull request open with AB#<id> in title and description; CI green; every file Viewed. Done when squash-merged, deployed, the result is recorded in the work item and the owner closes it by hand.' }
            @{ Name = 'Done'; Type = 'outgoing'; State = 'Closed'; Limit = 0; Split = $false
               Description = '' }
        )
        # Class of service for incidents and urgent bugs; sits above the default lane.
        Lanes   = @('Expedite')
    }

    DeliveryPlan = @{
        Name     = 'SignalLog Roadmap'
        Category = 'Microsoft.FeatureCategory'
    }

    # Seed backlog. Items are matched by type and title; existing items are left untouched.
    WorkItems    = @(
        @{
            Type        = 'Epic'
            Title       = 'Platform Foundation'
            Area        = 'Platform'
            Tags        = 'foundation'
            Description = 'Repository, build guardrails, CI/CD, Azure environments and the first end-to-end slice. Everything later increments build on.'
            Links       = @('https://github.com/AlexeyGane/signallog/blob/main/docs/adr/README.md')
            Children    = @(
                @{
                    Type        = 'Feature'
                    Title       = 'Walking skeleton'
                    Area        = 'Platform'
                    Description = 'Thinnest end-to-end slice: a replayed tick travels adapter → Service Bus → ingestion → Cosmos DB.'
                    Links       = @('https://github.com/AlexeyGane/signallog/blob/main/docs/adr/0006-compute-hosting.md')
                    Children    = @(
                        @{
                            Type               = 'User Story'
                            Title              = 'Solution skeleton'
                            Area               = 'Platform'
                            Tags               = 'ADR-0004; ADR-0012; ADR-0017'
                            AcceptanceCriteria = 'Solution builds with warnings as errors; banned-API fitness function passes; EventIds tests pass; CI workflow runs build, test, format and PR-title lint.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Replay adapter publishes a CloudEvents price tick'
                            Area               = 'Adapters'
                            Tags               = 'ADR-0011; ADR-0012'
                            AcceptanceCriteria = 'Timer-triggered replay adapter emits signallog.price.tick.v1 with a UUIDv7 id and traceparent; contract test validates against the v1 schema.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Ingestion persists a price tick idempotently'
                            Area               = 'Ingestion'
                            Tags               = 'ADR-0008; ADR-0009'
                            AcceptanceCriteria = 'Service Bus subscription persist upserts the tick into Cosmos DB; a redelivered message does not create a duplicate.'
                        }
                    )
                }
                @{
                    Type        = 'Feature'
                    Title       = 'Azure environment baseline'
                    Area        = 'Platform'
                    Description = 'Subscription guardrails and identities so that GitHub Actions can deploy without secrets.'
                    Links       = @('https://github.com/AlexeyGane/signallog/blob/main/docs/adr/0016-environments-and-infrastructure-as-code.md')
                    Children    = @(
                        @{
                            Type               = 'User Story'
                            Title              = 'Resource groups, budgets and tags for dev and prod'
                            Area               = 'Platform'
                            Tags               = 'ADR-0000; ADR-0016'
                            AcceptanceCriteria = 'rg-signallog-dev and rg-signallog-prod exist with required tags; budget alerts configured per ADR 0000; setup is scripted and idempotent.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'OIDC workload identity for GitHub Actions'
                            Area               = 'Platform'
                            Tags               = 'ADR-0004; ADR-0005'
                            AcceptanceCriteria = 'Federated credentials scoped to repository, branch and GitHub Environment; no client secret stored in GitHub; a workflow can run az account show.'
                        }
                    )
                }
                @{
                    Type        = 'Feature'
                    Title       = 'Documentation site'
                    Area        = 'Architecture'
                    Description = 'Public documentation site built from docs/ with Zensical and published to GitHub Pages; broken links and anchors fail the build.'
                    Links       = @('https://github.com/AlexeyGane/signallog/blob/main/docs/adr/0020-documentation-site.md')
                    Children    = @(
                        @{
                            Type               = 'User Story'
                            Title              = 'Decide the documentation site generator'
                            Area               = 'Architecture'
                            Tags               = 'ADR-0001; ADR-0020; NFR-DOC-01'
                            AcceptanceCriteria = 'ADR 0020 records the generator choice with a weighted evaluation; ADR 0001 is marked superseded; the documentation standard exists and is linked from ADR 0001.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Publish the documentation site to GitHub Pages'
                            Area               = 'Platform'
                            Tags               = 'ADR-0004; ADR-0020; NFR-DOC-01'
                            AcceptanceCriteria = 'zensical.toml with explicit navigation and a landing page; strict build passes locally and in CI; docs workflow builds on pull requests and deploys on main with SHA-pinned actions and hash-pinned Python packages; the site is reachable at https://alexeygane.github.io/signallog/.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Publish the cover note as an unlisted page'
                            Area               = 'Architecture'
                            Tags               = 'ADR-0020; NFR-DOC-01'
                            AcceptanceCriteria = 'The cover note is published at https://alexeygane.github.io/signallog/note/; it is not in the navigation, search or sitemap.xml and carries noindex; its links point to site pages and pass the strict build; the documentation standard describes unlisted pages.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Publish Fun Facts in English and Russian'
                            Area               = 'Architecture'
                            Tags               = 'ADR-0020; NFR-DOC-01'
                            AcceptanceCriteria = 'Fun facts are published in English and Russian, both in the navigation and linked to each other; every fact cites a source; the documentation standard describes Russian mirrors.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Mirror the cover note in English'
                            Area               = 'Architecture'
                            Tags               = 'ADR-0020; NFR-DOC-01'
                            AcceptanceCriteria = 'The cover note is generalised beyond one reader and published in English as an unlisted mirror of the Russian page, under the rules for unlisted pages and mirrors in the documentation standard.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Update the cover note'
                            Area               = 'Architecture'
                            Tags               = 'ADR-0020; NFR-DOC-01'
                            AcceptanceCriteria = 'The cover note at /note/ reflects the current state of the project and is ready to be sent to its reader (21 ADRs including 0020; CodeQL shown as planned, not as done; the change workflow standard referenced); it has a clickable table of contents with stable anchors (attr_list enabled in zensical.toml, no other page changes); every link resolves and the strict site build passes; it stays unlisted (not in nav, search or sitemap.xml, noindex); Fun facts gain two stories in English and Russian with primary sources: the fitness function and the tj-actions/changed-files tag incident; the repository file is the source of the note and the Claude document copy points to the site as the current version.'
                        }
                    )
                }
                @{
                    Type        = 'Feature'
                    Title       = 'Change workflow'
                    Area        = 'Platform'
                    Tags        = 'ADR-0002; ADR-0003; ADR-0004'
                    Description = 'Every change starts as a work item on the board and ends when its owner closes it by hand: implementation, evidence in the work item, green pull request, review with every file marked Viewed, squash merge, deployment and the result recorded in the work item.'
                    Links       = @('https://github.com/AlexeyGane/signallog/blob/main/docs/standards/change-workflow.md')
                    Children    = @(
                        @{
                            Type               = 'User Story'
                            Title              = 'Publish the change workflow standard'
                            Area               = 'Platform'
                            Tags               = 'ADR-0002; ADR-0003'
                            AcceptanceCriteria = 'docs/standards/change-workflow.md (English) describes the lifecycle, conventions, PR description, work item rules, review gate and safeguards, is in the site navigation and linked from the branching standard; the pull request template has What / Acceptance criteria / Checks sections with AB# in the description; board column descriptions match the workflow; strict site build passes.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Extract shared change functions into a PowerShell module'
                            Area               = 'Platform'
                            Tags               = 'ADR-0003; ADR-0004'
                            AcceptanceCriteria = 'eng/scripts/SignalLog.Change.psm1 holds the shared steps (work item create and state, evidence and result comments, blob checks, signed commit, pull request, checks, review gate, merge wait, deployment wait, result checks); a change script contains only its parameters and result checks; the module parses and its tests pass.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Require all files viewed before merging to main'
                            Area               = 'Platform'
                            Tags               = 'ADR-0002; ADR-0004'
                            AcceptanceCriteria = 'A ruleset on main requires a pull request, allows squash merges only and requires the CI checks and the review/all-files-viewed status; the review gate sets that status only when every file of the pull request is Viewed by the owner; a new push resets it.<br><br>GitHub settings as code: the main-protection ruleset and the repository merge settings (squash only, delete_branch_on_merge = true, which is today switched on by hand) are described in the repository and applied by one idempotent script under eng/github.<br><br>The settings script has a drift check mode that applies nothing and lists every difference between the repository description and GitHub, with a non-zero exit code when there is one.<br><br>The ruleset requires the status checks pr-title, build (ci.yml) and review/all-files-viewed; check names are unique across workflows: the job build in docs.yml is renamed site.<br><br>The meaning of require_extra_approval_for_unattributed_changes in the ruleset is found in GitHub documentation and the chosen value is recorded with its source and the date checked.<br><br>The header comment of .github/workflows/ci.yml names the required checks as they are actually configured.<br><br>Section 9 (Enforcement) of docs/standards/branching-and-release.md matches the configuration: the PR title check is in place (no longer planned), the required checks and the review gate are listed, and it links the change workflow standard.<br><br>eng/azure-devops/boards.settings.psd1 lists the User Story "Update the cover note" (AB#19) under the Feature "Documentation site" with its tags and acceptance criteria as on the board, so the board settings describe every work item that exists.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Renew the Azure DevOps token during long change runs'
                            Area               = 'Platform'
                            Tags               = 'ADR-0003'
                            AcceptanceCriteria = 'The change module takes a new Azure DevOps token from the Azure CLI when the current one is 30 minutes old and, once, when Azure DevOps answers with a sign-in page instead of JSON, then repeats the request; a second sign-in page stops the run with a clear message instead of property errors; a token given for tests is never replaced; Pester tests cover these cases and pass locally and in CI; the change workflow standard lists the safeguard.'
                        }
                    )
                }
                @{
                    Type        = 'Feature'
                    Title       = 'Domain knowledge base'
                    Area        = 'Architecture'
                    Tags        = 'ADR-0011; ADR-0014; ADR-0017'
                    Description = 'Domain pages under docs/domain (glossary, model, time and delivery, tenors, market data sources, market conventions) stay accurate: every fact has a primary source with the date checked, inferences are marked, open questions are tracked and closed.'
                    Links       = @('https://github.com/AlexeyGane/signallog/tree/main/docs/domain')
                    Children    = @(
                        @{
                            Type               = 'User Story'
                            Title              = 'Resolve the London TTF listing question'
                            Area               = 'Architecture'
                            Tags               = 'ADR-0011; ADR-0014'
                            AcceptanceCriteria = 'docs/domain/market-data-sources.md states, with ICE as the source and the date checked, that ICE Futures Europe launched Dutch TTF futures (IFEU, code TFN) on 2023-02-20 as a mirror of ICE Endex outside the EU Market Correction Mechanism, and what ICE shows for the contract today; the open question is closed or narrowed to what remains unknown (for example, liquidity); the instrument identifiers for the two venues stay distinct; strict site build passes.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Correct the session anchor zone of ICE futures'
                            Area               = 'Architecture'
                            Tags               = 'ADR-0017'
                            AcceptanceCriteria = 'docs/domain/market-conventions.md gives the TTF (NDEX TFM) session in the zone ICE anchors it to, with an ICE source and the date checked, instead of "20:50-18:00 New York (inferred anchor)": on 2026-11-06 ICE shows 00:50-22:00 London and 19:50-17:00 New York, an hour earlier in New York than on 2026-10-30, so the anchor is European, not New York; the Brent and JKM rows are checked the same way and confirmed or corrected; the New York inference in docs/domain/time-and-delivery.md, the glossary example and the open question on the anchor zone are corrected or closed; an example in an ADR or business rule that turns out wrong is changed by a numbered revision, not rewritten; strict site build passes.'
                        }
                    )
                }
                @{
                    Type        = 'Feature'
                    Title       = 'Supply chain security'
                    Area        = 'Platform'
                    Tags        = 'ADR-0002; ADR-0004; NFR-SEC-03'
                    Description = 'Dependencies, actions and code are checked before they reach main: Dependabot, NuGet audit, secret scanning with push protection, actions pinned by SHA and CodeQL code scanning.'
                    Links       = @('https://github.com/AlexeyGane/signallog/blob/main/docs/requirements/nfr.md#nfr-sec-03')
                    Children    = @(
                        @{
                            Type               = 'User Story'
                            Title              = 'Run CodeQL code scanning'
                            Area               = 'Platform'
                            Tags               = 'ADR-0004; NFR-SEC-03'
                            AcceptanceCriteria = '.github/workflows/codeql.yml analyses C# (build mode none) and the GitHub Actions workflows with the security-extended query suite on every pull request, on push to main and weekly; actions are pinned by full commit SHA to a release at least two weeks old; the job names are unique across workflows; GitHub default setup for code scanning is off; the first analysis on main uploads results to code scanning; the cover note no longer shows CodeQL as planned.'
                        }
                    )
                }
            )
        }
    )
}
