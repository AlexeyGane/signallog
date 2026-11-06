# Pester 5 tests for eng/scripts/SignalLog.Change.psm1. External commands (az, gh, git, Azure DevOps REST)
# are mocked; nothing here touches GitHub, Azure Boards or the working copy.
# Run: Invoke-Pester -Path eng/scripts/tests -Output Detailed

BeforeAll {
    # A copy loaded from another path (for example main while testing a staged change) makes Mock -ModuleName ambiguous
    Get-Module -Name SignalLog.Change | Remove-Module -Force
    $modulePath = Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'SignalLog.Change.psm1'
    Import-Module $modulePath -Force
    Initialize-ChangeContext -Staging (Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath 'signallog-change-tests') -Token 'test-token' | Out-Null
}

AfterAll {
    Remove-Module SignalLog.Change -Force -ErrorAction SilentlyContinue
}

Describe 'Module' {
    It 'parses without errors' {
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($modulePath, [ref] $null, [ref] $errors) | Out-Null
        $errors | Should -BeNullOrEmpty
    }

    It 'exports Invoke-Change and keeps the command wrappers private' {
        $commands = (Get-Module SignalLog.Change).ExportedFunctions.Keys
        $commands | Should -Contain 'Invoke-Change'
        $commands | Should -Not -Contain 'Invoke-Gh'
        $commands | Should -Not -Contain 'Invoke-Git'
    }

    It 'needs neither a staging folder nor a token with -GitHubOnly' {
        Mock -ModuleName SignalLog.Change Invoke-Az { throw 'az must not be called' }
        $ctx = Initialize-ChangeContext -GitHubOnly
        $ctx.Repository | Should -Be 'AlexeyGane/signallog'
        $ctx.Headers.Count | Should -Be 0
        Initialize-ChangeContext -Staging (Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath 'signallog-change-tests') -Token 'test-token' | Out-Null
    }

    It 'requires a staging folder for a full change' {
        { Initialize-ChangeContext -Token 'x' } | Should -Throw '*Staging*'
        Initialize-ChangeContext -Staging (Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath 'signallog-change-tests') -Token 'test-token' | Out-Null
    }

    It 'builds the context from the repository name' {
        $ctx = Get-ChangeContext
        $ctx.Owner | Should -Be 'AlexeyGane'
        $ctx.Name | Should -Be 'signallog'
        $ctx.BaseUrl | Should -Be 'https://dev.azure.com/alexeygane/SignalLog'
        $ctx.Headers.Authorization | Should -Be 'Bearer test-token'
    }
}

Describe 'Expand-ChangeText' {
    It 'replaces every placeholder' {
        Expand-ChangeText 'docs/AB{id}-x AB#{id} {evidence}' @{ id = 17; evidence = 'E' } | Should -Be 'docs/AB17-x AB#17 E'
    }
    It 'leaves text without placeholders alone' {
        Expand-ChangeText 'plain' @{ id = 1 } | Should -Be 'plain'
    }
}

Describe 'Get-StagedSourcePath' {
    It 'maps .github to github in the staging tree' {
        $p = Get-StagedSourcePath -Staging 'S' -Path '.github/pull_request_template.md'
        $p | Should -Be (Join-Path (Join-Path 'S' 'tree') 'github/pull_request_template.md')
    }
    It 'keeps other paths' {
        Get-StagedSourcePath -Staging 'S' -Path 'docs/note.md' | Should -Be (Join-Path (Join-Path 'S' 'tree') 'docs/note.md')
    }
    It 'does not touch names that only start with .github' {
        Get-StagedSourcePath -Staging 'S' -Path '.githubx/a' | Should -Be (Join-Path (Join-Path 'S' 'tree') '.githubx/a')
    }
}

