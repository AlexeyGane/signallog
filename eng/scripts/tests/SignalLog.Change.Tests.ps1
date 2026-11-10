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

Describe 'Test-PullRequestHead' {
    BeforeEach {
        $files = [ordered]@{ 'a.md' = @('1111111111111111111111111111111111111111', '2222222222222222222222222222222222222222'); 'new.md' = @($null, '3333333333333333333333333333333333333333') }
    }
    It 'passes when the branch carries the staged blobs and nothing else' {
        Mock -ModuleName SignalLog.Change Invoke-Git {
            switch ($Arguments[0]) {
                'rev-parse' {
                    switch ($Arguments[-1]) {
                        'origin/feature/AB9-x:a.md' { [pscustomobject]@{ ExitCode = 0; Output = @('2222222222222222222222222222222222222222') } }
                        'origin/feature/AB9-x:new.md' { [pscustomobject]@{ ExitCode = 0; Output = @('3333333333333333333333333333333333333333') } }
                        default { [pscustomobject]@{ ExitCode = 1; Output = @() } }
                    }
                }
                'diff' { [pscustomobject]@{ ExitCode = 0; Output = @('a.md', 'new.md') } }
                default { [pscustomobject]@{ ExitCode = 0; Output = @() } }
            }
        }
        { Test-PullRequestHead -Branch 'feature/AB9-x' -Files $files 6>$null } | Should -Not -Throw
        Should -Invoke -ModuleName SignalLog.Change Invoke-Git -ParameterFilter { $Arguments[0] -eq 'fetch' -and $Arguments -contains 'feature/AB9-x' } -Times 1
    }
    It 'throws and names the file when the branch carries an earlier version (regression: AB#26, PR #29)' {
        Mock -ModuleName SignalLog.Change Invoke-Git {
            switch ($Arguments[0]) {
                'rev-parse' {
                    switch ($Arguments[-1]) {
                        'origin/feature/AB9-x:a.md' { [pscustomobject]@{ ExitCode = 0; Output = @('4444444444444444444444444444444444444444') } }
                        'origin/feature/AB9-x:new.md' { [pscustomobject]@{ ExitCode = 0; Output = @('3333333333333333333333333333333333333333') } }
                        default { [pscustomobject]@{ ExitCode = 1; Output = @() } }
                    }
                }
                'diff' { [pscustomobject]@{ ExitCode = 0; Output = @('a.md', 'new.md') } }
                default { [pscustomobject]@{ ExitCode = 0; Output = @() } }
            }
        }
        { Test-PullRequestHead -Branch 'feature/AB9-x' -Files $files } | Should -Throw '*a.md: 4444444444444444444444444444444444444444 on the branch, 2222222222222222222222222222222222222222 in this change*'
    }
    It 'throws when a file of the change is missing on the branch' {
        Mock -ModuleName SignalLog.Change Invoke-Git {
            switch ($Arguments[0]) {
                'rev-parse' {
                    if ($Arguments[-1] -eq 'origin/feature/AB9-x:a.md') { [pscustomobject]@{ ExitCode = 0; Output = @('2222222222222222222222222222222222222222') } }
                    else { [pscustomobject]@{ ExitCode = 1; Output = @() } }
                }
                'diff' { [pscustomobject]@{ ExitCode = 0; Output = @('a.md') } }
                default { [pscustomobject]@{ ExitCode = 0; Output = @() } }
            }
        }
        { Test-PullRequestHead -Branch 'feature/AB9-x' -Files $files } | Should -Throw '*new.md: absent on the branch*'
    }
    It 'throws when the branch changes a file outside the change' {
        Mock -ModuleName SignalLog.Change Invoke-Git {
            switch ($Arguments[0]) {
                'rev-parse' {
                    switch ($Arguments[-1]) {
                        'origin/feature/AB9-x:a.md' { [pscustomobject]@{ ExitCode = 0; Output = @('2222222222222222222222222222222222222222') } }
                        'origin/feature/AB9-x:new.md' { [pscustomobject]@{ ExitCode = 0; Output = @('3333333333333333333333333333333333333333') } }
                        default { [pscustomobject]@{ ExitCode = 1; Output = @() } }
                    }
                }
                'diff' { [pscustomobject]@{ ExitCode = 0; Output = @('a.md', 'new.md', 'stray.md') } }
                default { [pscustomobject]@{ ExitCode = 0; Output = @() } }
            }
        }
        { Test-PullRequestHead -Branch 'feature/AB9-x' -Files $files } | Should -Throw '*stray.md: changed on the branch, not part of this change*'
    }
    It 'throws when the branch cannot be fetched' {
        Mock -ModuleName SignalLog.Change Invoke-Git { [pscustomobject]@{ ExitCode = 128; Output = @("fatal: couldn't find remote ref") } } -ParameterFilter { $Arguments[0] -eq 'fetch' }
        { Test-PullRequestHead -Branch 'feature/AB9-x' -Files $files } | Should -Throw '*git fetch*failed*'
    }
}

