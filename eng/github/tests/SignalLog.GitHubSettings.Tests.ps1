# Pester 5 tests for eng/github/SignalLog.GitHubSettings.psm1 and repository.settings.psd1.
# gh is mocked; the GitHub answers below are trimmed from the API snapshot of 2026-11-07.
# Run: Invoke-Pester -Path eng/github/tests -Output Detailed

BeforeAll {
    # A copy loaded from another path (for example main while testing a staged change) makes Mock -ModuleName ambiguous
    Get-Module -Name SignalLog.GitHubSettings | Remove-Module -Force
    $root = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path -Path $root -ChildPath 'SignalLog.GitHubSettings.psm1') -Force
    $desired = Import-PowerShellDataFile -LiteralPath (Join-Path -Path $root -ChildPath 'repository.settings.psd1')

    function New-Snapshot {
        # GitHub as it was on 2026-11-07, before AB#18: no required status checks
        $repository = @'
{ "allow_squash_merge": true, "allow_merge_commit": false, "allow_rebase_merge": false, "allow_auto_merge": false,
  "delete_branch_on_merge": true, "allow_update_branch": true, "squash_merge_commit_title": "PR_TITLE",
  "squash_merge_commit_message": "PR_BODY", "web_commit_signoff_required": false, "has_issues": true,
  "has_wiki": false, "has_projects": false, "has_discussions": false, "visibility": "public",
  "security_and_analysis": { "secret_scanning": { "status": "enabled" }, "secret_scanning_push_protection": { "status": "enabled" },
    "dependabot_security_updates": { "status": "enabled" }, "secret_scanning_validity_checks": { "status": "disabled" } } }
'@ | ConvertFrom-Json
        $ruleset = @'
{ "id": 25552935, "name": "main-protection", "target": "branch", "enforcement": "active", "bypass_actors": [],
  "conditions": { "ref_name": { "exclude": [], "include": ["~DEFAULT_BRANCH"] } },
  "rules": [ { "type": "deletion" }, { "type": "non_fast_forward" }, { "type": "required_linear_history" },
    { "type": "pull_request", "parameters": { "required_approving_review_count": 0, "dismiss_stale_reviews_on_push": false,
      "required_reviewers": [], "require_code_owner_review": false, "require_last_push_approval": false,
      "required_review_thread_resolution": true, "require_extra_approval_for_unattributed_changes": true,
      "allowed_merge_methods": ["squash"] } } ] }
'@ | ConvertFrom-Json
        return @{
            Repository = $repository
            Workflow   = ('{ "default_workflow_permissions": "read", "can_approve_pull_request_reviews": false }' | ConvertFrom-Json)
            Pages      = ('{ "build_type": "workflow", "html_url": "https://alexeygane.github.io/signallog/" }' | ConvertFrom-Json)
            Rulesets   = @($ruleset)
        }
    }

    function Add-StatusChecks($Snapshot, [string[]] $Contexts = @('pr-title', 'build', 'review-threads')) {
        $checks = foreach ($c in $Contexts) { [pscustomobject]@{ context = $c; integration_id = 15368 } }
        $rule = [pscustomobject]@{ type = 'required_status_checks'; parameters = [pscustomobject]@{
                strict_required_status_checks_policy = $false; do_not_enforce_on_create = $false; required_status_checks = @($checks) } }
        $Snapshot.Rulesets[0].rules = @($Snapshot.Rulesets[0].rules) + $rule
        return $Snapshot
    }
}

AfterAll {
    Remove-Module SignalLog.GitHubSettings -Force -ErrorAction SilentlyContinue
}

