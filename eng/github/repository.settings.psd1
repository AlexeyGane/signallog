# Desired state of the GitHub repository settings (ADR 0002 revision 2, ADR 0004).
# Applied by Initialize-GitHubSettings.ps1; -Check lists every difference from GitHub and changes nothing.
# Only the keys listed here are managed; anything else on GitHub is left as it is.
# Snapshot this was built from: GitHub API, 2026-11-07.
@{
    Repository          = 'AlexeyGane/signallog'

    # PATCH /repos/{owner}/{repo}
    Settings            = @{
        allow_squash_merge          = $true
        allow_merge_commit          = $false
        allow_rebase_merge          = $false
        allow_auto_merge            = $false      # the owner merges by hand (change workflow)
        delete_branch_on_merge      = $true
        allow_update_branch         = $true
        squash_merge_commit_title   = 'PR_TITLE'  # the squash commit subject is the Conventional Commits title
        squash_merge_commit_message = 'PR_BODY'
        web_commit_signoff_required = $false      # commits are signed instead (gpg.format ssh)
        has_issues                  = $true
        has_wiki                    = $false
        has_projects                = $false
        has_discussions             = $false
    }

    # security_and_analysis in PATCH /repos/{owner}/{repo}
    SecurityAndAnalysis = @{
        secret_scanning                 = 'enabled'
        secret_scanning_push_protection = 'enabled'
        dependabot_security_updates     = 'enabled'
    }

    # PUT /repos/{owner}/{repo}/actions/permissions/workflow
    WorkflowPermissions = @{
        default_workflow_permissions     = 'read'
        can_approve_pull_request_reviews = $false
    }

    # PUT /repos/{owner}/{repo}/pages (GitHub Pages built by the docs workflow, ADR 0020)
    Pages               = @{
        build_type = 'workflow'
    }

    # PUT /repos/{owner}/{repo}/rulesets/{id}, found by name (POST when missing)
    Rulesets            = @(
        @{
            name          = 'main-protection'
            target        = 'branch'
            enforcement   = 'active'
            bypass_actors = @()
            conditions    = @{ ref_name = @{ include = @('~DEFAULT_BRANCH'); exclude = @() } }
            rules         = @(
                @{ type = 'deletion' }
                @{ type = 'non_fast_forward' }
                @{ type = 'required_linear_history' }
                @{
                    type       = 'pull_request'
                    parameters = @{
                        # A solo owner cannot approve their own pull request; the review gate replaces approval
                        required_approving_review_count                 = 0
                        dismiss_stale_reviews_on_push                   = $false
                        required_reviewers                              = @()
                        require_code_owner_review                       = $false
                        require_last_push_approval                      = $false
                        required_review_thread_resolution               = $true
                        # "Additional approval for unattributed Copilot pull requests" (GitHub default; no effect with
                        # 0 approvals, ADR 0002 revision 2)
                        require_extra_approval_for_unattributed_changes = $true
                        allowed_merge_methods                           = @('squash')
                    }
                }
                @{
                    type       = 'required_status_checks'
                    parameters = @{
                        strict_required_status_checks_policy = $false
                        do_not_enforce_on_create             = $false
                        # ci.yml jobs (GitHub Actions app 15368) and the review gate commit status (set by the owner)
                        required_status_checks               = @(
                            @{ context = 'pr-title'; integration_id = 15368 }
                            @{ context = 'build'; integration_id = 15368 }
                            @{ context = 'review/all-files-viewed' }
                        )
                    }
                }
            )
        }
    )
}
