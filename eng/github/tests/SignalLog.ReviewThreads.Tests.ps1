# Pester 5 tests for eng/github/SignalLog.ReviewThreads.psm1: the plan of the review gate (ADR 0002 revision 3).
# Run: Invoke-Pester -Path eng/github/tests -Output Detailed

BeforeAll {
    Get-Module -Name SignalLog.ReviewThreads | Remove-Module -Force
    $root = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path -Path $root -ChildPath 'SignalLog.ReviewThreads.psm1') -Force

    $blobA = 'a' * 40
    $blobB = 'b' * 40
    $blobC = 'c' * 40

    function New-File([string] $Path, [string] $Sha, [string] $Status = 'modified') {
        [pscustomobject]@{ filename = $Path; status = $Status; sha = $Sha }
    }
    function New-Thread([string] $Path, [string[]] $States, [bool] $Resolved = $false, [string] $Id = "T_$Path", [int] $CommentId = 100) {
        $comments = for ($i = 0; $i -lt $States.Count; $i++) {
            $body = if ($States[$i] -eq 'person') { 'A question from a person' } else { "text`n`n$(Get-ReviewThreadMarker -State $States[$i])" }
            [pscustomobject]@{ id = $CommentId + $i; body = $body }
        }
        [pscustomobject]@{ id = $Id; isResolved = $Resolved; path = $Path; comments = @($comments) }
    }
}

AfterAll {
    Remove-Module SignalLog.ReviewThreads -Force -ErrorAction SilentlyContinue
}

Describe 'Module and script' {
    It 'parse without errors' {
        foreach ($file in @('SignalLog.ReviewThreads.psm1', 'Update-ReviewThreads.ps1')) {
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root $file), [ref] $null, [ref] $errors) | Out-Null
            $errors | Should -BeNullOrEmpty -Because $file
        }
    }
}

Describe 'Get-ReviewThreadState' {
    It 'takes the state of the last workflow comment' {
        Get-ReviewThreadState -Thread (New-Thread 'a.md' @($blobA, 'person', $blobB)) | Should -Be $blobB
    }
    It 'is null for a thread of a person' {
        Get-ReviewThreadState -Thread (New-Thread 'a.md' @('person')) | Should -BeNullOrEmpty
    }
    It 'reads "removed" for a deleted file' {
        Get-ReviewThreadState -Thread (New-Thread 'a.md' @('removed')) | Should -Be 'removed'
    }
}