Describe 'Module and settings file' {
    It 'parses without errors' {
        foreach ($file in @('SignalLog.GitHubSettings.psm1', 'Initialize-GitHubSettings.ps1')) {
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root $file), [ref] $null, [ref] $errors) | Out-Null
            $errors | Should -BeNullOrEmpty -Because $file
        }
    }
    It 'requires pr-title, build and the review gate, all from GitHub Actions, on main' {
        $rule = $desired.Rulesets[0].rules | Where-Object { $_.type -eq 'required_status_checks' }
        @($rule.parameters.required_status_checks | ForEach-Object { $_.context }) | Should -Be @('pr-title', 'build', 'review-threads')
        @($rule.parameters.required_status_checks | ForEach-Object { $_.integration_id }) | Should -Be @(15368, 15368, 15368)
    }
    It 'requires every review thread to be resolved (the review gate)' {
        $pr = $desired.Rulesets[0].rules | Where-Object { $_.type -eq 'pull_request' }
        $pr.parameters.required_review_thread_resolution | Should -BeTrue
    }
    It 'requires the job of the review-threads workflow by its name' {
        $workflow = Get-Content -LiteralPath (Join-Path (Split-Path -Parent (Split-Path -Parent $root)) '.github/workflows/review-threads.yml') -Raw
        $workflow | Should -Match '(?m)^  review-threads:\r?\n    name: review-threads\r?$'
        $workflow | Should -Match '(?m)^      pull-requests: write\r?$'
    }
    It 'allows squash merges only and keeps zero approvals' {
        $desired.Settings.allow_merge_commit | Should -BeFalse
        $desired.Settings.allow_rebase_merge | Should -BeFalse
        $pr = $desired.Rulesets[0].rules | Where-Object { $_.type -eq 'pull_request' }
        $pr.parameters.required_approving_review_count | Should -Be 0
        $pr.parameters.allowed_merge_methods | Should -Be @('squash')
    }
}

Describe 'Test-SettingsMatch' {
    It 'accepts extra keys on the GitHub side' {
        Test-SettingsMatch @{ a = 1 } ([pscustomobject]@{ a = 1; b = 2 }) | Should -BeTrue
    }
    It 'compares booleans and numbers with JSON values' {
        $json = '{ "flag": true, "count": 0 }' | ConvertFrom-Json
        Test-SettingsMatch @{ flag = $true; count = 0 } $json | Should -BeTrue
        Test-SettingsMatch @{ flag = $false } $json | Should -BeFalse
    }
    It 'matches lists in any order but not with a different length' {
        Test-SettingsMatch @('a', 'b') @('b', 'a') | Should -BeTrue
        Test-SettingsMatch @('a') @('a', 'b') | Should -BeFalse
        Test-SettingsMatch @() @() | Should -BeTrue
    }
    It 'matches list elements by subset' {
        $actual = '[ { "context": "build", "integration_id": 15368 }, { "context": "review-threads", "integration_id": 15368 } ]' | ConvertFrom-Json
        Test-SettingsMatch @(@{ context = 'review-threads' }, @{ context = 'build'; integration_id = 15368 }) $actual | Should -BeTrue
        Test-SettingsMatch @(@{ context = 'pr-title' }, @{ context = 'build' }) $actual | Should -BeFalse
    }
    It 'treats a missing value as a difference' {
        Test-SettingsMatch @{ a = 1 } ([pscustomobject]@{ b = 1 }) | Should -BeFalse
    }
}

Describe 'Get-SettingsDrift' {
    It 'finds exactly the missing required status checks in the snapshot of 2026-11-07' {
        $drift = Get-SettingsDrift -Desired $desired -Actual (New-Snapshot)
        $drift.Count | Should -Be 1
        $drift[0].Area | Should -Be 'Ruleset main-protection'
        $drift[0].Name | Should -Be 'rules.required_status_checks'
    }
    It 'finds nothing once the status checks are in place' {
        (Get-SettingsDrift -Desired $desired -Actual (Add-StatusChecks (New-Snapshot))).Count | Should -Be 0
    }
    It 'reports a missing required check by name' {
        $drift = Get-SettingsDrift -Desired $desired -Actual (Add-StatusChecks (New-Snapshot) @('pr-title', 'build'))
        $drift.Count | Should -Be 1
        $drift[0].Name | Should -Be 'rules.required_status_checks.required_status_checks'
    }
    It 'reports a changed repository setting and a disabled security feature' {
        $snapshot = Add-StatusChecks (New-Snapshot)
        $snapshot.Repository.delete_branch_on_merge = $false
        $snapshot.Repository.security_and_analysis.secret_scanning_push_protection.status = 'disabled'
        $names = (Get-SettingsDrift -Desired $desired -Actual $snapshot) | ForEach-Object { "$($_.Area)/$($_.Name)" }
        $names | Should -Contain 'Settings/delete_branch_on_merge'
        $names | Should -Contain 'SecurityAndAnalysis/secret_scanning_push_protection'
    }
    It 'reports a rule on GitHub that the file does not list' {
        $snapshot = Add-StatusChecks (New-Snapshot)
        $snapshot.Rulesets[0].rules = @($snapshot.Rulesets[0].rules) + [pscustomobject]@{ type = 'creation' }
        $drift = Get-SettingsDrift -Desired $desired -Actual $snapshot
        $drift.Count | Should -Be 1
        $drift[0].Name | Should -Be 'rules.creation'
        $drift[0].Actual | Should -Be 'present'
    }
    It 'reports a ruleset missing on GitHub' {
        $snapshot = New-Snapshot
        $snapshot.Rulesets = @()
        $drift = Get-SettingsDrift -Desired $desired -Actual $snapshot
        $drift.Count | Should -Be 1
        $drift[0].Name | Should -Be '(ruleset)'
    }
    It 'ignores settings the file does not manage' {
        $snapshot = Add-StatusChecks (New-Snapshot)
        $snapshot.Repository.security_and_analysis.secret_scanning_validity_checks.status = 'enabled'
        (Get-SettingsDrift -Desired $desired -Actual $snapshot).Count | Should -Be 0
    }
}