Describe 'Invoke-Change on a resumed run' {
    It 'stops before the CI wait when the open pull request carries other blobs' {
        Mock -ModuleName SignalLog.Change Get-BoardItem { [pscustomobject]@{ fields = [pscustomobject]@{ 'System.State' = 'Resolved' } } }
        Mock -ModuleName SignalLog.Change Get-ChangePullRequest { $null } -ParameterFilter { $State -eq 'merged' }
        Mock -ModuleName SignalLog.Change Get-ChangePullRequest { 29 } -ParameterFilter { $State -eq 'open' }
        Mock -ModuleName SignalLog.Change New-SignedCommit { throw 'must not commit' }
        Mock -ModuleName SignalLog.Change Wait-PullRequestCheck { throw 'must not wait' }
        Mock -ModuleName SignalLog.Change Wait-ReviewAndMerge { throw 'must not wait for the merge' }
        Mock -ModuleName SignalLog.Change Invoke-Git {
            switch ($Arguments[0]) {
                'rev-parse' { [pscustomobject]@{ ExitCode = 0; Output = @('4444444444444444444444444444444444444444') } }
                'diff' { [pscustomobject]@{ ExitCode = 0; Output = @('a.md') } }
                default { [pscustomobject]@{ ExitCode = 0; Output = @() } }
            }
        }
        $change = @{
            Story  = 26
            Branch = 'feature/AB{id}-x'
            Title  = 't AB#{id}'
            Files  = [ordered]@{ 'a.md' = @('1111111111111111111111111111111111111111', '2222222222222222222222222222222222222222') }
        }
        { Invoke-Change $change 6>$null } | Should -Throw '*feature/AB26-x does not carry this change*'
        Should -Invoke -ModuleName SignalLog.Change Wait-PullRequestCheck -Times 0
        Should -Invoke -ModuleName SignalLog.Change New-SignedCommit -Times 0
    }
}

Describe 'Test-WorkingTreeChange' {
    BeforeEach {
        $files = [ordered]@{
            'a.md'    = @('1111111111111111111111111111111111111111', '2222222222222222222222222222222222222222')
            'new.md'  = @($null, '3333333333333333333333333333333333333333')
            'gone.md' = @('4444444444444444444444444444444444444444', $null)
        }
        Mock -ModuleName SignalLog.Change Test-Path { $true }
        Mock -ModuleName SignalLog.Change Test-Path { $false } -ParameterFilter { $LiteralPath -eq 'gone.md' }
    }
    It 'passes when the working copy holds exactly the change, a deleted file included' {
        Mock -ModuleName SignalLog.Change Invoke-Git {
            switch ($Arguments[0]) {
                'status' { [pscustomobject]@{ ExitCode = 0; Output = @(' M a.md', '?? new.md', ' D gone.md') } }
                'hash-object' {
                    switch ($Arguments[-1]) {
                        'a.md' { [pscustomobject]@{ ExitCode = 0; Output = @('2222222222222222222222222222222222222222') } }
                        'new.md' { [pscustomobject]@{ ExitCode = 0; Output = @('3333333333333333333333333333333333333333') } }
                    }
                }
            }
        }
        { Test-WorkingTreeChange -Files $files 6>$null } | Should -Not -Throw
    }
    It 'throws and names a file the change does not include' {
        Mock -ModuleName SignalLog.Change Invoke-Git {
            switch ($Arguments[0]) {
                'status' { [pscustomobject]@{ ExitCode = 0; Output = @(' M a.md', '?? new.md', ' D gone.md', ' M stray.md') } }
                'hash-object' {
                    switch ($Arguments[-1]) {
                        'a.md' { [pscustomobject]@{ ExitCode = 0; Output = @('2222222222222222222222222222222222222222') } }
                        'new.md' { [pscustomobject]@{ ExitCode = 0; Output = @('3333333333333333333333333333333333333333') } }
                    }
                }
            }
        }
        { Test-WorkingTreeChange -Files $files } | Should -Throw '*stray.md: changed in the working copy, not part of this change*'
    }
    It 'throws and names a file whose content differs from the verified blob' {
        Mock -ModuleName SignalLog.Change Invoke-Git {
            switch ($Arguments[0]) {
                'status' { [pscustomobject]@{ ExitCode = 0; Output = @(' M a.md', '?? new.md', ' D gone.md') } }
                'hash-object' {
                    switch ($Arguments[-1]) {
                        'a.md' { [pscustomobject]@{ ExitCode = 0; Output = @('5555555555555555555555555555555555555555') } }
                        'new.md' { [pscustomobject]@{ ExitCode = 0; Output = @('3333333333333333333333333333333333333333') } }
                    }
                }
            }
        }
        { Test-WorkingTreeChange -Files $files } | Should -Throw '*a.md: 5555555555555555555555555555555555555555 in the working copy, 2222222222222222222222222222222222222222 in this change*'
    }
    It 'throws when a file to be deleted is still there' {
        Mock -ModuleName SignalLog.Change Test-Path { $true } -ParameterFilter { $LiteralPath -eq 'gone.md' }
        Mock -ModuleName SignalLog.Change Invoke-Git {
            switch ($Arguments[0]) {
                'status' { [pscustomobject]@{ ExitCode = 0; Output = @(' M a.md', '?? new.md') } }
                'hash-object' {
                    switch ($Arguments[-1]) {
                        'a.md' { [pscustomobject]@{ ExitCode = 0; Output = @('2222222222222222222222222222222222222222') } }
                        'new.md' { [pscustomobject]@{ ExitCode = 0; Output = @('3333333333333333333333333333333333333333') } }
                        'gone.md' { [pscustomobject]@{ ExitCode = 0; Output = @('4444444444444444444444444444444444444444') } }
                    }
                }
            }
        }
        { Test-WorkingTreeChange -Files $files } | Should -Throw '*gone.md: 4444444444444444444444444444444444444444 in the working copy, absent in this change*'
    }
}