Describe 'Resolve-CheckRun' {
    It 'is pending when there are no checks yet' {
        (Resolve-CheckRun -Checks @()).State | Should -Be 'pending'
    }
    It 'ignores a run cancelled by a newer run of the same check' {
        $checks = @(
            [pscustomobject]@{ name = 'build'; bucket = 'cancel' }
            [pscustomobject]@{ name = 'build'; bucket = 'pass' }
            [pscustomobject]@{ name = 'pr-title'; bucket = 'pass' }
        )
        $r = Resolve-CheckRun -Checks $checks
        $r.State | Should -Be 'pass'
        $r.Summary | Should -Be 'build=pass, pr-title=pass'
    }
    It 'treats a check with only cancelled runs as pending' {
        $r = Resolve-CheckRun -Checks @([pscustomobject]@{ name = 'build'; bucket = 'cancel' })
        $r.State | Should -Be 'pending'
    }
    It 'fails on a red check and names it' {
        $checks = @(
            [pscustomobject]@{ name = 'build'; bucket = 'fail' }
            [pscustomobject]@{ name = 'pr-title'; bucket = 'pass' }
        )
        $r = Resolve-CheckRun -Checks $checks
        $r.State | Should -Be 'fail'
        $r.Failed | Should -Be @('build')
    }
    It 'counts skipped checks as finished' {
        $checks = @(
            [pscustomobject]@{ name = 'deploy'; bucket = 'skipping' }
            [pscustomobject]@{ name = 'build'; bucket = 'pass' }
        )
        (Resolve-CheckRun -Checks $checks).State | Should -Be 'pass'
    }
    It 'excludes the review gate' {
        $checks = @(
            [pscustomobject]@{ name = 'review/all-files-viewed'; bucket = 'pending' }
            [pscustomobject]@{ name = 'build'; bucket = 'pass' }
        )
        (Resolve-CheckRun -Checks $checks -Exclude 'review/all-files-viewed').State | Should -Be 'pass'
    }
}

Describe 'ConvertFrom-RunList' {
    It 'returns null for no runs' {
        ConvertFrom-RunList -Lines @() | Should -BeNullOrEmpty
        ConvertFrom-RunList -Lines $null | Should -BeNullOrEmpty
    }
    It 'returns null for "null null" (regression: AB#19 deployment step)' {
        ConvertFrom-RunList -Lines @('null null') | Should -BeNullOrEmpty
    }
    It 'parses id and url' {
        $run = ConvertFrom-RunList -Lines @('19126734 https://github.com/AlexeyGane/signallog/actions/runs/19126734')
        $run.Id | Should -Be 19126734
        $run.Url | Should -Be 'https://github.com/AlexeyGane/signallog/actions/runs/19126734'
    }
}

Describe 'Get-ReviewGateDecision' {
    It 'is pending with a count while files are unviewed' {
        $d = Get-ReviewGateDecision -Viewed 3 -Total 4
        $d.State | Should -Be 'pending'
        $d.Description | Should -Be '3 of 4 files viewed'
    }
    It 'is success when every file is viewed' {
        $d = Get-ReviewGateDecision -Viewed 4 -Total 4
        $d.State | Should -Be 'success'
        $d.Description | Should -Be 'All 4 files viewed'
    }
    It 'is never success for a pull request without files' {
        (Get-ReviewGateDecision -Viewed 0 -Total 0).State | Should -Be 'pending'
    }
}

Describe 'Invoke-ResultCheck' {
    It 'counts failures, encodes names and treats a throwing check as failed' {
        $checks = [ordered]@{
            'page opens'     = $true
            'a < b'          = $false
            'throws'         = { throw 'boom' }
            'scriptblock ok' = { 1 -eq 1 }
        }
        $r = Invoke-ResultCheck -Checks $checks 6>$null
        $r.Failed | Should -Be 2
        $r.Html | Should -Match '<li>OK: page opens</li>'
        $r.Html | Should -Match '<li><b>FAILED</b>: a &lt; b</li>'
        $r.Html | Should -Match '<li><b>FAILED</b>: throws</li>'
        $r.Html | Should -Match '<li>OK: scriptblock ok</li>'
    }
}

Describe 'Test-Baseline' {
    BeforeAll {
        Mock -ModuleName SignalLog.Change Invoke-Git {
            switch ($Arguments[-1]) {
                'HEAD:a.md' { [pscustomobject]@{ ExitCode = 0; Output = @('1111111111111111111111111111111111111111') } }
                default { [pscustomobject]@{ ExitCode = 1; Output = @() } }
            }
        }
    }
    It 'passes when blobs match and a new file is absent' {
        $files = [ordered]@{ 'a.md' = @('1111111111111111111111111111111111111111', 'x'); 'new.md' = @($null, 'y') }
        { Test-Baseline -Files $files 6>$null } | Should -Not -Throw
    }
    It 'throws when a blob differs' {
        $files = [ordered]@{ 'a.md' = @('2222222222222222222222222222222222222222', 'x') }
        { Test-Baseline -Files $files } | Should -Throw '*a.md at HEAD*'
    }
    It 'throws when a file expected to exist is absent' {
        $files = [ordered]@{ 'gone.md' = @('3333333333333333333333333333333333333333', 'x') }
        { Test-Baseline -Files $files } | Should -Throw '*absent*'
    }
}

