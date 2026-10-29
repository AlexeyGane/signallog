#Requires -Version 7.2
<#
.SYNOPSIS
    Creates or updates the SignalLog Azure Boards project from boards.settings.psd1 (ADR 0003).

.DESCRIPTION
    Idempotent: every step reads the current state first and only creates or changes what differs.
    Applies, in order:
      1. Project (Agile process, private)
      2. Area paths and the monthly cadence of iteration paths
      3. Team settings: owned areas, iterations, backlog levels, bug behavior, working days
      4. Scrumban board for stories: columns, WIP limits, Definition of Done, Expedite lane
      5. Delivery Plan
      6. Seed backlog: Epic → Feature → User Story with ADR links

    Not automated (needs a browser): creating the organization and connecting GitHub
    through the Azure Boards app. See the runbook printed at the end.

    Authentication, first match wins:
      - $env:AZURE_DEVOPS_EXT_PAT
      - Microsoft Entra token from the Azure CLI (az login)
      - interactive prompt for a personal access token
    Required PAT scopes: Project and Team (Read, write & manage), Work Items (Read & write).

.PARAMETER Organization
    Azure DevOps organization name, as in https://dev.azure.com/<Organization>.

.PARAMETER SettingsPath
    Desired-state file. Defaults to boards.settings.psd1 next to this script.

.EXAMPLE
    ./eng/azure-devops/Initialize-AzureBoards.ps1 -Organization alexeygane
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9-]{0,48}[A-Za-z0-9]$')]
    [string] $Organization,

    [string] $SettingsPath = (Join-Path $PSScriptRoot 'boards.settings.psd1')
)

