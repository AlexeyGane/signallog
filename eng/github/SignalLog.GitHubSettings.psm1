<#
.SYNOPSIS
    Compares the desired GitHub settings (repository.settings.psd1) with GitHub and applies the difference.

.DESCRIPTION
    Get-SettingsDrift is pure: it takes the desired state and the GitHub API answers and returns one row per
    difference, so it is tested without GitHub. Get-GitHubState and Set-GitHubState call gh; they go through
    Invoke-GhApi so tests can mock them. Only the keys listed in the desired state are managed.
#>

Set-StrictMode -Version Latest

# --- Comparison (pure, tested) ---------------------------------------------------

function Get-SettingProperty {
    # Value of a key on a hashtable or a property on an object from ConvertFrom-Json; $null when absent
    param($Object, [string] $Name)
    if ($null -eq $Object) { return $null }
    if ($Object -is [System.Collections.IDictionary]) { if ($Object.Contains($Name)) { return , $Object[$Name] } else { return $null } }
    $property = $Object.PSObject.Properties[$Name]
    if ($property) { return , $property.Value }
    return $null
}

function Test-IsList($Value) {
    return ($Value -is [System.Collections.IList]) -and -not ($Value -is [string])
}

function Test-SettingsMatch {
    <#
    .SYNOPSIS
        True when Actual contains Desired: every desired key has an equal value; actual may have more keys.
        Lists match when they have the same length and every desired element matches a different actual
        element, in any order.
    #>
    param($Desired, $Actual)
    if ($Desired -is [System.Collections.IDictionary]) {
        if ($null -eq $Actual) { return $false }
        foreach ($key in $Desired.Keys) {
            if (-not (Test-SettingsMatch -Desired $Desired[$key] -Actual (Get-SettingProperty $Actual $key))) { return $false }
        }
        return $true
    }
    if (Test-IsList $Desired) {
        # @( if ... ) collects the elements whatever comes back: nothing, one object or a list
        $actualList = [object[]] @(if ($null -ne $Actual) { $Actual })
        if (@($Desired).Count -ne $actualList.Length) { return $false }
        $used = [System.Collections.Generic.HashSet[int]]::new()
        foreach ($d in $Desired) {
            $found = $false
            for ($i = 0; $i -lt $actualList.Length; $i++) {
                if (-not $used.Contains($i) -and (Test-SettingsMatch -Desired $d -Actual $actualList[$i])) { [void] $used.Add($i); $found = $true; break }
            }
            if (-not $found) { return $false }
        }
        return $true
    }
    if ($null -eq $Desired) { return $null -eq $Actual }
    if ($null -eq $Actual) { return $false }
    return ([string] $Desired) -eq ([string] $Actual)
}

function Format-SettingValue($Value) {
    if ($null -eq $Value) { return '(absent)' }
    if ($Value -is [string] -or $Value -is [bool] -or $Value -is [ValueType]) { return [string] $Value }
    return (ConvertTo-Json -InputObject $Value -Depth 10 -Compress)
}

function New-DriftRow([string] $Area, [string] $Name, $Desired, $Actual) {
    return [pscustomobject]@{ Area = $Area; Name = $Name; Desired = (Format-SettingValue $Desired); Actual = (Format-SettingValue $Actual) }
}