Describe 'Get-ReviewThreadPlan' {
    It 'opens one thread per file of a new pull request, in path order' {
        $plan = Get-ReviewThreadPlan -Files @((New-File 'b.md' $blobB), (New-File 'a.md' $blobA)) -Threads @()
        $plan.Count | Should -Be 2
        $plan[0].Action | Should -Be 'Create'
        $plan[0].Path | Should -Be 'a.md'
        $plan[0].State | Should -Be $blobA
        $plan[0].Reason | Should -Be 'new'
        $plan[1].Path | Should -Be 'b.md'
    }
    It 'records a deleted file as removed' {
        $plan = Get-ReviewThreadPlan -Files @(New-File 'old.ps1' $blobA 'removed') -Threads @()
        $plan[0].State | Should -Be 'removed'
    }
    It 'does nothing when every thread matches its file (a second run)' {
        $plan = Get-ReviewThreadPlan -Files @((New-File 'a.md' $blobA), (New-File 'b.md' $blobB)) -Threads @((New-Thread 'a.md' @($blobA) $true), (New-Thread 'b.md' @($blobB)))
        $plan.Count | Should -Be 0
    }
    It 'keeps a resolved file resolved when a push leaves it unchanged' {
        $plan = Get-ReviewThreadPlan -Files @((New-File 'a.md' $blobA), (New-File 'b.md' $blobC)) -Threads @((New-Thread 'a.md' @($blobA) $true), (New-Thread 'b.md' @($blobB) $true))
        $plan.Count | Should -Be 1
        $plan[0].Path | Should -Be 'b.md'
    }
    It 'opens a new thread for a file changed after its thread was resolved' {
        $plan = Get-ReviewThreadPlan -Files @(New-File 'a.md' $blobB) -Threads @(New-Thread 'a.md' @($blobA) $true)
        $plan[0].Action | Should -Be 'Create'
        $plan[0].Reason | Should -Be 'changed'
        $plan[0].State | Should -Be $blobB
    }
    It 'replies in the open thread when the file changes before it is resolved' {
        $plan = Get-ReviewThreadPlan -Files @(New-File 'a.md' $blobB) -Threads @(New-Thread 'a.md' @($blobA) $false 'T1' 500)
        $plan.Count | Should -Be 1
        $plan[0].Action | Should -Be 'Reply'
        $plan[0].CommentId | Should -Be 500
        $plan[0].State | Should -Be $blobB
    }
    It 'compares with the latest thread and the latest marker' {
        $threads = @((New-Thread 'a.md' @($blobA) $true 'T1'), (New-Thread 'a.md' @($blobB, $blobC) $false 'T2'))
        (Get-ReviewThreadPlan -Files @(New-File 'a.md' $blobC) -Threads $threads).Count | Should -Be 0
        (Get-ReviewThreadPlan -Files @(New-File 'a.md' $blobB) -Threads $threads)[0].Action | Should -Be 'Reply'
    }
    It 'opens a thread again when a reverted change returns to a resolved file' {
        $threads = @((New-Thread 'a.md' @($blobA) $true 'T1'), (New-Thread 'a.md' @($blobB) $true 'T2'))
        $plan = Get-ReviewThreadPlan -Files @(New-File 'a.md' $blobA) -Threads $threads
        $plan[0].Action | Should -Be 'Create'
        $plan[0].Reason | Should -Be 'changed'
    }
    It 'ignores threads of people, resolved or not' {
        $plan = Get-ReviewThreadPlan -Files @(New-File 'a.md' $blobA) -Threads @((New-Thread 'a.md' @('person')), (New-Thread 'gone.md' @('person')))
        $plan.Count | Should -Be 1
        $plan[0].Action | Should -Be 'Create'
    }
    It 'resolves open workflow threads of files that left the pull request, and only those' {
        $threads = @(
            (New-Thread 'gone.md' @($blobA) $false 'T_gone' 700)
            (New-Thread 'done.md' @($blobA) $true 'T_done')
            (New-Thread 'a.md' @($blobA) $false 'T_a')
        )
        $plan = Get-ReviewThreadPlan -Files @(New-File 'a.md' $blobA) -Threads $threads
        $plan.Count | Should -Be 1
        $plan[0].Action | Should -Be 'Resolve'
        $plan[0].ThreadId | Should -Be 'T_gone'
        $plan[0].CommentId | Should -Be 700
    }
    It 'returns an empty array for a pull request without files and threads' {
        $plan = Get-ReviewThreadPlan -Files @() -Threads @()
        , $plan | Should -BeOfType [object[]]
        $plan.Count | Should -Be 0
    }
}

Describe 'Get-ReviewThreadText' {
    It 'carries the marker of the state it asks to review' {
        $text = Get-ReviewThreadText -Action ([pscustomobject]@{ Action = 'Create'; Path = 'a.md'; State = $blobA; Reason = 'new' }) -Head ('1234567' + '0' * 33)
        $text | Should -Match 'as of 1234567'
        $text | Should -Match ([regex]::Escape((Get-ReviewThreadMarker -State $blobA)))
    }
    It 'says when a file changed after the review' {
        $text = Get-ReviewThreadText -Action ([pscustomobject]@{ Action = 'Create'; Path = 'a.md'; State = $blobB; Reason = 'changed' }) -Head ('abcdef0' + '0' * 33)
        $text | Should -Match 'Changed in abcdef0 after your review'
    }
    It 'round-trips: the state of a reply is read back from its text' {
        $text = Get-ReviewThreadText -Action ([pscustomobject]@{ Action = 'Reply'; Path = 'a.md'; State = 'removed'; CommentId = 1 }) -Head ('f' * 40)
        Get-ReviewThreadState -Thread ([pscustomobject]@{ comments = @([pscustomobject]@{ body = $text }) }) | Should -Be 'removed'
    }
}
