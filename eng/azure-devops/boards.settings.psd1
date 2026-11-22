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
               Description = 'Pull request open with AB#<id> in title and description; CI green; every review thread resolved. Done when squash-merged, deployed, the result is recorded in the work item and the owner closes it by hand.' }
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
                    Description = 'Thinnest end-to-end slice: a replayed tick travels adapter → API Management → ingress function → Service Bus → ingestion → Cosmos DB (ADR 0009, ADR 0010).'
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
                            Title              = 'Define the PriceTick v1 contract'
                            Area               = 'Platform'
                            Tags               = 'ADR-0012; ADR-0014; ADR-0017; NFR-MNT-02'
                            AcceptanceCriteria = 'contracts/schemas/price-tick/v1.json (JSON Schema 2020-12) describes the CloudEvents envelope and data of signallog.price.tick.v1 as in ADR 0012, with instrument ids as in ADR 0014 and UTC timestamps as in ADR 0017, and allows unknown fields; SignalLog.Contracts holds the envelope and data types, one set of serializer options (decimal as JSON number, enums upper-case, UTC with Z) and a producer helper that sets a UUIDv7 id, time, type, dataschema and traceparent; contract tests in CI show that produced events and the samples validate, that a consumer reads a sample with unknown fields, and that invalid messages are rejected by the schema and by the deserializer.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Complete the PriceTick v1 contract with the review follow-ups'
                            Area               = 'Platform'
                            Tags               = 'ADR-0012; ADR-0017'
                            AcceptanceCriteria = 'The timestamp error of ContractJson tells a JSON null, an empty string and a value without Z apart, and a contract test covers the three cases; contracts/README.md and the consumer test name the unknown fields of valid-unknown-fields.json (partitionkey, data.openInterest), and the test checks that they are present; Fun facts explain the term wire format used in the contract code, in English and Russian; the build and the contract tests pass locally and in CI.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Replay adapter publishes a CloudEvents price tick'
                            Area               = 'Adapters'
                            Tags               = 'ADR-0010; ADR-0011; ADR-0012; ADR-0013'
                            AcceptanceCriteria = 'IMarketDataSource is the single source abstraction (ADR 0011); the replay source gives one synthetic last price per configured instrument, marked REPLAY, as a pure function of seed, instrument and time (reproducible across instances and runs, within a band around the base price, on the tick grid, small steps from minute to minute), with defaults near the market of November 2026; the timer-triggered function ReplayAdapter (no hyphen, ADR 0013) wraps each tick in signallog.price.tick.v1 with PriceTickEvents.Create, so every event has a UUIDv7 id, source /adapters/replay and the traceparent of the run, joined to the trace of the invocation; HttpTickPublisher posts each event in CloudEvents structured mode to the ingress endpoint /v1/ticks from the app setting Ingress__Endpoint (ADR 0010); tests in CI show that the produced events validate against the v1 schema, that the prices are reproducible and bounded, that all events of a run share its trace and have unique ids, and how the publisher posts and fails; the Walking skeleton description follows the ingestion path of ADR 0010.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Explain how the replay source generates prices'
                            Area               = 'Adapters'
                            Tags               = 'ADR-0011; ADR-0012'
                            AcceptanceCriteria = 'docs/domain/replay-price-generator.md explains why the replay price is a pure function of seed, instrument and time, how SplitMix64 and FNV-1a give reproducible random values at the knots and why System.Random and string.GetHashCode are not used, how cosine interpolation and the two noise layers shape the line, how the band and the tick grid are applied in decimal, and how large one minute''s step can be; charts and figures come from running ReplaySource; each property is mapped to its test; limits and next steps are listed; sources are cited with the date checked; the page is in the domain README and the site navigation, and the strict site build passes.'
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
                    Title       = 'Citations and references'
                    Area        = 'Architecture'
                    Tags        = 'ADR-0021; NFR-DOC-01'
                    Description = 'Every external fact in the documentation and the code cites one entry of a single bibliography by a stable key; terms and concepts link to their registers; links from code resolve on the site; CI keeps it so.'
                    Links       = @('https://github.com/AlexeyGane/signallog/blob/main/docs/adr/0021-citation-and-reference-model.md')
                    Children    = @(
                        @{
                            Type               = 'User Story'
                            Title              = 'Record the citation and reference model in ADR 0021'
                            Area               = 'Architecture'
                            Tags               = 'ADR-0021; ADR-0020; NFR-DOC-01'
                            AcceptanceCriteria = 'docs/adr/0021-citation-and-reference-model.md is Accepted and records options A-D (source lists per page, full footnotes per page, Pandoc keys with a plugin, shortened footnotes with one bibliography), the drivers and the consequences; docs/standards/references.md describes keys, entry fields, footnotes, roles of sources, the date checked and the date of a fact, links from code and explicit anchors, and says that converting citations in an Accepted ADR is an editorial change; the documentation standard, the ADR conventions, the domain conventions, the concepts page and the ADR template point to it; the Feature and its stories are in boards.settings.psd1; the strict build passes.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Publish the bibliography from sources.toml'
                            Area               = 'Architecture'
                            Tags               = 'ADR-0021; NFR-DOC-01'
                            AcceptanceCriteria = 'zensical.toml enables footnotes, abbr, pymdownx.snippets with auto_append of includes/abbreviations.md and the feature content.footnote.tooltips; docs/references/sources.toml holds entries with CSL field names, tier and stability; eng/docs/build_references.py validates the entries and writes docs/references/index.md with one anchor per key, entries grouped by kind and a Cited in list, and --check fails when the entries are invalid or the page is out of date; unittest tests cover the generator, and the docs workflow runs them and --check before the build; docs/domain/replay-price-generator.md, ADR 0021 and the documentation standard cite their sources by footnotes, and the replay page has explicit anchors knots, splitmix64, uniform, instrument-key and two-layers; eng/docs/references-legacy.txt lists the pages that are not migrated yet; the strict build passes.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Check citations and links from code in CI'
                            Area               = 'Platform'
                            Tags               = 'ADR-0021; ADR-0004; NFR-DOC-01'
                            AcceptanceCriteria = 'eng/docs/check_references.py reports unused footnotes, external URLs outside the bibliography, bibliography entries that are cited nowhere and not marked further_reading, unused concepts, different keys in an English page and its Russian mirror, links from code and configuration to site pages or anchors that do not exist, and ADR, NFR or BR ids and source keys in code that do not exist; pages listed in eng/docs/references-legacy.txt get warnings, all others errors; the docs workflow runs build_references.py --check and the checker after the build and also runs on changes under src/, tests/, contracts/ and eng/azure-devops/; links, identifiers and source keys in code are errors from the start, because code has no legacy list; the pull request template asks whether external sources are cited by key; unittest tests cover each kind of finding; the workflow tests pass.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Cite sources by key on the domain pages'
                            Area               = 'Architecture'
                            Tags               = 'ADR-0021; ADR-0011; ADR-0014; ADR-0017'
                            AcceptanceCriteria = 'market-data-sources, market-conventions, tenors-and-delivery-periods, time-and-delivery and model cite every external fact by a footnote to the bibliography; no external URL and no checked date remains on these pages, and the date of a fact stays in the text; every source is read again and its accessed date set, and a statement that its source does not support is corrected, marked unverified or removed; dates in the text are ISO 8601, except where a column spells out how an identifier reads; concepts are linked at first use and each page links the glossary (links to single terms follow when terms get anchors); the pages are removed from the legacy list; the bibliography accepts the CSL type legislation; the checker counts a footnote followed by a colon as used; the strict build and check_references.py report no errors.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Give every glossary term an anchor and a tooltip'
                            Area               = 'Architecture'
                            Tags               = 'ADR-0021; NFR-DOC-01'
                            AcceptanceCriteria = 'Every term in docs/domain/glossary.md has an explicit anchor; the sources of the glossary are footnotes to the bibliography; includes/abbreviations.md lists the abbreviations of the glossary and is appended to every page; links to glossary sections elsewhere point to terms; the page is removed from the legacy list.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Cite sources by key in ADRs 0000 to 0010'
                            Area               = 'Architecture'
                            Tags               = 'ADR-0021'
                            AcceptanceCriteria = 'External links in the text and in More Information of ADRs 0000 to 0010 are footnotes to the bibliography; More Information keeps only links to other decisions; no decision text changes; concepts are linked at first use; the files are removed from the legacy list.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Cite sources by key in ADRs 0011 to 0020 and the ADR log'
                            Area               = 'Architecture'
                            Tags               = 'ADR-0021'
                            AcceptanceCriteria = 'External links in ADRs 0011 to 0020 and in docs/adr/README.md are footnotes to the bibliography; More Information keeps only links to other decisions; no decision text changes; concepts are linked at first use; the files are removed from the legacy list.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Cite sources by key in the requirements and standards'
                            Area               = 'Architecture'
                            Tags               = 'ADR-0021; NFR-DOC-01'
                            AcceptanceCriteria = 'The requirements README, the NFR catalogue, the business rules, the branching and release standard, the change workflow standard and the C# coding standard cite external sources by footnotes; their Sources lists are footnotes or Further reading; the example in section 8 of the coding standard links to the explicit anchor #two-layers instead of #6-two-layers; the pages are removed from the legacy list.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Generate the concepts register with sources by role'
                            Area               = 'Architecture'
                            Tags               = 'ADR-0021; NFR-DOC-01'
                            AcceptanceCriteria = 'Concepts are kept in docs/standards/concepts.toml with sources by role (origin, definition, evidence, method or data, further reading, disputes) and links to stories, decisions and code; the concepts page is generated, and Used in is computed from links in the documentation; a concept that no page uses fails the check, and the unused entry for the queuing formula is removed; UUIDv7 and C4 are linked at first use on the pages that mention them.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Link Fun Facts and the cover note to the bibliography'
                            Area               = 'Architecture'
                            Tags               = 'ADR-0021; ADR-0020; NFR-DOC-01'
                            AcceptanceCriteria = 'Every fun fact has an explicit anchor, cites its sources by footnotes and ends with See also to its concept or decision, in English and Russian with the same keys and anchors; the concepts register links back to the stories; the references of the cover note point to bibliography entries; the pages are removed from the legacy list.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Document the replay constants and link them to the documentation'
                            Area               = 'Adapters'
                            Tags               = 'ADR-0021; ADR-0011'
                            AcceptanceCriteria = 'Every number literal with a meaning in ReplaySource is a named constant with a summary, its unit or no unit, the bibliography key of its source where it comes from a specification, and a seealso href to an explicit anchor of the replay generator page; the same holds for the other magic numbers in src: the GUID size (16 bytes) and the UUID version (7) in SignalLog.Contracts/EventIds.cs, the lengths and offsets of the traceparent parts in SignalLog.Contracts/Identifiers.cs, and the connection lifetime of the HTTP client (2 minutes) in SignalLog.Adapters/Program.cs; EventIds cites rfc-9562, the traceparent checks cite the W3C Trace Context recommendation and the currency summaries cite iso-4217 by key; section 8 of the coding standard describes constants from specifications and source keys in comments; the replay tests give the same prices as before; links from code are checked as errors; build and tests pass.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Check external links every week'
                            Area               = 'Platform'
                            Tags               = 'ADR-0021; ADR-0004'
                            AcceptanceCriteria = 'A scheduled workflow checks every URL in sources.toml once a week with lychee, the action pinned to a commit SHA, and lists living sources whose accessed date is older than 180 days; a failure does not block pull requests; the workflow tests pass.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Turn all citation checks into errors'
                            Area               = 'Platform'
                            Tags               = 'ADR-0021; NFR-DOC-01'
                            AcceptanceCriteria = 'eng/docs/references-legacy.txt is empty and removed, and the warning mode is removed from check_references.py; every finding fails the docs workflow; the documentation standard and the references standard say so.'
                        }
                    )
                }
                @{
                    Type        = 'Feature'
                    Title       = 'Change workflow'
                    Area        = 'Platform'
                    Tags        = 'ADR-0002; ADR-0003; ADR-0004'
                    Description = 'Every change starts as a work item on the board and ends when its owner closes it by hand: implementation, evidence in the work item, green pull request, review with a resolved thread on every file, squash merge, deployment and the result recorded in the work item.'
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
                        @{
                            Type               = 'User Story'
                            Title              = 'Stop a resumed change run when the pull request does not carry the staged files'
                            Area               = 'Platform'
                            Tags               = 'ADR-0003'
                            AcceptanceCriteria = 'When Invoke-Change finds the pull request of a change already open, it fetches the branch and, before it waits for CI and the merge, checks that every file of the change has its verified blob on the branch and that the branch changes no other file; any difference stops the run and lists the files; Pester tests cover a matching branch, an earlier blob, a missing file, an extra file, a failed fetch and the resumed Invoke-Change path, and pass locally and in CI; the change workflow standard describes the check.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Apply a change from the working copy on its branch'
                            Area               = 'Platform'
                            Tags               = 'ADR-0003; ADR-0004'
                            AcceptanceCriteria = 'A start script built on Start-Change makes the work item Active, updates main and checks out the change branch, refusing to leave uncommitted changes behind; with FromWorkingTree, Invoke-Change takes the files from the working copy on that branch instead of a staging folder, after checking that the branch is checked out with no commits beyond main, that the files match the verified baseline on origin/main, and that the working copy holds exactly the files of the change with their verified blobs and nothing else; Invoke-SolutionCheck runs the build job of ci.yml locally with the build and the banned API probe free of persistent build servers; Pester tests cover these cases and pass locally and in CI; the change workflow standard and the cover note describe branch mode.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Review every file through resolved review threads'
                            Area               = 'Platform'
                            Tags               = 'ADR-0002; ADR-0004'
                            AcceptanceCriteria = 'A workflow review-threads runs on every push to a pull request to main, with its own GITHUB_TOKEN (pull-requests: write, contents: read) and no personal access token, and opens one file-level review thread per changed file, Dependabot pull requests included.<br><br>On a later push it opens a new thread only for a file whose content (git blob) changed after its thread was resolved, replies in a thread that is still open when its file changes, leaves files with unchanged content alone and resolves its own threads of files that left the pull request; threads of people are never touched; running it again changes nothing.<br><br>The main-protection ruleset requires conversation resolution and the checks pr-title, build and review-threads; the commit status review/all-files-viewed, eng/github/Watch-ReviewGate.ps1 and the Viewed functions of the change module are gone; Initialize-GitHubSettings.ps1 -Check reports no difference after the change.<br><br>The plan of the workflow is a function covered by Pester tests (new pull request, unchanged, changed after resolution, changed while open, reverted, deleted file, file left the pull request, threads of people); staging mode can delete a file; all Pester tests pass locally and in CI.<br><br>ADR 0002 revision 3 records the decision with the options considered and its sources; the change workflow standard, the branching standard, the cover note, the pull request template and the board column descriptions describe the new gate; strict site build passes.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Run the tooling tests in their own process'
                            Area               = 'Platform'
                            Tags               = 'ADR-0004'
                            AcceptanceCriteria = 'The PowerShell tooling tests (eng/scripts/tests, eng/github/tests) run from the change module in a new pwsh process without the profile (Invoke-ToolingTest), so modules left in the session by earlier change scripts cannot change the result; Invoke-SolutionCheck runs them as its last step, like the build job of ci.yml, and fails on failed tests although Invoke-Pester exits 0, reading the result line instead.<br><br>Copy-ChangeTestTree builds the test copy for staging mode in the module: the files git knows in the working copy, the staged files with .github staged as github, without the files the change deletes, replacing an earlier copy; staging scripts no longer copy files themselves.<br><br>Pester tests cover the command line (both folders, a quoted path), the result line, a missing result, a real run in a new process, the solution check step and the test copy; with the nested-module situation of AB#33 recreated, Invoke-Pester in the session fails 3 tests and Invoke-ToolingTest passes all; all Pester tests pass locally and in CI.<br><br>The change workflow standard explains why the tooling tests run in their own process; strict site build passes.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Write down the C# coding standard'
                            Area               = 'Platform'
                            Tags               = 'ADR-0004; ADR-0012; ADR-0017'
                            AcceptanceCriteria = 'docs/standards/coding.md records the C# rules of the project and, for each, whether the build, dotnet format or the review enforces it: layout and usings, guard clauses followed by a blank line, explicit types, naming, sealed types and records, decimal prices, TimeProvider, UUIDv7 ids, regular expressions, async and cancellation, logging, comments, tests and suppressions; the rules match .editorconfig, Directory.Build.props and BannedSymbols.txt; the page is in the site navigation, the cover note and the concepts page link it, and the strict site build passes.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Move the coding rules from review to the build'
                            Area               = 'Platform'
                            Tags               = 'ADR-0004'
                            AcceptanceCriteria = 'The 16 rules of the coding standard that built-in .NET analyzers can check fail the build: the code-style options in .editorconfig use the severity suffix :warning, and CA1062, CA2007, CA1031, SYSLIB1045, IDE0005 and IDE2003 are warnings; a naming rule requires the Async suffix in src.<br><br>Tests are exempt from CA2007, CS1591 and the Async suffix, with a comment that says why; GenerateDocumentationFile is on in Directory.Build.props.<br><br>The 13 current violations are fixed; every rule moved has a probe in Appendix A of the coding standard, and its Enforced by entry says Build; the solution check and CI pass.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Run two changes at once in two working copies'
                            Area               = 'Platform'
                            Tags               = 'ADR-0002; ADR-0003'
                            AcceptanceCriteria = 'Two changes can run at the same time in two working copies (git worktree) of one repository: Update-MainBranch fetches origin/main, then switches to main and pulls in the copy that has main checked out, or detaches HEAD at origin/main when another copy has main; Start-Change creates a new change branch from origin/main and works from a detached HEAD; Test-ChangeBranch names a detached HEAD in its message; Pester tests cover the copy that owns main, the second copy, a single copy, a failed fetch and the start from a detached HEAD; docs/standards/change-workflow.md describes the two copies, the rule that two open changes share no file, locks and merge order; boards.settings.psd1 carries the acceptance criteria of AB#50 and AB#53 that are on the board; the tooling tests pass.'
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
                        @{
                            Type               = 'User Story'
                            Title              = 'Show the unit of every number in the documentation'
                            Area               = 'Platform'
                            Tags               = 'BR-PRICE-01'
                            AcceptanceCriteria = 'The day-ahead example on the tenors page shows its currency and unit (EUR/MWh); a search of the documentation finds no other price, tick size or quantity whose unit is missing from the number itself, its column header or its row label; the documentation standard has a writing rule for it; the strict site build passes.'
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
                        @{
                            Type               = 'User Story'
                            Title              = 'Keep the CodeQL action steps on one version'
                            Area               = 'Platform'
                            Tags               = 'ADR-0004; NFR-SEC-03'
                            AcceptanceCriteria = 'Both CodeQL steps in .github/workflows/codeql.yml (init and analyze) use github/codeql-action at the same commit, v4.39.3, its SHA taken from the action''s own repository; .github/dependabot.yml puts every github/codeql-action step in one group, so Dependabot updates them in a single pull request; a Pester test in CI checks every workflow: each action is pinned to a full commit SHA and all steps of one action use the same commit, and it fails on the codeql.yml of pull requests #33 and #34; ADR 0004 records the rule and its reason; CodeQL passes on the pull request; strict site build passes.'
                        }
                        @{
                            Type               = 'User Story'
                            Title              = 'Drop the stale version from the JsonSchema.Net comment'
                            Area               = 'Platform'
                            Tags               = 'ADR-0012'
                            AcceptanceCriteria = 'The comment above JsonSchema.Net in Directory.Packages.props no longer names a version and release date, which went stale when Dependabot moved the package from 9.4.1 to 9.6.0 (#36); it names what the package is for and that Dependabot keeps the version current; no other comment in Directory.Packages.props names a version; CI build and tests pass.'
                        }
                    )
                }
            )
        }
    )
}
