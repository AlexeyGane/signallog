# Pester 5 tests for the GitHub Actions workflows under .github/workflows (ADR 0004).
# Run: Invoke-Pester -Path eng/github/tests -Output Detailed

BeforeDiscovery {
    $repository = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $workflows = @(Get-ChildItem -LiteralPath (Join-Path $repository '.github/workflows') -Filter '*.yml' | ForEach-Object { @{ Name = $_.Name; Path = $_.FullName } })
}

BeforeAll {
    function Get-ActionReference([string] $Path) {
        # "uses: owner/repo[/path]@ref # comment" -> Action (owner/repo), Step (owner/repo/path), Ref
        foreach ($line in Get-Content -LiteralPath $Path) {
            if ($line -match '^\s*(-\s+)?uses:\s*(?<step>(?<action>[^/@\s]+/[^/@\s]+)[^@\s]*)@(?<ref>[^\s#]+)') {
                [pscustomobject]@{ Action = $Matches.action; Step = $Matches.step; Ref = $Matches.ref }
            }
        }
    }
}

Describe 'Workflow <Name>' -ForEach $workflows {
    It 'pins every action to a full commit SHA' {
        foreach ($reference in @(Get-ActionReference $Path)) {
            $reference.Ref | Should -Match '^[0-9a-f]{40}$' -Because "$($reference.Step) in $Name"
        }
    }
    It 'uses one commit for all steps of the same action' {
        foreach ($group in @(Get-ActionReference $Path | Group-Object -Property Action)) {
            @($group.Group.Ref | Sort-Object -Unique).Count | Should -Be 1 -Because "the steps of $($group.Name) in $Name must run the same version"
        }
    }
}