Describe 'Test-ChangeBranch' {
    It 'passes on the branch with no commits beyond main' {
        Mock -ModuleName SignalLog.Change Invoke-Git {
            switch ($Arguments[0]) {
                'branch' { [pscustomobject]@{ ExitCode = 0; Output = @('feature/AB9-x') } }
                'rev-list' { [pscustomobject]@{ ExitCode = 0; Output = @('0') } }
                default { [pscustomobject]@{ ExitCode = 0; Output = @() } }
            }
        }
        { Test-ChangeBranch -Branch 'feature/AB9-x' 6>$null } | Should -Not -Throw
    }
    It 'throws on another branch' {
        Mock -ModuleName SignalLog.Change Invoke-Git { [pscustomobject]@{ ExitCode = 0; Output = @('main') } }
        { Test-ChangeBranch -Branch 'feature/AB9-x' } | Should -Throw "*on 'main', expected feature/AB9-x*"
    }
    It 'throws when the branch already has commits' {
        Mock -ModuleName SignalLog.Change Invoke-Git {
            switch ($Arguments[0]) {
                'branch' { [pscustomobject]@{ ExitCode = 0; Output = @('feature/AB9-x') } }
                'rev-list' { [pscustomobject]@{ ExitCode = 0; Output = @('2') } }
                default { [pscustomobject]@{ ExitCode = 0; Output = @() } }
            }
        }
        { Test-ChangeBranch -Branch 'feature/AB9-x' } | Should -Throw '*already has 2 commit(s)*'
    }
}

