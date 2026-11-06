#Requires -Version 7.2
<#
.SYNOPSIS
    Runs the review gate for one pull request that no change script created, for example from Dependabot.

.DESCRIPTION
    The ruleset on main requires the commit status review/all-files-viewed. A change script keeps it in step
    with the owner's Viewed marks; for any other pull request this script does the same: it opens the pull
    request, sets the status to pending with a count ("1 of 2 files viewed") and to success once every file is
    Viewed, and waits for the owner's merge. It never merges. See docs/standards/change-workflow.md, section 5.

    Viewed marks belong to each user and GitHub returns them only to that user, so the gate runs on the
    owner's machine with gh signed in as the owner; a workflow cannot run it.

.PARAMETER Number
    Pull request number.

.EXAMPLE
    ./eng/github/Watch-ReviewGate.ps1 -Number 25
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [int] $Number
)

$ErrorActionPreference = 'Stop'
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\scripts\SignalLog.Change.psm1') -Force
Initialize-ChangeContext -GitHubOnly | Out-Null

Write-Host "==> Review gate for PR #$Number" -ForegroundColor Cyan
Wait-ReviewAndMerge -Number $Number