function Get-SettingsDrift {
    <#
    .SYNOPSIS
        One row (Area, Name, Desired, Actual) per difference between the desired state and GitHub.
    .PARAMETER Actual
        @{ Repository = <GET repos/x>; Workflow = <GET actions/permissions/workflow>; Pages = <GET pages>;
           Rulesets = @(<GET rulesets/{id}> for every ruleset) }
    #>
    param([Parameter(Mandatory)] [System.Collections.IDictionary] $Desired, [Parameter(Mandatory)] [System.Collections.IDictionary] $Actual)
    $rows = [System.Collections.Generic.List[object]]::new()

    if ($Desired['Settings']) {
        foreach ($key in $Desired['Settings'].Keys) {
            $a = Get-SettingProperty $Actual['Repository'] $key
            if (-not (Test-SettingsMatch $Desired['Settings'][$key] $a)) { $rows.Add((New-DriftRow 'Settings' $key $Desired['Settings'][$key] $a)) }
        }
    }
    if ($Desired['SecurityAndAnalysis']) {
        $sa = Get-SettingProperty $Actual['Repository'] 'security_and_analysis'
        foreach ($key in $Desired['SecurityAndAnalysis'].Keys) {
            $a = Get-SettingProperty (Get-SettingProperty $sa $key) 'status'
            if (-not (Test-SettingsMatch $Desired['SecurityAndAnalysis'][$key] $a)) { $rows.Add((New-DriftRow 'SecurityAndAnalysis' $key $Desired['SecurityAndAnalysis'][$key] $a)) }
        }
    }
    if ($Desired['WorkflowPermissions']) {
        foreach ($key in $Desired['WorkflowPermissions'].Keys) {
            $a = Get-SettingProperty $Actual['Workflow'] $key
            if (-not (Test-SettingsMatch $Desired['WorkflowPermissions'][$key] $a)) { $rows.Add((New-DriftRow 'WorkflowPermissions' $key $Desired['WorkflowPermissions'][$key] $a)) }
        }
    }
    if ($Desired['Pages']) {
        foreach ($key in $Desired['Pages'].Keys) {
            $a = Get-SettingProperty $Actual['Pages'] $key
            if (-not (Test-SettingsMatch $Desired['Pages'][$key] $a)) { $rows.Add((New-DriftRow 'Pages' $key $Desired['Pages'][$key] $a)) }
        }
    }
    foreach ($ruleset in @($Desired['Rulesets'])) {
        if (-not $ruleset) { continue }
        $area = "Ruleset $($ruleset['name'])"
        $live = @($Actual['Rulesets']) | Where-Object { $_ -and (Get-SettingProperty $_ 'name') -eq $ruleset['name'] } | Select-Object -First 1
        if (-not $live) { $rows.Add((New-DriftRow $area '(ruleset)' 'present' $null)); continue }
        foreach ($key in @('target', 'enforcement', 'conditions', 'bypass_actors')) {
            if ($ruleset.Contains($key)) {
                $a = Get-SettingProperty $live $key
                if (-not (Test-SettingsMatch $ruleset[$key] $a)) { $rows.Add((New-DriftRow $area $key $ruleset[$key] $a)) }
            }
        }
        $liveRules = Get-SettingProperty $live 'rules'
        foreach ($rule in @($ruleset['rules'])) {
            $match = $liveRules | Where-Object { $_ -and (Get-SettingProperty $_ 'type') -eq $rule['type'] } | Select-Object -First 1
            if (-not $match) { $rows.Add((New-DriftRow $area "rules.$($rule['type'])" 'present' $null)); continue }
            if ($rule.Contains('parameters')) {
                $liveParameters = Get-SettingProperty $match 'parameters'
                foreach ($key in $rule['parameters'].Keys) {
                    $a = Get-SettingProperty $liveParameters $key
                    if (-not (Test-SettingsMatch $rule['parameters'][$key] $a)) { $rows.Add((New-DriftRow $area "rules.$($rule['type']).$key" $rule['parameters'][$key] $a)) }
                }
            }
        }
        $wanted = @($ruleset['rules'] | ForEach-Object { $_['type'] })
        foreach ($liveRule in $liveRules) {
            $type = Get-SettingProperty $liveRule 'type'
            if ($type -and $type -notin $wanted) { $rows.Add((New-DriftRow $area "rules.$type" $null 'present')) }
        }
    }
    return , $rows.ToArray()
}

function ConvertTo-RulesetBody {
    <# The request body for POST/PUT rulesets: the desired ruleset as JSON. #>
    param([Parameter(Mandatory)] [System.Collections.IDictionary] $Ruleset)
    return ConvertTo-Json -InputObject $Ruleset -Depth 12
}

# --- GitHub (mocked in tests) ---------------------------------------------------