Describe 'Start-Change' {
    BeforeEach {
        Mock -ModuleName SignalLog.Change Get-BoardItem { [pscustomobject]@{ fields = [pscustomobject]@{ 'System.State' = 'New' } } }
        Mock -ModuleName SignalLog.Change Set-BoardItemState { }
    }
    It 'makes the work item Active and creates the branch from an up-to-date main' {
        Mock -ModuleName SignalLog.Change Invoke-Git {
            if ($Arguments[0] -eq 'branch' -and $Arguments[1] -eq '--show-current') { [pscustomobject]@{ ExitCode = 0; Output = @('main') } }
            else { [pscustomobject]@{ ExitCode = 0; Output = @() } }
        }
        $r = Start-Change @{ Story = 9; Branch = 'feature/AB{id}-x' } 6>$null
        $r.Id | Should -Be 9
        $r.Branch | Should -Be 'feature/AB9-x'
        Should -Invoke -ModuleName SignalLog.Change Set-BoardItemState -ParameterFilter { $Id -eq 9 -and $State -eq 'Active' } -Times 1
        Should -Invoke -ModuleName SignalLog.Change Invoke-Git -ParameterFilter { $Arguments[0] -eq 'pull' } -Times 1
        Should -Invoke -ModuleName SignalLog.Change Invoke-Git -ParameterFilter { $Arguments[0] -eq 'switch' -and $Arguments[1] -eq '-c' -and $Arguments[2] -eq 'feature/AB9-x' } -Times 1
    }
    It 'refuses to leave uncommitted changes behind' {
        Mock -ModuleName SignalLog.Change Invoke-Git {
            switch ($Arguments[0]) {
                'branch' { [pscustomobject]@{ ExitCode = 0; Output = @('main') } }
                'status' { [pscustomobject]@{ ExitCode = 0; Output = @(' M docs/note.md') } }
                default { [pscustomobject]@{ ExitCode = 0; Output = @() } }
            }
        }
        { Start-Change @{ Story = 9; Branch = 'feature/AB{id}-x' } 6>$null } | Should -Throw '*uncommitted changes*'
        Should -Invoke -ModuleName SignalLog.Change Invoke-Git -ParameterFilter { $Arguments[0] -eq 'switch' } -Times 0
    }
    It 'does nothing to git when the branch is already checked out' {
        Mock -ModuleName SignalLog.Change Invoke-Git {
            if ($Arguments[0] -eq 'branch' -and $Arguments[1] -eq '--show-current') { [pscustomobject]@{ ExitCode = 0; Output = @('feature/AB9-x') } }
            else { throw "unexpected git $($Arguments -join ' ')" }
        }
        (Start-Change @{ Story = 9; Branch = 'feature/AB{id}-x' } 6>$null).Branch | Should -Be 'feature/AB9-x'
    }
}

Describe 'Invoke-SolutionCheck' {
    It 'runs the CI build steps, the build without persistent build servers, and reads the test summary' {
        Mock -ModuleName SignalLog.Change Invoke-Native {
            if ($Arguments[0] -eq 'test') { [pscustomobject]@{ ExitCode = 0; Output = @('Test run summary: Passed!', '  total: 57') } }
            else { [pscustomobject]@{ ExitCode = 0; Output = @() } }
        }
        $r = Invoke-SolutionCheck 6>$null
        $r.Passed | Should -BeTrue
        $r.Tests | Should -Be 'total: 57'
        Should -Invoke -ModuleName SignalLog.Change Invoke-Native -ParameterFilter { $FilePath -eq 'dotnet' -and $Arguments[0] -eq 'build' -and $Arguments -contains '--disable-build-servers' -and $Arguments -contains 'Release' } -Times 1
        Should -Invoke -ModuleName SignalLog.Change Invoke-Native -ParameterFilter { $FilePath -eq 'pwsh' -and ($Arguments -join ' ') -match 'Test-BannedApi\.ps1' } -Times 1
    }
    It 'stops at the first failed step and names it, also when the failed run prints no summary' {
        Mock -ModuleName SignalLog.Change Invoke-Native {
            if ($Arguments[0] -eq 'test') { [pscustomobject]@{ ExitCode = 1; Output = @('failed') } }
            else { [pscustomobject]@{ ExitCode = 0; Output = @() } }
        }
        $r = Invoke-SolutionCheck 6>$null
        $r.Passed | Should -BeFalse
        $r.Failed | Should -Be @('test')
        Should -Invoke -ModuleName SignalLog.Change Invoke-Native -ParameterFilter { $Arguments[0] -eq 'format' } -Times 0
    }
}