Describe 'New-BoardItem' {
    It 'returns an existing work item without creating one' {
        Mock -ModuleName SignalLog.Change Invoke-BoardApi { [pscustomobject]@{ workItems = @([pscustomobject]@{ id = 42 }) } } -ParameterFilter { $Path -like 'wit/wiql*' }
        Mock -ModuleName SignalLog.Change Invoke-BoardApi { throw 'must not create' } -ParameterFilter { $Path -like 'wit/workitems/$*' }
        New-BoardItem -Item @{ Type = 'User Story'; Title = 'T'; Area = 'Platform' } -ParentId 1 6>$null | Should -Be 42
    }
    It 'creates the work item under its parent when none exists' {
        Mock -ModuleName SignalLog.Change Invoke-BoardApi { [pscustomobject]@{ workItems = @() } } -ParameterFilter { $Path -like 'wit/wiql*' }
        Mock -ModuleName SignalLog.Change Invoke-BoardApi { [pscustomobject]@{ id = 43 } } -ParameterFilter { $Path -like 'wit/workitems/$*' }
        New-BoardItem -Item @{ Type = 'User Story'; Title = 'T'; Area = 'Platform'; Tags = 'ADR-0003' } -ParentId 15 6>$null | Should -Be 43
        Should -Invoke -ModuleName SignalLog.Change Invoke-BoardApi -ParameterFilter {
            $Path -like 'wit/workitems/$User%20Story*' -and $Body -match 'workItems/15' -and $Body -match 'SignalLog\\\\Platform'
        } -Times 1
    }
}

Describe 'Test-BoardComment' {
    It 'finds a marker in the Discussion' {
        Mock -ModuleName SignalLog.Change Invoke-BoardApi { [pscustomobject]@{ comments = @([pscustomobject]@{ text = '<p><b>[evidence AB#17]</b></p>' }) } }
        Test-BoardComment -Id 17 -Marker '[evidence AB#17]' | Should -BeTrue
        Test-BoardComment -Id 17 -Marker '[result AB#17]' | Should -BeFalse
    }
    It 'is false for a work item without comments' {
        Mock -ModuleName SignalLog.Change Invoke-BoardApi { [pscustomobject]@{ comments = @() } }
        Test-BoardComment -Id 17 -Marker '[evidence AB#17]' | Should -BeFalse
    }
}

Describe 'Wait-Deployment' {
    It 'waits for the run to appear instead of watching run "null"' {
        $global:SignalLogChangeTestCalls = 0
        Mock -ModuleName SignalLog.Change Start-Sleep { }
        Mock -ModuleName SignalLog.Change Invoke-Gh {
            if ($Arguments[1] -eq 'list') {
                $global:SignalLogChangeTestCalls++
                if ($global:SignalLogChangeTestCalls -lt 3) { [pscustomobject]@{ ExitCode = 0; Output = @() } }
                else { [pscustomobject]@{ ExitCode = 0; Output = @('555 https://example.test/runs/555') } }
            }
            else { [pscustomobject]@{ ExitCode = 0; Output = @() } }
        }
        $run = Wait-Deployment -Sha 'abc' 6>$null
        $run.Id | Should -Be 555
        Should -Invoke -ModuleName SignalLog.Change Invoke-Gh -ParameterFilter { $Arguments[1] -eq 'watch' -and $Arguments[2] -eq '555' } -Times 1
        Remove-Variable -Name SignalLogChangeTestCalls -Scope Global
    }
    It 'throws when the run fails' {
        Mock -ModuleName SignalLog.Change Invoke-Gh {
            if ($Arguments[1] -eq 'list') { [pscustomobject]@{ ExitCode = 0; Output = @('7 https://example.test/runs/7') } }
            else { [pscustomobject]@{ ExitCode = 1; Output = @() } }
        }
        { Wait-Deployment -Sha 'abc' 6>$null } | Should -Throw '*failed*'
    }
}