function Invoke-GhApi {
    <# gh api; returns the parsed JSON. With -Body the JSON is sent through a temporary file (--input). #>
    param([Parameter(Mandatory)] [string] $Path, [string] $Method = 'GET', [string] $Body)
    $arguments = @('api', '-X', $Method, $Path, '-H', 'Accept: application/vnd.github+json')
    $file = $null
    if ($Body) {
        $file = [IO.Path]::GetTempFileName()
        Set-Content -LiteralPath $file -Value $Body -Encoding utf8NoBOM
        $arguments += @('--input', $file)
    }
    try {
        $out = & gh @arguments
        if ($LASTEXITCODE -ne 0) { throw "gh api -X $Method $Path failed: $out" }
    }
    finally { if ($file) { Remove-Item -LiteralPath $file -ErrorAction SilentlyContinue } }
    if ($out) { return ($out -join "`n") | ConvertFrom-Json }
    return $null
}

function Get-GitHubState {
    param([Parameter(Mandatory)] [string] $Repository)
    $list = @(Invoke-GhApi -Path "repos/$Repository/rulesets")
    return @{
        Repository = Invoke-GhApi -Path "repos/$Repository"
        Workflow   = Invoke-GhApi -Path "repos/$Repository/actions/permissions/workflow"
        Pages      = Invoke-GhApi -Path "repos/$Repository/pages"
        Rulesets   = @($list | Where-Object { $_ } | ForEach-Object { Invoke-GhApi -Path "repos/$Repository/rulesets/$($_.id)" })
    }
}

function Set-GitHubState {
    <# Applies the areas that have drift. Each area is sent whole (only its managed keys). #>
    param(
        [Parameter(Mandatory)] [System.Collections.IDictionary] $Desired,
        [Parameter(Mandatory)] [System.Collections.IDictionary] $Actual,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Drift
    )
    $repo = $Desired['Repository']
    $areas = @($Drift | ForEach-Object { $_.Area } | Select-Object -Unique)
    if ('Settings' -in $areas) {
        Invoke-GhApi -Method PATCH -Path "repos/$repo" -Body (ConvertTo-Json -InputObject $Desired['Settings'] -Depth 5) | Out-Null
        Write-Host '    ~ repository settings' -ForegroundColor Green
    }
    if ('SecurityAndAnalysis' -in $areas) {
        $sa = @{}
        foreach ($key in $Desired['SecurityAndAnalysis'].Keys) { $sa[$key] = @{ status = $Desired['SecurityAndAnalysis'][$key] } }
        Invoke-GhApi -Method PATCH -Path "repos/$repo" -Body (ConvertTo-Json -InputObject @{ security_and_analysis = $sa } -Depth 5) | Out-Null
        Write-Host '    ~ security and analysis' -ForegroundColor Green
    }
    if ('WorkflowPermissions' -in $areas) {
        Invoke-GhApi -Method PUT -Path "repos/$repo/actions/permissions/workflow" -Body (ConvertTo-Json -InputObject $Desired['WorkflowPermissions'] -Depth 5) | Out-Null
        Write-Host '    ~ workflow permissions' -ForegroundColor Green
    }
    if ('Pages' -in $areas) {
        Invoke-GhApi -Method PUT -Path "repos/$repo/pages" -Body (ConvertTo-Json -InputObject $Desired['Pages'] -Depth 5) | Out-Null
        Write-Host '    ~ pages' -ForegroundColor Green
    }
    foreach ($ruleset in @($Desired['Rulesets'])) {
        if (-not $ruleset -or "Ruleset $($ruleset['name'])" -notin $areas) { continue }
        $live = @($Actual['Rulesets']) | Where-Object { $_ -and (Get-SettingProperty $_ 'name') -eq $ruleset['name'] } | Select-Object -First 1
        $body = ConvertTo-RulesetBody -Ruleset $ruleset
        if ($live) { Invoke-GhApi -Method PUT -Path "repos/$repo/rulesets/$($live.id)" -Body $body | Out-Null }
        else { Invoke-GhApi -Method POST -Path "repos/$repo/rulesets" -Body $body | Out-Null }
        Write-Host "    ~ ruleset $($ruleset['name'])" -ForegroundColor Green
    }
}

Export-ModuleMember -Function 'Test-SettingsMatch', 'Get-SettingsDrift', 'ConvertTo-RulesetBody', 'Get-GitHubState', 'Set-GitHubState'