Describe 'Invoke-Change in branch mode' {
    It 'checks branch, baseline on origin/main and working copy, and commits on the branch without copying staged files' {
        Mock -ModuleName SignalLog.Change Get-BoardItem { [pscustomobject]@{ fields = [pscustomobject]@{ 'System.State' = 'Active' } } }
        Mock -ModuleName SignalLog.Change Get-ChangePullRequest { $null }
        Mock -ModuleName SignalLog.Change Test-ChangeBranch { }
        Mock -ModuleName SignalLog.Change Test-Baseline { }
        Mock -ModuleName SignalLog.Change Test-WorkingTreeChange { }
        Mock -ModuleName SignalLog.Change Test-BoardComment { $true }
        Mock -ModuleName SignalLog.Change Reset-PreparedFile { throw 'must not reset' }
        Mock -ModuleName SignalLog.Change Update-MainBranch { throw 'must not switch to main' }
        Mock -ModuleName SignalLog.Change Copy-StagedFile { throw 'must not copy staged files' }
        Mock -ModuleName SignalLog.Change New-SignedCommit { }
        Mock -ModuleName SignalLog.Change New-ChangePullRequest { throw 'stop after the commit' }
        $change = @{
            Story           = 9
            FromWorkingTree = $true
            Branch          = 'feature/AB{id}-x'
            Title           = 't AB#{id}'
            Files           = [ordered]@{ 'a.md' = @('1111111111111111111111111111111111111111', '2222222222222222222222222222222222222222') }
            CommitBody      = 'body'
            PrBody          = 'Work item: AB#{id}'
        }
        { Invoke-Change $change 6>$null } | Should -Throw '*stop after the commit*'
        Should -Invoke -ModuleName SignalLog.Change Test-ChangeBranch -ParameterFilter { $Branch -eq 'feature/AB9-x' } -Times 1
        Should -Invoke -ModuleName SignalLog.Change Test-Baseline -ParameterFilter { $Revision -eq 'origin/main' } -Times 1
        Should -Invoke -ModuleName SignalLog.Change Test-WorkingTreeChange -Times 1
        Should -Invoke -ModuleName SignalLog.Change New-SignedCommit -ParameterFilter { $OnBranch -and $Branch -eq 'feature/AB9-x' } -Times 1
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

Describe 'Azure DevOps token' {
    BeforeEach {
        $global:SignalLogTokenCount = 0
        Mock -ModuleName SignalLog.Change Invoke-Az { $global:SignalLogTokenCount++; "token-$global:SignalLogTokenCount" }
        $ctx = Initialize-ChangeContext -Staging 'S'
    }
    AfterEach {
        Remove-Variable -Name SignalLogTokenCount, SignalLogRequestCount -Scope Global -ErrorAction SilentlyContinue
        Initialize-ChangeContext -Staging (Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath 'signallog-change-tests') -Token 'test-token' | Out-Null
    }

    It 'is taken from the Azure CLI at start' {
        $ctx.TokenFromAz | Should -BeTrue
        $ctx.Headers.Authorization | Should -Be 'Bearer token-1'
    }
    It 'is renewed before a request when it is older than 30 minutes' {
        Mock -ModuleName SignalLog.Change Invoke-BoardRequest { [pscustomobject]@{ id = 7; auth = $Request.Headers.Authorization } }
        $ctx.TokenTaken = (Get-Date).AddMinutes(-31)
        $item = Get-BoardItem -Id 7 6>$null
        $item.auth | Should -Be 'Bearer token-2'
        $global:SignalLogTokenCount | Should -Be 2
    }
    It 'is kept while it is fresh' {
        Mock -ModuleName SignalLog.Change Invoke-BoardRequest { [pscustomobject]@{ id = 7 } }
        Get-BoardItem -Id 7 | Out-Null
        $global:SignalLogTokenCount | Should -Be 1
    }
    It 'is renewed and the request repeated once when Azure DevOps answers with a sign-in page' {
        $global:SignalLogRequestCount = 0
        Mock -ModuleName SignalLog.Change Invoke-BoardRequest {
            $global:SignalLogRequestCount++
            if ($global:SignalLogRequestCount -eq 1) { '<html>Sign in</html>' } else { [pscustomobject]@{ comments = @(); auth = $Request.Headers.Authorization } }
        }
        $answer = & (Get-Module SignalLog.Change) { Invoke-BoardApi -Path 'wit/workItems/22/comments' } 6>$null
        $answer.auth | Should -Be 'Bearer token-2'
        $global:SignalLogRequestCount | Should -Be 2
    }
    It 'throws a clear error when the page comes back again' {
        Mock -ModuleName SignalLog.Change Invoke-BoardRequest { '<html>Sign in</html>' }
        { Test-BoardComment -Id 22 -Marker '[result AB#22]' 6>$null } | Should -Throw '*page instead of JSON*'
    }
    It 'is never replaced when it was given for tests' {
        Initialize-ChangeContext -Staging 'S' -Token 'fixed' | Out-Null
        Mock -ModuleName SignalLog.Change Invoke-BoardRequest { '<html>Sign in</html>' }
        { Get-BoardItem -Id 1 } | Should -Throw '*page instead of JSON*'
        $global:SignalLogTokenCount | Should -Be 1 -Because 'only the start-up context of BeforeEach asked az'
    }
}
