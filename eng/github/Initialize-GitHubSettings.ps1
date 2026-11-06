#Requires -Version 7.2
<#
.SYNOPSIS
    Applies repository.settings.psd1 to GitHub, or with -Check lists the differences (ADR 0002 revision 2).

.DESCRIPTION
    Idempotent: reads the current state, compares only the keys the settings file lists and changes only the
    areas that differ (repository merge settings, security and analysis, workflow permissions, Pages,
    rulesets found by name). After applying, it reads GitHub again and fails if anything still differs.

    -Check changes nothing: it prints every difference and exits with code 1 when there is one, 0 otherwise.

    Needs gh signed in as a repository administrator (gh auth status).

.PARAMETER Check
    Drift check only: compare and report, apply nothing.

.PARAMETER SettingsPath
    Desired-state file. Defaults to repository.settings.psd1 next to this script.

.EXAMPLE
    ./eng/github/Initialize-GitHubSettings.ps1 -Check

.EXAMPLE
    ./eng/github/Initialize-GitHubSettings.ps1
#>
[CmdletBinding()]
param(
    [switch] $Check,
    [string] $SettingsPath = (Join-Path -Path $PSScriptRoot -ChildPath 'repository.settings.psd1')
)

$ErrorActionPreference = 'Stop'
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'SignalLog.GitHubSettings.psm1') -Force

$desired = Import-PowerShellDataFile -LiteralPath $SettingsPath
$repo = $desired['Repository']
Write-Host "==> GitHub settings of $repo$(if ($Check) { ' (check only)' })" -ForegroundColor Cyan

$actual = Get-GitHubState -Repository $repo
$drift = Get-SettingsDrift -Desired $desired -Actual $actual

if ($drift.Count -eq 0) {
    Write-Host '    + GitHub matches the settings file' -ForegroundColor Green
    exit 0
}

$drift | Format-Table -Property Area, Name, Desired, Actual -AutoSize -Wrap | Out-Host
if ($Check) {
    Write-Host "    - $($drift.Count) difference(s); nothing was changed" -ForegroundColor Red
    exit 1
}

Set-GitHubState -Desired $desired -Actual $actual -Drift $drift
$left = Get-SettingsDrift -Desired $desired -Actual (Get-GitHubState -Repository $repo)
if ($left.Count -gt 0) {
    $left | Format-Table -Property Area, Name, Desired, Actual -AutoSize -Wrap | Out-Host
    Write-Host "    - $($left.Count) difference(s) remain after applying" -ForegroundColor Red
    exit 1
}
Write-Host "    + applied; GitHub now matches the settings file" -ForegroundColor Green
exit 0