Clear-Host
Set-Location -LiteralPath (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ApiVersion = '7.1'
$AzureDevOpsResourceId = '499b84ac-1321-427f-aa17-267ca6975798'
$OrgUrl = "https://dev.azure.com/$Organization"
$Settings = Import-PowerShellDataFile -LiteralPath $SettingsPath
$script:AuthHeader = $null

#region Helpers

function Write-Step([string] $Text) {
    Write-Host ''
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Write-Change([string] $Text) {
    Write-Host "    + $Text" -ForegroundColor Green
}

function Write-Unchanged([string] $Text) {
    Write-Host "    = $Text" -ForegroundColor DarkGray
}

function ConvertTo-PathSegment([string] $Value) {
    return [uri]::EscapeDataString($Value)
}

function Get-PatHeader([string] $Pat) {
    $bytes = [Text.Encoding]::ASCII.GetBytes(":$Pat")
    return @{ Authorization = "Basic $([Convert]::ToBase64String($bytes))" }
}

function Get-AuthCandidates {
    if ($env:AZURE_DEVOPS_EXT_PAT) {
        return , @{ Name = 'AZURE_DEVOPS_EXT_PAT'; Header = (Get-PatHeader $env:AZURE_DEVOPS_EXT_PAT) }
    }

    $candidates = @()
    if (Get-Command -Name az -ErrorAction SilentlyContinue) {
        $token = & az account get-access-token --resource $AzureDevOpsResourceId --query accessToken --output tsv 2>$null
        if ($LASTEXITCODE -eq 0 -and $token) {
            $candidates += @{ Name = 'Azure CLI (Microsoft Entra)'; Header = @{ Authorization = "Bearer $token" } }
        }
    }
    $candidates += @{ Name = 'personal access token (prompt)'; Header = $null }
    return $candidates
}

function Connect-AzureDevOps {
    foreach ($candidate in Get-AuthCandidates) {
        $header = $candidate.Header
        if ($null -eq $header) {
            $secure = Read-Host -Prompt "Azure DevOps PAT for $Organization" -AsSecureString
            $header = Get-PatHeader (ConvertFrom-SecureString -SecureString $secure -AsPlainText)
        }

        try {
            $response = Invoke-RestMethod -Method Get -Headers $header `
                -Uri "$OrgUrl/_apis/projects?api-version=$ApiVersion"
            # A failed sign-in can come back as 203 with an HTML sign-in page instead of 401.
            if ($response -is [string]) {
                throw 'Received an HTML sign-in page instead of JSON.'
            }
            $script:AuthHeader = $header
            Write-Change "Signed in with $($candidate.Name)"
            return
        }
        catch {
            Write-Warning "Sign-in with $($candidate.Name) failed: $($_.Exception.Message)"
        }
    }
    throw "Could not authenticate to $OrgUrl. Check the organization name and the PAT scopes."
}

function Invoke-Ado {
    param(
        [Parameter(Mandatory)] [ValidateSet('Get', 'Post', 'Put', 'Patch')] [string] $Method,
        [Parameter(Mandatory)] [string] $Uri,
        [object] $Body,
        [string] $ContentType = 'application/json',
        [switch] $AllowNotFound
    )

    $separator = if ($Uri.Contains('?')) { '&' } else { '?' }
    $request = @{
        Method  = $Method
        Uri     = "$Uri$($separator)api-version=$ApiVersion"
        Headers = $script:AuthHeader
    }
    if ($PSBoundParameters.ContainsKey('Body')) {
        # -InputObject keeps single-element arrays as JSON arrays.
        $request.Body = ConvertTo-Json -InputObject $Body -Depth 20 -Compress
        $request.ContentType = $ContentType
    }

    try {
        return Invoke-RestMethod @request
    }
    catch {
        $status = $_.Exception.Response.StatusCode.value__
        if ($AllowNotFound -and $status -eq 404) {
            return $null
        }
        $detail = $_.ErrorDetails.Message
        throw "$Method $Uri failed ($status): $detail"
    }
}

function Wait-AdoOperation([string] $OperationId) {
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        $operation = Invoke-Ado -Method Get -Uri "$OrgUrl/_apis/operations/$OperationId"
        switch ($operation.status) {
            'succeeded' { return }
            { $_ -in 'failed', 'cancelled' } { throw "Operation $OperationId $($operation.status): $($operation.resultMessage)" }
        }
        Start-Sleep -Seconds 2
    }
    throw "Operation $OperationId did not finish within 2 minutes."
}

#endregion

#region Steps

function Set-Project {
    Write-Step "Project '$($Settings.Project.Name)'"
    $name = $Settings.Project.Name
    $project = Invoke-Ado -Method Get -Uri "$OrgUrl/_apis/projects/$(ConvertTo-PathSegment $name)" -AllowNotFound

    if ($null -eq $project) {
        $process = (Invoke-Ado -Method Get -Uri "$OrgUrl/_apis/process/processes").value |
            Where-Object { $_.name -eq $Settings.Project.Process }
        if ($null -eq $process) {
            throw "Process '$($Settings.Project.Process)' not found in $OrgUrl."
        }

        $operation = Invoke-Ado -Method Post -Uri "$OrgUrl/_apis/projects" -Body @{
            name         = $name
            description  = $Settings.Project.Description
            visibility   = $Settings.Project.Visibility
            capabilities = @{
                versioncontrol  = @{ sourceControlType = 'Git' }
                processTemplate = @{ templateTypeId = $process.id }
            }
        }
        Wait-AdoOperation $operation.id
        $project = Invoke-Ado -Method Get -Uri "$OrgUrl/_apis/projects/$(ConvertTo-PathSegment $name)?includeCapabilities=true"
        Write-Change "Created ($($Settings.Project.Process), $($Settings.Project.Visibility))"
    }
    else {
        Write-Unchanged "Exists ($($project.visibility))"
    }

    $project = Invoke-Ado -Method Get -Uri "$OrgUrl/_apis/projects/$(ConvertTo-PathSegment $name)?includeCapabilities=true"
    return $project
}

function Get-ClassificationNode([string] $ProjectUrl, [string] $Group, [string] $RelativePath) {
    $pathPart = if ($RelativePath) { '/' + (($RelativePath -split '\\' | ForEach-Object { ConvertTo-PathSegment $_ }) -join '/') } else { '' }
    return Invoke-Ado -Method Get -Uri "$ProjectUrl/_apis/wit/classificationnodes/$Group$pathPart" -AllowNotFound
}

function New-ClassificationNode([string] $ProjectUrl, [string] $Group, [string] $ParentPath, [string] $Name, [hashtable] $Attributes) {
    $existing = Get-ClassificationNode $ProjectUrl $Group (($ParentPath, $Name | Where-Object { $_ }) -join '\')
    if ($existing) {
        Write-Unchanged "$Group\$(($ParentPath, $Name | Where-Object { $_ }) -join '\')"
        return $existing
    }

    $pathPart = if ($ParentPath) { '/' + (($ParentPath -split '\\' | ForEach-Object { ConvertTo-PathSegment $_ }) -join '/') } else { '' }
    $body = @{ name = $Name }
    if ($Attributes) {
        $body.attributes = $Attributes
    }
    $node = Invoke-Ado -Method Post -Uri "$ProjectUrl/_apis/wit/classificationnodes/$Group$pathPart" -Body $body
    Write-Change "$Group\$(($ParentPath, $Name | Where-Object { $_ }) -join '\')"
    return $node
}

function Set-AreasAndIterations([string] $ProjectUrl) {
    Write-Step 'Area paths'
    foreach ($area in $Settings.Areas) {
        $null = New-ClassificationNode $ProjectUrl 'Areas' '' $area $null
    }

    Write-Step 'Iteration paths (monthly cadence)'
    $first = [datetime]::ParseExact($Settings.Cadence.FirstMonth, 'yyyy-MM', [Globalization.CultureInfo]::InvariantCulture)
    $iterations = @()
    for ($i = 0; $i -lt $Settings.Cadence.Months; $i++) {
        $start = $first.AddMonths($i)
        $finish = $start.AddMonths(1).AddDays(-1)
        $year = $start.ToString('yyyy')
        $null = New-ClassificationNode $ProjectUrl 'Iterations' '' $year $null
        $iterations += New-ClassificationNode $ProjectUrl 'Iterations' $year $start.ToString('yyyy-MM') @{
            startDate  = $start.ToString('yyyy-MM-ddT00:00:00Z')
            finishDate = $finish.ToString('yyyy-MM-ddT00:00:00Z')
        }
    }
    return $iterations
}

function Set-TeamSettings([string] $ProjectUrl, [string] $ProjectName, [string] $TeamName, [object[]] $Iterations) {
    $teamUrl = "$OrgUrl/$(ConvertTo-PathSegment $ProjectName)/$(ConvertTo-PathSegment $TeamName)"

    Write-Step "Team '$TeamName': owned areas"
    $null = Invoke-Ado -Method Patch -Uri "$teamUrl/_apis/work/teamsettings/teamfieldvalues" -Body @{
        defaultValue = $ProjectName
        values       = @(@{ value = $ProjectName; includeChildren = $true })
    }
    Write-Change "$ProjectName (including sub-areas), default area $ProjectName"

    Write-Step "Team '$TeamName': iterations"
    $subscribed = @((Invoke-Ado -Method Get -Uri "$teamUrl/_apis/work/teamsettings/iterations").value | ForEach-Object { $_.id })
    foreach ($iteration in $Iterations) {
        if ($iteration.identifier -in $subscribed) {
            Write-Unchanged $iteration.name
            continue
        }
        $null = Invoke-Ado -Method Post -Uri "$teamUrl/_apis/work/teamsettings/iterations" -Body @{ id = $iteration.identifier }
        Write-Change $iteration.name
    }

    Write-Step "Team '$TeamName': backlog levels, bug behavior, working days"
    $root = Get-ClassificationNode $ProjectUrl 'Iterations' ''
    $null = Invoke-Ado -Method Patch -Uri "$teamUrl/_apis/work/teamsettings" -Body @{
        # Kanban: new items land in the backlog, not in the current month.
        backlogIteration      = $root.identifier
        defaultIteration      = $root.identifier
        backlogVisibilities   = $Settings.Team.BacklogVisibilities
        bugsBehavior          = $Settings.Team.BugsBehavior
        workingDays           = $Settings.Team.WorkingDays
    }
    Write-Change "Epics visible; bugs $($Settings.Team.BugsBehavior); $($Settings.Team.WorkingDays.Count) working days"

    return $teamUrl
}

function Set-Board([string] $TeamUrl) {
    $boardName = $Settings.Board.Name
    Write-Step "Board '$boardName': columns and WIP limits"
    $boardSegment = ConvertTo-PathSegment $boardName
    $current = (Invoke-Ado -Method Get -Uri "$TeamUrl/_apis/work/boards/$boardSegment/columns").value

    # Work item types on this board, taken from the current state mappings (User Story, Bug).
    $types = @($current | ForEach-Object { $_.stateMappings.PSObject.Properties.Name } | Sort-Object -Unique)
    if ($Settings.Team.BugsBehavior -eq 'asRequirements' -and 'Bug' -notin $types) {
        $types += 'Bug'
    }

    $desired = foreach ($column in $Settings.Board.Columns) {
        $mappings = [ordered]@{}
        foreach ($type in $types) {
            $mappings[$type] = $column.State
        }
        $entry = [ordered]@{
            name          = $column.Name
            itemLimit     = $column.Limit
            stateMappings = $mappings
            columnType    = $column.Type
        }
        switch ($column.Type) {
            'incoming' { $entry.id = ($current | Where-Object columnType -eq 'incoming').id }
            'outgoing' { $entry.id = ($current | Where-Object columnType -eq 'outgoing').id }
            default {
                $sameName = $current | Where-Object { $_.columnType -eq 'inProgress' -and $_.name -eq $column.Name }
                if ($sameName) {
                    $entry.id = $sameName.id
                }
                $entry.isSplit = [bool] $column.Split
                $entry.description = $column.Description
            }
        }
        [pscustomobject] $entry
    }

    # Reuse the id of an existing in-progress column mapped to the same state (Active → In Progress,
    # Resolved → Review), so that cards keep their column history. Columns without an id are created.
    $usedIds = [Collections.Generic.List[string]]::new()
    $desired | Where-Object { $_.PSObject.Properties.Name -contains 'id' } | ForEach-Object { $usedIds.Add($_.id) }
    foreach ($column in @($desired | Where-Object { $_.columnType -eq 'inProgress' -and $_.PSObject.Properties.Name -notcontains 'id' })) {
        $state = @($column.stateMappings.Values)[0]
        $match = $current | Where-Object {
            $_.columnType -eq 'inProgress' -and
            $_.id -notin $usedIds -and
            @($_.stateMappings.PSObject.Properties.Value)[0] -eq $state
        } | Select-Object -First 1
        if ($match) {
            $column | Add-Member -NotePropertyName id -NotePropertyValue $match.id
            $usedIds.Add($match.id)
        }
    }

    $null = Invoke-Ado -Method Put -Uri "$TeamUrl/_apis/work/boards/$boardSegment/columns" -Body @($desired)
    foreach ($column in $Settings.Board.Columns) {
        $limit = if ($column.Limit -gt 0) { "WIP $($column.Limit)" } else { 'no limit' }
        Write-Change "$($column.Name) → $($column.State), $limit$(if ($column.Split) { ', split Doing/Done' })"
    }

    Write-Step "Board '$boardName': swimlanes"
    $rows = @((Invoke-Ado -Method Get -Uri "$TeamUrl/_apis/work/boards/$boardSegment/rows").value)
    $missing = @($Settings.Board.Lanes | Where-Object { $_ -notin $rows.name })
    if ($missing.Count -eq 0) {
        $Settings.Board.Lanes | ForEach-Object { Write-Unchanged $_ }
    }
    else {
        $newRows = @($missing | ForEach-Object { @{ name = $_ } }) + @($rows | ForEach-Object { @{ id = $_.id; name = $_.name } })
        $null = Invoke-Ado -Method Put -Uri "$TeamUrl/_apis/work/boards/$boardSegment/rows" -Body $newRows
        $missing | ForEach-Object { Write-Change $_ }
    }
}

function Set-DeliveryPlan([string] $ProjectUrl, [string] $TeamId) {
    $planName = $Settings.DeliveryPlan.Name
    Write-Step "Delivery Plan '$planName'"
    $plans = @((Invoke-Ado -Method Get -Uri "$ProjectUrl/_apis/work/plans").value)
    if ($plans | Where-Object name -eq $planName) {
        Write-Unchanged 'Exists'
        return
    }

    try {
        $null = Invoke-Ado -Method Post -Uri "$ProjectUrl/_apis/work/plans" -Body @{
            name        = $planName
            description = 'Features on the monthly cadence; traceability Epic → Feature → Story (ADR 0003).'
            type        = 'deliveryTimelineView'
            properties  = @{
                teamBacklogMappings = @(@{ teamId = $TeamId; categoryReferenceName = $Settings.DeliveryPlan.Category })
            }
        }
        Write-Change "Created for $($Settings.DeliveryPlan.Category)"
    }
    catch {
        Write-Warning "Delivery Plan was not created: $($_.Exception.Message)"
        Write-Warning 'Create it manually: Boards → Delivery Plans → New plan, team SignalLog Team, backlog Features.'
    }
}

function Find-WorkItem([string] $ProjectUrl, [string] $Type, [string] $Title) {
    $escapedTitle = $Title.Replace("'", "''")
    $query = "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = @project AND [System.WorkItemType] = '$Type' AND [System.Title] = '$escapedTitle'"
    $result = Invoke-Ado -Method Post -Uri "$ProjectUrl/_apis/wit/wiql" -Body @{ query = $query }
    return @($result.workItems) | Select-Object -First 1
}

function New-WorkItemTree([string] $ProjectUrl, [string] $ProjectName, [hashtable] $Item, [object] $Parent, [int] $Depth) {
    $indent = '  ' * $Depth
    $found = Find-WorkItem $ProjectUrl $Item.Type $Item.Title

    if ($found) {
        $workItem = Invoke-Ado -Method Get -Uri "$ProjectUrl/_apis/wit/workitems/$($found.id)"
        Write-Unchanged "$indent$($Item.Type) #$($workItem.id) $($Item.Title)"
    }
    else {
        $patch = [Collections.Generic.List[object]]::new()
        $patch.Add(@{ op = 'add'; path = '/fields/System.Title'; value = $Item.Title })
        $patch.Add(@{ op = 'add'; path = '/fields/System.AreaPath'; value = "$ProjectName\$($Item.Area)" })
        if ($Item.ContainsKey('Description')) {
            $patch.Add(@{ op = 'add'; path = '/fields/System.Description'; value = $Item.Description })
        }
        if ($Item.ContainsKey('AcceptanceCriteria')) {
            $patch.Add(@{ op = 'add'; path = '/fields/Microsoft.VSTS.Common.AcceptanceCriteria'; value = $Item.AcceptanceCriteria })
        }
        if ($Item.ContainsKey('Tags')) {
            $patch.Add(@{ op = 'add'; path = '/fields/System.Tags'; value = $Item.Tags })
        }
        if ($Parent) {
            $patch.Add(@{ op = 'add'; path = '/relations/-'; value = @{ rel = 'System.LinkTypes.Hierarchy-Reverse'; url = $Parent.url } })
        }
        if ($Item.ContainsKey('Links')) {
            foreach ($link in $Item.Links) {
                $patch.Add(@{ op = 'add'; path = '/relations/-'; value = @{ rel = 'Hyperlink'; url = $link } })
            }
        }

        $typeSegment = ConvertTo-PathSegment $Item.Type
        $workItem = Invoke-Ado -Method Post -Uri "$ProjectUrl/_apis/wit/workitems/`$$typeSegment" `
            -Body $patch.ToArray() -ContentType 'application/json-patch+json'
        Write-Change "$indent$($Item.Type) #$($workItem.id) $($Item.Title)"
    }

    if ($Item.ContainsKey('Children')) {
        foreach ($child in $Item.Children) {
            New-WorkItemTree $ProjectUrl $ProjectName $child $workItem ($Depth + 1)
        }
    }
}

#endregion

Write-Step "Connecting to $OrgUrl"
Connect-AzureDevOps

$project = Set-Project
$projectName = $project.name
$projectUrl = "$OrgUrl/$(ConvertTo-PathSegment $projectName)"

$iterations = Set-AreasAndIterations $projectUrl
$teamUrl = Set-TeamSettings $projectUrl $projectName $project.defaultTeam.name $iterations
Set-Board $teamUrl
Set-DeliveryPlan $projectUrl $project.defaultTeam.id

Write-Step 'Seed backlog'
foreach ($item in $Settings.WorkItems) {
    New-WorkItemTree $projectUrl $projectName $item $null 0
}

Write-Step 'Manual steps (browser)'
Write-Host "    1. Connect GitHub: $projectUrl/_settings/boards-external-integration"
Write-Host '       Install the Azure Boards app, select only AlexeyGane/signallog.'
Write-Host "    2. Optional: turn off Repos, Pipelines, Test Plans and Artifacts in $projectUrl/_settings/"
Write-Host '       (GitHub hosts code and CI; Boards is the only Azure DevOps service used).'
Write-Host ''
Write-Host "Done: $projectUrl/_boards/board/t/$(ConvertTo-PathSegment $project.defaultTeam.name)/Stories" -ForegroundColor Green
