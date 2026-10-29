<#
.SYNOPSIS
    Architecture fitness function for ADR 0012 and ADR 0017.

.DESCRIPTION
    Builds tests/Fitness/BannedApiProbe, which deliberately calls banned APIs, and checks that:
      - the build fails;
      - every line marked "// BANNED" in Probe.cs fails with RS0030;
      - no other line fails with RS0030 (allowed overloads stay allowed).
    Runs the same way locally (Windows PowerShell 7+) and in CI (pwsh on ubuntu-latest).
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$probeDir = Join-Path $root 'tests/Fitness/BannedApiProbe'
$probeFile = Join-Path $probeDir 'Probe.cs'

$expected = Select-String -Path $probeFile -Pattern '// BANNED' |
    ForEach-Object { $_.LineNumber } |
    Sort-Object -Unique

$output = & dotnet build $probeDir --no-incremental -nologo 2>&1 | Out-String
$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    Write-Error 'BannedApiProbe compiled. The banned-API analyzer is not active (check Directory.Packages.props, Directory.Build.props and .editorconfig).'
}

$actual = [regex]::Matches($output, 'Probe\.cs\((\d+),\d+\): error RS0030') |
    ForEach-Object { [int]$_.Groups[1].Value } |
    Sort-Object -Unique

$missing = @($expected | Where-Object { $_ -notin $actual })
$unexpected = @($actual | Where-Object { $_ -notin $expected })

if ($missing.Count -gt 0 -or $unexpected.Count -gt 0) {
    Write-Host $output
    Write-Error ("RS0030 mismatch. Not reported on BANNED lines: [{0}]. Reported on allowed lines: [{1}]." -f ($missing -join ', '), ($unexpected -join ', '))
}

$otherErrors = [regex]::Matches($output, ': error (?!RS0030)[A-Z]+\d+')
if ($otherErrors.Count -gt 0) {
    Write-Host $output
    Write-Error 'BannedApiProbe failed for a reason other than RS0030; the check is inconclusive.'
}

Write-Host "OK: RS0030 reported on all $($expected.Count) banned call sites and nowhere else."

# The probe build fails on purpose and leaves $LASTEXITCODE = 1. GitHub Actions ends pwsh steps
# with "exit $LASTEXITCODE", so reset it explicitly: reaching this line means the check passed.
exit 0
