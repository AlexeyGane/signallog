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
               Description = 'Branch <type>/AB<id>-<description> from main. Done when tests and docs are updated and a pull request is open.' }
            @{ Name = 'Review'; Type = 'inProgress'; State = 'Resolved'; Limit = 2; Split = $false
               Description = 'Pull request title has AB#<id>; CI green; self-review checklist complete. Done when squash-merged.' }
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
            )
        }
    )
}
