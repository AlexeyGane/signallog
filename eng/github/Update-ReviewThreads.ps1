#Requires -Version 7.2
<#
.SYNOPSIS
    Keeps one review thread per changed file of a pull request (the review gate, ADR 0002 revision 3).

.DESCRIPTION
    Run by the workflow review-threads on every push to a pull request, with GH_TOKEN set to the workflow's
    GITHUB_TOKEN (pull-requests: write). Reads the files and review threads of the pull request, lets
    Get-ReviewThreadPlan decide (see SignalLog.ReviewThreads.psm1) and carries the plan out: new file-level
    review comments, replies in open threads, and resolved threads for files that left the pull request.
    Running it again changes nothing. It never resolves a thread of a file that is still in the pull request.

.PARAMETER Repository
    owner/name.

.PARAMETER Number
    Pull request number.

.EXAMPLE
    ./eng/github/Update-ReviewThreads.ps1 -Repository AlexeyGane/signallog -Number 40
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Repository,
    [Parameter(Mandatory)] [int] $Number
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'SignalLog.ReviewThreads.psm1') -Force

function Invoke-GhApi {
    param([Parameter(Mandatory)] [string[]] $Arguments)
    $output = & gh api @Arguments
    if ($LASTEXITCODE -ne 0) { throw "gh api $($Arguments[0..1] -join ' ') failed with exit code $LASTEXITCODE" }
    return $output
}

$owner, $name = $Repository.Split('/')
$head = ([string] @(Invoke-GhApi @("repos/$Repository/pulls/$Number", '--jq', '.head.sha'))[0]).Trim()

$files = foreach ($line in @(Invoke-GhApi @('--paginate', "repos/$Repository/pulls/$Number/files?per_page=100", '--jq', '.[] | [.filename, .status, .sha] | @tsv'))) {
    if (-not $line) { continue }
    $parts = ([string] $line).Split("`t")
    [pscustomobject]@{ filename = $parts[0]; status = $parts[1]; sha = $parts[2] }
}

$query = 'query($owner:String!,$name:String!,$number:Int!){repository(owner:$owner,name:$name){pullRequest(number:$number){' +
    'reviewThreads(first:100){pageInfo{hasNextPage} nodes{id isResolved path comments(first:100){pageInfo{hasNextPage} nodes{databaseId body}}}}}}}'
$data = (Invoke-GhApi @('graphql', '-F', "owner=$owner", '-F', "name=$name", '-F', "number=$Number", '-f', "query=$query")) -join "`n" | ConvertFrom-Json
$connection = $data.data.repository.pullRequest.reviewThreads
if ($connection.pageInfo.hasNextPage) { throw "PR #$Number has more than 100 review threads; this script reads the first 100 only." }
$threads = foreach ($node in @($connection.nodes)) {
    if ($node.comments.pageInfo.hasNextPage) { throw "A review thread on $($node.path) has more than 100 comments; this script reads the first 100 only." }
    [pscustomobject]@{
        id         = $node.id
        isResolved = [bool] $node.isResolved
        path       = $node.path
        comments   = @($node.comments.nodes | ForEach-Object { [pscustomobject]@{ id = $_.databaseId; body = $_.body } })
    }
}

$plan = Get-ReviewThreadPlan -Files @($files) -Threads @($threads)
Write-Host "PR #$Number at $($head.Substring(0, 7)): $(@($files).Count) file(s), $(@($threads).Count) review thread(s), $($plan.Count) action(s)"

$summary = [System.Collections.Generic.List[string]]::new()
foreach ($action in $plan) {
    $body = Get-ReviewThreadText -Action $action -Head $head
    switch ($action.Action) {
        'Create' {
            Invoke-GhApi @('-X', 'POST', "repos/$Repository/pulls/$Number/comments", '-f', "body=$body", '-f', "commit_id=$head",
                '-f', "path=$($action.Path)", '-f', 'subject_type=file', '--silent') | Out-Null
        }
        'Reply' {
            Invoke-GhApi @('-X', 'POST', "repos/$Repository/pulls/$Number/comments/$($action.CommentId)/replies", '-f', "body=$body", '--silent') | Out-Null
        }
        'Resolve' {
            Invoke-GhApi @('-X', 'POST', "repos/$Repository/pulls/$Number/comments/$($action.CommentId)/replies", '-f', "body=$body", '--silent') | Out-Null
            $mutation = 'mutation($id:ID!){resolveReviewThread(input:{threadId:$id}){thread{isResolved}}}'
            Invoke-GhApi @('graphql', '-f', "id=$($action.ThreadId)", '-f', "query=$mutation", '--silent') | Out-Null
        }
    }
    $line = "$($action.Action) $(if ($action.Action -eq 'Create') { "($($action.Reason)) " })$($action.Path)"
    Write-Host "  + $line"
    $summary.Add("- $line")
}

if ($env:GITHUB_STEP_SUMMARY) {
    $text = if ($summary.Count -gt 0) { $summary -join "`n" } else { '- Nothing to do: every file already has a thread for its current content.' }
    Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value "### Review threads for PR #$Number`n`n$text" -Encoding utf8NoBOM
}
