#Requires -Version 7.2
<#
.SYNOPSIS
    The review gate of pull requests to main (ADR 0002 revision 3): one review thread per changed file.

.DESCRIPTION
    The workflow review-threads runs Update-ReviewThreads.ps1 on every push to a pull request. Each file of the
    pull request gets a file-level review comment from the workflow; the main-protection ruleset requires every
    conversation to be resolved before the merge, so the owner resolves a file's thread once the file is read.

    Each comment of the workflow carries a marker with the state of the file it asks to review: the git blob id
    of the file at the head of the pull request, or "removed" for a deleted file. A later run compares that state
    with the file as it is now:
      - no thread yet                          -> a new thread
      - same state                             -> nothing; a resolved file stays resolved
      - other state, latest thread unresolved  -> a reply with the new state in that thread
      - other state, latest thread resolved    -> a new thread: the file changed after it was read
      - file no longer in the pull request     -> its open threads are resolved by the workflow
    The plan depends only on the files and threads as they are, not on the push that started the run, so a
    skipped or cancelled run, a force push or a merge from main cannot leave a changed file without a thread.

    Get-ReviewThreadPlan decides; Update-ReviewThreads.ps1 reads GitHub and carries the plan out.
#>

Set-StrictMode -Version Latest

$script:MarkerPattern = '<!-- review-threads: (?<state>[0-9a-f]{40}|removed) -->'

function Get-ReviewFileState {
    <# State of one file of the pull request: its blob id at the head, or "removed". #>
    param([Parameter(Mandatory)] [object] $File)
    if ($File.status -eq 'removed') { return 'removed' }
    return [string] $File.sha
}

function Get-ReviewThreadMarker {
    <# The hidden marker that records which state of the file a comment asks to review. #>
    param([Parameter(Mandatory)] [string] $State)
    return "<!-- review-threads: $State -->"
}

function Get-ReviewThreadState {
    <# The state recorded by the last workflow comment of a thread, or $null for a thread of a person. #>
    param([Parameter(Mandatory)] [object] $Thread)
    $state = $null
    foreach ($comment in @($Thread.comments)) {
        $match = [regex]::Match([string] $comment.body, $script:MarkerPattern)
        if ($match.Success) { $state = $match.Groups['state'].Value }
    }
    return $state
}

function Test-ReviewThread {
    <# A thread the workflow opened: its first comment carries the marker. #>
    param([Parameter(Mandatory)] [object] $Thread)
    $first = @($Thread.comments)[0]
    return [bool] ($first -and [regex]::IsMatch([string] $first.body, $script:MarkerPattern))
}

function Get-ReviewThreadPlan {
    <#
    .SYNOPSIS
        Decides what the workflow does: which threads to open, where to reply and which threads to resolve.
    .PARAMETER Files
        Files of the pull request (GitHub REST pulls/{n}/files): filename, status, sha.
    .PARAMETER Threads
        Review threads of the pull request in the order GitHub returns them (oldest first): id, isResolved, path,
        comments (oldest first) with id (REST id of the comment) and body.
    .OUTPUTS
        Actions in a stable order (by path): Create (Path, State, Reason = new|changed),
        Reply (Path, State, CommentId: the first comment of the thread) and Resolve (Path, ThreadId, CommentId).
    #>
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Files,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Threads
    )
    $own = @($Threads | Where-Object { $_ -and (Test-ReviewThread -Thread $_) })
    $current = [ordered]@{}
    foreach ($file in @($Files | Where-Object { $_ } | Sort-Object -Property filename)) { $current[[string] $file.filename] = Get-ReviewFileState -File $file }

    $plan = [System.Collections.Generic.List[object]]::new()
    foreach ($path in $current.Keys) {
        $state = $current[$path]
        $latest = @($own | Where-Object { $_.path -eq $path }) | Select-Object -Last 1
        if (-not $latest) {
            $plan.Add([pscustomobject]@{ Action = 'Create'; Path = $path; State = $state; Reason = 'new' })
            continue
        }
        if ((Get-ReviewThreadState -Thread $latest) -eq $state) { continue }
        if ($latest.isResolved) {
            $plan.Add([pscustomobject]@{ Action = 'Create'; Path = $path; State = $state; Reason = 'changed' })
        }
        else {
            $plan.Add([pscustomobject]@{ Action = 'Reply'; Path = $path; State = $state; CommentId = @($latest.comments)[0].id })
        }
    }
    foreach ($thread in @($own | Where-Object { -not $_.isResolved -and -not $current.Contains([string] $_.path) } | Sort-Object -Property path)) {
        $plan.Add([pscustomobject]@{ Action = 'Resolve'; Path = [string] $thread.path; ThreadId = $thread.id; CommentId = @($thread.comments)[0].id })
    }
    return , $plan.ToArray()
}

function Get-ReviewThreadText {
    <# Text of a workflow comment for one action of the plan. #>
    param([Parameter(Mandatory)] [object] $Action, [Parameter(Mandatory)] [string] $Head)
    $short = $Head.Substring(0, [Math]::Min(7, $Head.Length))
    switch ($Action.Action) {
        'Create' {
            $lead = if ($Action.Reason -eq 'changed') { "**Changed in $short after your review.** Read the file again" } else { "**Review this file** as of $short" }
            return "$lead, then resolve this conversation. The merge stays blocked while any conversation is open.`n`n$(Get-ReviewThreadMarker -State $Action.State)"
        }
        'Reply' { return "Changed again in ${short}: read the new version before you resolve this conversation.`n`n$(Get-ReviewThreadMarker -State $Action.State)" }
        'Resolve' { return 'This file is no longer part of the pull request; the workflow resolved the conversation.' }
        default { throw "Unknown action $($Action.Action)" }
    }
}

Export-ModuleMember -Function @(
    'Get-ReviewFileState', 'Get-ReviewThreadMarker', 'Get-ReviewThreadState', 'Test-ReviewThread', 'Get-ReviewThreadPlan', 'Get-ReviewThreadText'
)