Describe 'ConvertTo-RulesetBody' {
    It 'keeps single-element lists as JSON arrays' {
        $body = ConvertTo-RulesetBody -Ruleset $desired.Rulesets[0] | ConvertFrom-Json
        @($body.conditions.ref_name.include).Count | Should -Be 1
        $body.conditions.ref_name.include[0] | Should -Be '~DEFAULT_BRANCH'
        ($body.rules | Where-Object { $_.type -eq 'pull_request' }).parameters.allowed_merge_methods | Should -Be @('squash')
        @(($body.rules | Where-Object { $_.type -eq 'required_status_checks' }).parameters.required_status_checks).Count | Should -Be 3
    }
}

Describe 'Set-GitHubState' {
    It 'updates only the ruleset when only the ruleset differs' {
        Mock -ModuleName SignalLog.GitHubSettings Invoke-GhApi { }
        $snapshot = New-Snapshot
        $drift = Get-SettingsDrift -Desired $desired -Actual $snapshot
        Set-GitHubState -Desired $desired -Actual $snapshot -Drift $drift 6>$null
        Should -Invoke -ModuleName SignalLog.GitHubSettings Invoke-GhApi -Times 1 -Exactly
        Should -Invoke -ModuleName SignalLog.GitHubSettings Invoke-GhApi -ParameterFilter { $Method -eq 'PUT' -and $Path -eq 'repos/AlexeyGane/signallog/rulesets/25552935' } -Times 1 -Exactly
    }
    It 'creates the ruleset when it is missing' {
        Mock -ModuleName SignalLog.GitHubSettings Invoke-GhApi { }
        $snapshot = New-Snapshot
        $snapshot.Rulesets = @()
        $drift = Get-SettingsDrift -Desired $desired -Actual $snapshot
        Set-GitHubState -Desired $desired -Actual $snapshot -Drift $drift 6>$null
        Should -Invoke -ModuleName SignalLog.GitHubSettings Invoke-GhApi -ParameterFilter { $Method -eq 'POST' -and $Path -eq 'repos/AlexeyGane/signallog/rulesets' } -Times 1 -Exactly
    }
    It 'sends security features as status objects' {
        Mock -ModuleName SignalLog.GitHubSettings Invoke-GhApi { }
        $snapshot = Add-StatusChecks (New-Snapshot)
        $snapshot.Repository.security_and_analysis.secret_scanning.status = 'disabled'
        $drift = Get-SettingsDrift -Desired $desired -Actual $snapshot
        Set-GitHubState -Desired $desired -Actual $snapshot -Drift $drift 6>$null
        Should -Invoke -ModuleName SignalLog.GitHubSettings Invoke-GhApi -ParameterFilter {
            $Method -eq 'PATCH' -and ($Body | ConvertFrom-Json).security_and_analysis.secret_scanning.status -eq 'enabled'
        } -Times 1 -Exactly
    }
}
