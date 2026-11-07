<#
.SYNOPSIS
    Shared steps of the change workflow (docs/standards/change-workflow.md).

.DESCRIPTION
    A change script describes one change as a hashtable (work item, branch, title, files, evidence, result
    checks) and calls Invoke-Change. The module does the rest: work item state, baseline, staged files,
    evidence comment, signed commit, pull request, CI, review gate, the wait for the owner's merge, the
    deployment and the result comment. It never merges and never closes a work item.

    Runs on the owner's machine with PowerShell 7, az (signed in), gh (signed in) and git with commit signing.
    External commands go through Invoke-Az, Invoke-Gh, Invoke-Git and Invoke-BoardApi, so tests can mock them.
#>

Set-StrictMode -Version Latest

$script:Ctx = $null

# An Azure CLI access token lives about an hour; a change run can wait many hours for the owner's merge.
# The token is taken again when it is older than this, and once more when Azure DevOps answers with a
# sign-in page instead of JSON.
$script:TokenMaxAgeMinutes = 30
$script:TokenResource = '499b84ac-1321-427f-aa17-267ca6975798' # Azure DevOps

# --- Context -------------------------------------------------------------------

function Initialize-ChangeContext {
    <#
    .SYNOPSIS
        Sets the repository, board and site the module works with, and gets an Azure DevOps token.
    .PARAMETER GitHubOnly
        For GitHub-only steps (the review gate of a pull request no change script created, for example from
        Dependabot): no staging folder and no Azure DevOps token are needed.
    #>
    [CmdletBinding()]
    param(
        [string] $Repository = 'AlexeyGane/signallog',
        [string] $Organization = 'alexeygane',
        [string] $Project = 'SignalLog',
        [string] $SiteUrl = 'https://alexeygane.github.io/signallog',
        [string] $Staging,
        [string] $Gate = 'review/all-files-viewed',
        [switch] $GitHubOnly,
        # For tests only: skips az
        [string] $Token
    )
    if (-not $GitHubOnly -and -not $Staging) { throw 'Staging is required unless -GitHubOnly is given.' }
    $fromAz = -not $Token -and -not $GitHubOnly
    if ($fromAz) { $Token = Get-AzDevOpsToken }
    $script:Ctx = [pscustomobject]@{
        Repository   = $Repository
        Owner        = $Repository.Split('/')[0]
        Name         = $Repository.Split('/')[1]
        Organization = $Organization
        Project      = $Project
        BaseUrl      = "https://dev.azure.com/$Organization/$Project"
        SiteUrl      = $SiteUrl.TrimEnd('/')
        Staging      = $Staging
        Gate         = $Gate
        Headers      = $(if ($Token) { @{ Authorization = "Bearer $Token" } } else { @{} })
        TokenFromAz  = $fromAz
        TokenTaken   = Get-Date
    }
    return $script:Ctx
}

function Get-AzDevOpsToken {
    $token = Invoke-Az @('account', 'get-access-token', '--resource', $script:TokenResource, '--query', 'accessToken', '--output', 'tsv')
    if (-not $token) { throw 'No Azure CLI token: run az login and start the script again.' }
    return ([string] @($token)[0]).Trim()
}

function Update-BoardToken {
    <# Takes a new Azure DevOps token from the Azure CLI. A token given for tests is never replaced. #>
    $ctx = Get-ChangeContext
    if (-not $ctx.TokenFromAz) { return $false }
    $ctx.Headers = @{ Authorization = "Bearer $(Get-AzDevOpsToken)" }
    $ctx.TokenTaken = Get-Date
    Write-Host '    ~ Azure DevOps token renewed' -ForegroundColor DarkGray
    return $true
}

function Get-ChangeContext {
    if (-not $script:Ctx) { throw 'Call Initialize-ChangeContext first.' }
    return $script:Ctx
}

function Write-ChangeStep([string] $Text) { Write-Host ''; Write-Host "==> $Text" -ForegroundColor Cyan }
function Write-ChangeOk([string] $Text) { Write-Host "    + $Text" -ForegroundColor Green }
function Write-ChangeSkip([string] $Text) { Write-Host "    = $Text" -ForegroundColor DarkGray }

# --- External commands (mocked in tests) ----------------------------------------

function Invoke-Az([string[]] $Arguments) {
    $out = & az @Arguments
    if ($LASTEXITCODE -ne 0) { throw "az $($Arguments[0]) failed" }
    return $out
}

function Invoke-Gh {
    # Returns @{ ExitCode; Output }; the caller decides whether a non-zero exit code is an error
    param([string[]] $Arguments)
    $out = & gh @Arguments 2>$null
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $out }
}

function Invoke-Git {
    param([string[]] $Arguments)
    $out = & git @Arguments 2>&1
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $out }
}

function Invoke-BoardApi {
    param(
        [ValidateSet('Get', 'Post', 'Patch')] [string] $Method = 'Get',
        [Parameter(Mandatory)] [string] $Path,
        [object] $Body,
        [string] $ContentType = 'application/json; charset=utf-8',
        [string] $InFile
    )
    $ctx = Get-ChangeContext
    if ($ctx.TokenFromAz -and ((Get-Date) - $ctx.TokenTaken).TotalMinutes -ge $script:TokenMaxAgeMinutes) { Update-BoardToken | Out-Null }
    $uri = if ($Path -like 'https://*') { $Path } else { "$($ctx.BaseUrl)/_apis/$Path" }
    $request = @{ Method = $Method; Uri = $uri; Headers = $ctx.Headers; ContentType = $ContentType }
    if ($InFile) { $request.InFile = $InFile }
    elseif ($null -ne $Body) {
        $json = if ($Body -is [string]) { $Body } else { ConvertTo-Json -InputObject $Body -Depth 10 }
        $request.Body = [Text.Encoding]::UTF8.GetBytes($json)
    }
    $response = Invoke-BoardRequest -Request $request
    # With an expired or missing token Azure DevOps answers 203 with its sign-in page (HTML), not JSON
    if ($response -is [string] -and (Update-BoardToken)) {
        $request.Headers = $ctx.Headers
        $response = Invoke-BoardRequest -Request $request
    }
    if ($response -is [string]) { throw "Azure DevOps answered $Method $uri with a page instead of JSON (expired or missing token?). Run az login and start the script again." }
    return $response
}

function Invoke-BoardRequest {
    # The only call to Invoke-RestMethod, so tests can replace the HTTP answer
    param([Parameter(Mandatory)] [hashtable] $Request)
    return Invoke-RestMethod @Request
}

# --- Pure helpers (tested) ------------------------------------------------------

function Expand-ChangeText {
    <# Replaces {id} (work item id) and other {name} placeholders. #>
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Text, [Parameter(Mandatory)] [hashtable] $Values)
    foreach ($key in $Values.Keys) { $Text = $Text.Replace("{$key}", [string] $Values[$key]) }
    return $Text
}

function Get-StagedSourcePath {
    <# Repository path -> path in the staging tree; .github is staged as github (dot folders cannot be written there). #>
    param([Parameter(Mandatory)] [string] $Staging, [Parameter(Mandatory)] [string] $Path)
    $relative = $Path -replace '^\.github(?=/|$)', 'github'
    return Join-Path -Path (Join-Path -Path $Staging -ChildPath 'tree') -ChildPath $relative
}

function Resolve-CheckRun {
    <#
    .SYNOPSIS
        Reduces gh pr checks output (name, bucket) to one state per check name.
    .DESCRIPTION
        A run cancelled by a newer run of the same check does not count (the Azure Boards app edits the PR
        description right after creation, which starts a new run and cancels the old one). A check whose
        only runs are cancelled is still pending. Returns @{ State = pending|fail|pass; Summary; Failed }.
    #>
    param([AllowEmptyCollection()] [object[]] $Checks = @(), [string] $Exclude)
    $relevant = @($Checks | Where-Object { $_ -and $_.name -ne $Exclude })
    if ($relevant.Count -eq 0) { return [pscustomobject]@{ State = 'pending'; Summary = ''; Failed = @() } }
    $runs = foreach ($group in ($relevant | Group-Object -Property name)) {
        $live = @($group.Group | Where-Object { $_.bucket -ne 'cancel' })
        if ($live.Count -gt 0) { $live } else { [pscustomobject]@{ name = $group.Name; bucket = 'pending' } }
    }
    $runs = @($runs)
    $failed = @($runs | Where-Object { $_.bucket -eq 'fail' } | ForEach-Object { $_.name })
    $state = if ($failed.Count -gt 0) { 'fail' } elseif (@($runs | Where-Object { $_.bucket -eq 'pending' }).Count -gt 0) { 'pending' } else { 'pass' }
    $summary = ($runs | ForEach-Object { "$($_.name)=$($_.bucket)" }) -join ', '
    return [pscustomobject]@{ State = $state; Summary = $summary; Failed = $failed }
}

function ConvertFrom-RunList {
    <#
    .SYNOPSIS
        Parses "<id> <url>" lines from gh run list; returns the first run or $null.
    .DESCRIPTION
        An empty list must give $null, not a run with id "null" (the AB#19 deployment step failed that way).
    #>
    param([AllowNull()] [AllowEmptyCollection()] [object[]] $Lines)
    foreach ($line in @($Lines)) {
        if (-not $line) { continue }
        $parts = ([string] $line).Trim() -split '\s+', 2
        if ($parts.Count -eq 2 -and $parts[0] -match '^\d+$') { return [pscustomobject]@{ Id = [long] $parts[0]; Url = $parts[1] } }
    }
    return $null
}

function Get-ReviewGateDecision {
    <# State and description of the review gate status for viewed/total files. #>
    param([Parameter(Mandatory)] [int] $Viewed, [Parameter(Mandatory)] [int] $Total)
    if ($Total -gt 0 -and $Viewed -ge $Total) { return [pscustomobject]@{ State = 'success'; Description = "All $Total files viewed" } }
    return [pscustomobject]@{ State = 'pending'; Description = "$Viewed of $Total files viewed" }
}

function Invoke-ResultCheck {
    <#
    .SYNOPSIS
        Evaluates named result checks; prints them and returns @{ Failed; Html } for the result comment.
    .PARAMETER Checks
        Ordered dictionary: name -> bool, or name -> scriptblock returning bool (a throwing check fails).
    #>
    param([Parameter(Mandatory)] [System.Collections.IDictionary] $Checks)
    $failed = 0
    $items = foreach ($name in $Checks.Keys) {
        $value = $Checks[$name]
        $ok = $false
        try { $ok = [bool] $(if ($value -is [scriptblock]) { & $value } else { $value }) } catch { $ok = $false }
        $encoded = [System.Net.WebUtility]::HtmlEncode([string] $name)
        if ($ok) { Write-ChangeOk $name; "<li>OK: $encoded</li>" }
        else { Write-Host "    - $name" -ForegroundColor Red; $failed++; "<li><b>FAILED</b>: $encoded</li>" }
    }
    return [pscustomobject]@{ Failed = $failed; Html = ($items -join '') }
}

# --- Azure Boards ---------------------------------------------------------------

function Find-BoardItem {
    param([Parameter(Mandatory)] [string] $Type, [Parameter(Mandatory)] [string] $Title)
    $ctx = Get-ChangeContext
    $query = "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = '$($ctx.Project)' AND [System.WorkItemType] = '$Type' AND [System.Title] = '$($Title.Replace("'", "''"))'"
    $result = Invoke-BoardApi -Method Post -Path 'wit/wiql?api-version=7.1' -Body @{ query = $query }
    $first = @($result.workItems) | Select-Object -First 1
    if ($first) { return [int] $first.id }
    return $null
}

function New-BoardItem {
    <# Finds a work item by type and title, or creates it under ParentId. Returns its id. #>
    param([Parameter(Mandatory)] [hashtable] $Item, [Parameter(Mandatory)] [int] $ParentId)
    $existing = Find-BoardItem -Type $Item.Type -Title $Item.Title
    if ($existing) { Write-ChangeSkip "$($Item.Type) #$existing $($Item.Title)"; return $existing }
    $ctx = Get-ChangeContext
    $patch = [System.Collections.Generic.List[object]]::new()
    $patch.Add(@{ op = 'add'; path = '/fields/System.Title'; value = $Item.Title })
    $patch.Add(@{ op = 'add'; path = '/fields/System.AreaPath'; value = "$($ctx.Project)\$($Item.Area)" })
    # Index access, not dot access: under strict mode a missing hashtable key read with a dot throws
    if ($Item['Tags']) { $patch.Add(@{ op = 'add'; path = '/fields/System.Tags'; value = $Item['Tags'] }) }
    if ($Item['Description']) { $patch.Add(@{ op = 'add'; path = '/fields/System.Description'; value = $Item['Description'] }) }
    if ($Item['AcceptanceCriteria']) { $patch.Add(@{ op = 'add'; path = '/fields/Microsoft.VSTS.Common.AcceptanceCriteria'; value = $Item['AcceptanceCriteria'] }) }
    $patch.Add(@{ op = 'add'; path = '/relations/-'; value = @{ rel = 'System.LinkTypes.Hierarchy-Reverse'; url = "https://dev.azure.com/$($ctx.Organization)/_apis/wit/workItems/$ParentId" } })
    $type = [uri]::EscapeDataString($Item.Type)
    $created = Invoke-BoardApi -Method Post -Path "wit/workitems/`$$($type)?api-version=7.1" -ContentType 'application/json-patch+json; charset=utf-8' `
        -Body (ConvertTo-Json -InputObject $patch.ToArray() -Depth 6)
    Write-ChangeOk "$($Item.Type) #$($created.id) $($Item.Title)"
    return [int] $created.id
}

function Get-BoardItem {
    param([Parameter(Mandatory)] [int] $Id)
    return Invoke-BoardApi -Path "wit/workitems/$($Id)?api-version=7.1"
}

function Set-BoardItemField {
    param([Parameter(Mandatory)] [int] $Id, [Parameter(Mandatory)] [string] $Field, [Parameter(Mandatory)] [string] $Value)
    $body = ConvertTo-Json -InputObject @(@{ op = 'add'; path = "/fields/$Field"; value = $Value }) -Depth 3
    Invoke-BoardApi -Method Patch -Path "wit/workitems/$($Id)?api-version=7.1" -ContentType 'application/json-patch+json; charset=utf-8' -Body $body | Out-Null
}

function Set-BoardItemState {
    param([Parameter(Mandatory)] [int] $Id, [Parameter(Mandatory)] [string] $State)
    Set-BoardItemField -Id $Id -Field 'System.State' -Value $State
    Write-ChangeOk "AB#$Id -> $State"
}

function Test-BoardComment {
    <# True when a Discussion comment of the work item contains the marker, e.g. "[evidence AB#17]". #>
    param([Parameter(Mandatory)] [int] $Id, [Parameter(Mandatory)] [string] $Marker)
    $comments = (Invoke-BoardApi -Path "wit/workItems/$Id/comments?api-version=7.1-preview.4").comments
    return [bool] (@($comments) | Where-Object { $_ -and ([string] $_.text).Contains($Marker) })
}

function Add-BoardComment {
    param([Parameter(Mandatory)] [int] $Id, [Parameter(Mandatory)] [string] $Html)
    $c = Invoke-BoardApi -Method Post -Path "wit/workItems/$Id/comments?api-version=7.1-preview.4" -Body @{ text = $Html }
    Write-ChangeOk "comment $($c.id) in AB#$Id"
}

function Add-BoardAttachment {
    <# Uploads a file, attaches it to the work item and returns its URL for an <img> in a comment. #>
    param([Parameter(Mandatory)] [int] $Id, [Parameter(Mandatory)] [string] $Path)
    $name = [uri]::EscapeDataString((Split-Path -Path $Path -Leaf))
    $a = Invoke-BoardApi -Method Post -Path "wit/attachments?fileName=$name&api-version=7.1" -ContentType 'application/octet-stream' -InFile $Path
    $body = ConvertTo-Json -InputObject @(@{ op = 'add'; path = '/relations/-'; value = @{ rel = 'AttachedFile'; url = $a.url; attributes = @{ comment = 'Evidence' } } }) -Depth 6
    Invoke-BoardApi -Method Patch -Path "wit/workitems/$($Id)?api-version=7.1" -ContentType 'application/json-patch+json' -Body $body | Out-Null
    return $a.url
}

# --- Git ------------------------------------------------------------------------

function Get-BlobId {
    <# Blob id of a path at a revision ("HEAD:path"), in the index (":path"), or $null when absent. #>
    param([Parameter(Mandatory)] [string] $Spec)
    $r = Invoke-Git @('rev-parse', '--verify', '--quiet', $Spec)
    if ($r.ExitCode -ne 0) { return $null }
    return ([string] @($r.Output)[0]).Trim()
}

function Test-Baseline {
    <#
    .SYNOPSIS
        Each file must have, at Revision, the blob id the change was verified against ($null = must be absent).
    .PARAMETER Files
        Ordered dictionary: path -> @(blobBefore, blobAfter).
    #>
    param([Parameter(Mandatory)] [System.Collections.IDictionary] $Files, [string] $Revision = 'HEAD')
    foreach ($path in $Files.Keys) {
        $actual = Get-BlobId "${Revision}:$path"
        $expected = $Files[$path][0]
        if ($actual -ne $expected) { throw "$path at $Revision is $(if ($actual) { $actual } else { 'absent' }), expected $(if ($expected) { $expected } else { 'absent' }). Rebuild the change on the new main." }
    }
    Write-ChangeOk "$($Files.Count) files match the verified baseline"
}

function Test-StagedBlob {
    param([Parameter(Mandatory)] [System.Collections.IDictionary] $Files)
    foreach ($path in $Files.Keys) {
        $actual = Get-BlobId ":$path"
        if ($actual -ne $Files[$path][1]) { throw "Staged $path is $actual, expected $($Files[$path][1]). Stage the files again." }
    }
}

function Update-MainBranch {
    foreach ($arguments in @(@('switch', 'main'), @('pull', '--prune'))) {
        $r = Invoke-Git $arguments
        if ($r.ExitCode -ne 0) { throw "git $($arguments -join ' ') failed: $($r.Output -join ' ')" }
    }
}

function Reset-PreparedFile {
    <# Puts back files left by an interrupted run, only if they are byte-identical to the staged copies. #>
    param([Parameter(Mandatory)] [System.Collections.IDictionary] $Files)
    $ctx = Get-ChangeContext
    foreach ($line in @((Invoke-Git @('status', '--porcelain', '--untracked-files=all')).Output)) {
        if (-not $line) { continue }
        $status = ([string] $line).Substring(0, 2)
        $path = ([string] $line).Substring(3).Trim('"')
        $source = Get-StagedSourcePath -Staging $ctx.Staging -Path $path
        $prepared = $Files.Contains($path) -and (Test-Path -LiteralPath $source) -and
            ((Get-FileHash -LiteralPath $source).Hash -eq (Get-FileHash -LiteralPath $path).Hash)
        if (-not $prepared) { throw "Uncommitted change in $path that this change did not prepare. Commit or stash it, then run again." }
        if ($status -eq '??') { Remove-Item -LiteralPath $path -Force } else { Invoke-Git @('restore', '--staged', '--worktree', '--', $path) | Out-Null }
        Write-ChangeSkip "${path}: put back (left by an earlier run)"
    }
}

function Copy-StagedFile {
    param([Parameter(Mandatory)] [System.Collections.IDictionary] $Files)
    $ctx = Get-ChangeContext
    foreach ($path in $Files.Keys) {
        $dir = Split-Path -Path $path -Parent
        if ($dir) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Copy-Item -LiteralPath (Get-StagedSourcePath -Staging $ctx.Staging -Path $path) -Destination $path -Force
    }
}

function New-SignedCommit {
    <# Creates the branch, stages the files, checks their blobs, commits signed, verifies the signature and pushes. #>
    param(
        [Parameter(Mandatory)] [string] $Branch,
        [Parameter(Mandatory)] [string] $Message,
        [Parameter(Mandatory)] [System.Collections.IDictionary] $Files
    )
    $r = Invoke-Git @('switch', '-c', $Branch)
    if ($r.ExitCode -ne 0) { throw "git switch -c $Branch failed: $($r.Output -join ' ')" }
    $r = Invoke-Git (@('add', '--') + @($Files.Keys))
    if ($r.ExitCode -ne 0) { throw "git add failed: $($r.Output -join ' ')" }
    Test-StagedBlob -Files $Files
    $messageFile = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath 'signallog-commit-msg.txt'
    Set-Content -LiteralPath $messageFile -Value $Message -Encoding utf8NoBOM
    try {
        $r = Invoke-Git @('commit', '--file', $messageFile)
        if ($r.ExitCode -ne 0) { throw "git commit failed: $($r.Output -join ' ')" }
    }
    finally { Remove-Item -LiteralPath $messageFile -ErrorAction SilentlyContinue }
    $signature = ([string] @((Invoke-Git @('log', '-1', '--format=%G?')).Output)[0]).Trim()
    if ($signature -ne 'G') { throw "The commit is not signed with a valid key (git reports '$signature'). Stopping before push." }
    (Invoke-Git @('log', '--show-signature', '-1')).Output | Write-Host
    $r = Invoke-Git @('push', '--set-upstream', 'origin', $Branch)
    if ($r.ExitCode -ne 0) { throw "git push failed: $($r.Output -join ' ')" }
    Write-ChangeOk "signed commit pushed to $Branch"
}

# --- GitHub ---------------------------------------------------------------------

function Get-ChangePullRequest {
    param([Parameter(Mandatory)] [string] $Branch, [ValidateSet('open', 'merged')] [string] $State = 'open')
    $ctx = Get-ChangeContext
    $r = Invoke-Gh @('pr', 'list', '--repo', $ctx.Repository, '--head', $Branch, '--state', $State, '--json', 'number', '--jq', '.[0].number')
    $n = [string] @($r.Output)[0]
    if ($n -match '^\d+$') { return [int] $n }
    return $null
}

function New-ChangePullRequest {
    param([Parameter(Mandatory)] [string] $Branch, [Parameter(Mandatory)] [string] $Title, [Parameter(Mandatory)] [string] $Body)
    $ctx = Get-ChangeContext
    $r = Invoke-Gh @('pr', 'create', '--repo', $ctx.Repository, '--base', 'main', '--head', $Branch, '--title', $Title, '--body', $Body)
    if ($r.ExitCode -ne 0) { throw 'gh pr create failed' }
    for ($i = 0; $i -lt 10; $i++) {
        $n = Get-ChangePullRequest -Branch $Branch -State open
        if ($n) { Write-ChangeOk "pull request #$n"; return $n }
        Start-Sleep -Seconds 3
    }
    throw 'The new pull request was not found.'
}

function Wait-PullRequestCheck {
    <# Waits for the CI checks of the pull request (not the review gate); throws on a red check. #>
    param([Parameter(Mandatory)] [int] $Number, [int] $TimeoutMinutes = 60)
    $ctx = Get-ChangeContext
    $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
    while ((Get-Date) -lt $deadline) {
        $r = Invoke-Gh @('pr', 'checks', [string] $Number, '--repo', $ctx.Repository, '--json', 'name,bucket')
        $checks = if ($r.Output) { @(($r.Output -join "`n") | ConvertFrom-Json) } else { @() }
        $state = Resolve-CheckRun -Checks $checks -Exclude $ctx.Gate
        if ($state.State -eq 'fail') { throw "CI failed on PR #${Number}: $($state.Failed -join ', '). Fix it in the branch and run the script again." }
        if ($state.State -eq 'pass') { Write-ChangeOk "CI: $($state.Summary)"; return $state }
        Start-Sleep -Seconds 15
    }
    throw "CI did not finish on PR #$Number within $TimeoutMinutes minutes."
}

function Get-ReviewState {
    param([Parameter(Mandatory)] [int] $Number)
    $ctx = Get-ChangeContext
    $query = 'query($owner:String!,$name:String!,$number:Int!){repository(owner:$owner,name:$name){pullRequest(number:$number){state headRefOid files(first:100){nodes{viewerViewedState}}}}}'
    $r = Invoke-Gh @('api', 'graphql', '-F', "owner=$($ctx.Owner)", '-F', "name=$($ctx.Name)", '-F', "number=$Number", '-f', "query=$query",
        '--jq', '.data.repository.pullRequest | {state, head: .headRefOid, total: (.files.nodes | length), viewed: ([.files.nodes[] | select(.viewerViewedState == "VIEWED")] | length)}')
    if ($r.ExitCode -ne 0) { throw 'GitHub GraphQL query failed' }
    return ($r.Output -join "`n") | ConvertFrom-Json
}

function Set-ReviewGateStatus {
    param([Parameter(Mandatory)] [string] $Sha, [Parameter(Mandatory)] [string] $State, [Parameter(Mandatory)] [string] $Description, [Parameter(Mandatory)] [int] $Number)
    $ctx = Get-ChangeContext
    $r = Invoke-Gh @('api', '-X', 'POST', "repos/$($ctx.Repository)/statuses/$Sha", '-f', "state=$State", '-f', "context=$($ctx.Gate)",
        '-f', "description=$Description", '-f', "target_url=https://github.com/$($ctx.Repository)/pull/$Number/files")
    if ($r.ExitCode -ne 0) { throw 'Setting the review gate status failed' }
}

function Wait-ReviewAndMerge {
    <# Opens the PR, keeps the review gate in step with the Viewed marks and waits for the owner's merge. #>
    param([Parameter(Mandatory)] [int] $Number)
    $ctx = Get-ChangeContext
    Write-Host "    Review PR #$Number in the browser: mark every file as Viewed, then press 'Squash and merge'." -ForegroundColor Yellow
    Write-Host '    The script follows the Viewed marks and waits for your merge; Ctrl+C stops it, a later run resumes.' -ForegroundColor Yellow
    Invoke-Gh @('pr', 'view', [string] $Number, '--repo', $ctx.Repository, '--web') | Out-Null
    $last = ''
    while ($true) {
        $s = Get-ReviewState -Number $Number
        if ($s.state -eq 'MERGED') { break }
        if ($s.state -eq 'CLOSED') { throw "PR #$Number was closed without merging. Stopping." }
        $key = "$($s.head)/$($s.viewed)/$($s.total)"
        if ($key -ne $last) {
            $decision = Get-ReviewGateDecision -Viewed $s.viewed -Total $s.total
            Set-ReviewGateStatus -Sha $s.head -State $decision.State -Description $decision.Description -Number $Number
            if ($decision.State -eq 'success') { Write-ChangeOk "$($decision.Description): $($ctx.Gate) is green, merge is yours" }
            else { Write-Host "    . $($decision.Description)" -ForegroundColor DarkGray }
            $last = $key
        }
        Start-Sleep -Seconds 15
    }
    Write-ChangeOk "PR #$Number merged"
}

function Wait-Deployment {
    <# Waits for the workflow run of the merge commit to start and finish; returns @{ Id; Url }. #>
    param([Parameter(Mandatory)] [string] $Sha, [string] $Workflow = 'docs.yml', [int] $StartTimeoutSeconds = 300)
    $ctx = Get-ChangeContext
    $run = $null
    $deadline = (Get-Date).AddSeconds($StartTimeoutSeconds)
    while (-not $run -and (Get-Date) -lt $deadline) {
        $r = Invoke-Gh @('run', 'list', '--repo', $ctx.Repository, '--workflow', $Workflow, '--commit', $Sha, '--limit', '1', '--json', 'databaseId,url', '--jq', '.[] | "\(.databaseId) \(.url)"')
        $run = ConvertFrom-RunList -Lines $r.Output
        if (-not $run) { Start-Sleep -Seconds 10 }
    }
    if (-not $run) { throw "The $Workflow workflow did not start for $Sha." }
    $w = Invoke-Gh @('run', 'watch', [string] $run.Id, '--repo', $ctx.Repository, '--exit-status', '--interval', '15')
    if ($w.ExitCode -ne 0) { throw "The $Workflow workflow failed: $($run.Url)" }
    Write-ChangeOk "$Workflow run $($run.Id) succeeded"
    return $run
}

# --- The whole change ------------------------------------------------------------

function Invoke-Change {
    <#
    .SYNOPSIS
        Runs one change through the change workflow. Safe to run again: finished steps are skipped.
    .PARAMETER Change
        Hashtable with:
          Story         int id of an existing work item, or
          StoryItem     hashtable (Type, Title, Area, Tags, AcceptanceCriteria) found or created under
          FeatureItem   hashtable found or created under EpicId (optional; else StoryParent int)
          Branch        branch name; {id} is replaced by the work item id
          Title         pull request title and commit subject; {id} replaced
          Files         ordered: path -> @(blobBefore or $null, blobAfter)
          Evidence      @{ Items = '<li>..</li>...'; Images = @('file.png', ...) } (files under Staging\evidence)
          CommitBody    commit message body; {id} replaced
          PrBody        pull request description; {id} and {evidence} replaced
          Precheck      optional scriptblock run before anything is changed
          Workflow      workflow file deployed on main (default docs.yml; $null = no deployment)
          Published     URL named in the result comment
          ResultChecks  scriptblock returning an ordered dictionary name -> bool or scriptblock
    #>
    param([Parameter(Mandatory)] [hashtable] $Change)
    $ctx = Get-ChangeContext

    Write-ChangeStep '1. Work item'
    # Optional keys are read by index: under strict mode a missing hashtable key read with a dot throws
    if ($Change['Story']) { $id = [int] $Change['Story'] }
    else {
        $parent = if ($Change['FeatureItem']) { New-BoardItem -Item $Change['FeatureItem'] -ParentId $Change['EpicId'] } else { [int] $Change['StoryParent'] }
        $id = New-BoardItem -Item $Change['StoryItem'] -ParentId $parent
    }
    $state = (Get-BoardItem -Id $id).fields.'System.State'
    if ($state -eq 'New') { Set-BoardItemState -Id $id -State 'Active'; $state = 'Active' }
    Write-Host "    AB#$id [$state]"
    if ($state -notin @('Active', 'Resolved')) { throw "AB#$id is '$state'; it must be Active (or Resolved on a re-run)." }

    $values = @{ id = $id; evidence = "https://dev.azure.com/$($ctx.Organization)/$($ctx.Project)/_workitems/edit/$id" }
    $branch = Expand-ChangeText $Change.Branch $values
    $title = Expand-ChangeText $Change.Title $values
    $files = $Change.Files
    $evidenceMarker = "[evidence AB#$id]"
    $resultMarker = "[result AB#$id]"
    $trailer = "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01RLzhf5iziPxvCyLkZjanXQ"

    $merged = Get-ChangePullRequest -Branch $branch -State merged
    $open = Get-ChangePullRequest -Branch $branch -State open

    if (-not $merged -and -not $open) {
        Write-ChangeStep '2. Base and baseline'
        Reset-PreparedFile -Files $files
        Update-MainBranch
        Test-Baseline -Files $files -Revision 'HEAD'
        if ($Change['Precheck']) { & $Change['Precheck'] }

        Write-ChangeStep '3. Files and evidence'
        Copy-StagedFile -Files $files
        if (-not (Test-BoardComment -Id $id -Marker $evidenceMarker)) {
            $images = foreach ($image in @($Change['Evidence']['Images'])) {
                if (-not $image) { continue }
                $url = Add-BoardAttachment -Id $id -Path (Join-Path -Path (Join-Path -Path $ctx.Staging -ChildPath 'evidence') -ChildPath $image)
                "<p><img src=`"$url`" alt=`"$([System.Net.WebUtility]::HtmlEncode($image))`"/></p>"
            }
            $rows = ($files.Keys | ForEach-Object { "<li><code>$_</code>: blob <code>$($files[$_][1].Substring(0, 12))</code></li>" }) -join ''
            $items = Expand-ChangeText ([string] $Change['Evidence']['Items']) $values
            Add-BoardComment -Id $id -Html "<p><b>$evidenceMarker</b> Checked before the pull request (change workflow, step 3).</p><ol>$items</ol><p>Files (git blob after the change):</p><ul>$rows</ul>$($images -join '')"
        }
        else { Write-ChangeSkip 'evidence comment already in the work item' }

        Write-ChangeStep '4. Signed commit and pull request'
        $message = "$title`n`n$((Expand-ChangeText $Change.CommitBody $values).Trim())`n`nWork item: AB#$id`n`n$trailer"
        New-SignedCommit -Branch $branch -Message $message -Files $files
        $body = "$((Expand-ChangeText $Change.PrBody $values).Trim())`n`n🤖 Generated with [Claude Code](https://claude.com/claude-code)`n`nhttps://claude.ai/code/session_01RLzhf5iziPxvCyLkZjanXQ"
        $open = New-ChangePullRequest -Branch $branch -Title $title -Body $body
        if ((Get-BoardItem -Id $id).fields.'System.State' -ne 'Resolved') { Set-BoardItemState -Id $id -State 'Resolved' }
    }

    if (-not $merged) {
        Write-ChangeStep "5. CI on PR #$open"
        Wait-PullRequestCheck -Number $open | Out-Null
        Write-ChangeStep '6. Review and merge (yours)'
        Wait-ReviewAndMerge -Number $open
        $merged = $open
    }

    Write-ChangeStep '7. Deployment and result'
    Update-MainBranch
    if ((Invoke-Git @('branch', '--list', $branch)).Output) { Invoke-Git @('branch', '-D', $branch) | Out-Null }
    $sha = ([string] @((Invoke-Gh @('pr', 'view', [string] $merged, '--repo', $ctx.Repository, '--json', 'mergeCommit', '--jq', '.mergeCommit.oid')).Output)[0]).Trim()
    $workflow = if ($Change.ContainsKey('Workflow')) { $Change.Workflow } else { 'docs.yml' }
    $deployLine = 'Deployment: none for this change'
    if ($workflow) {
        $run = Wait-Deployment -Sha $sha -Workflow $workflow
        $deployLine = "Deployment: <a href=`"$($run.Url)`">$workflow run $($run.Id)</a>, success"
        Start-Sleep -Seconds 30
    }
    $result = Invoke-ResultCheck -Checks (& $Change.ResultChecks)

    if (-not (Test-BoardComment -Id $id -Marker $resultMarker)) {
        $published = if ($Change['Published']) { "<li>Published: <a href=`"$($Change['Published'])`">$($Change['Published'])</a></li>" } else { '' }
        Add-BoardComment -Id $id -Html @"
<p><b>$resultMarker</b> After merge (change workflow, step 8).</p>
<ul>
<li>Pull request: <a href="https://github.com/$($ctx.Repository)/pull/$merged">#$merged</a></li>
<li>Merge commit: <a href="https://github.com/$($ctx.Repository)/commit/$sha"><code>$($sha.Substring(0, 7))</code></a></li>
<li>$deployLine</li>
$published
</ul>
<p>Result checks:</p><ul>$($result.Html)</ul>
<p>Closing this work item is the owner's decision.</p>
"@
    }

    Write-Host ''
    if ($result.Failed) {
        Write-Warning "$($result.Failed) result check(s) failed; see the result comment in AB#$id. Leave the work item open; staging kept at $($ctx.Staging)."
    }
    else {
        Remove-Item -LiteralPath $ctx.Staging -Recurse -Force
        Write-Host "Done. Read the evidence and result in AB#$id and close it by hand: $($values.evidence)" -ForegroundColor Green
    }
    return [pscustomobject]@{ Id = $id; PullRequest = $merged; MergeCommit = $sha; Failed = $result.Failed }
}

Export-ModuleMember -Function @(
    'Initialize-ChangeContext', 'Get-ChangeContext', 'Invoke-Change',
    'Expand-ChangeText', 'Get-StagedSourcePath', 'Resolve-CheckRun', 'ConvertFrom-RunList', 'Get-ReviewGateDecision', 'Invoke-ResultCheck',
    'Find-BoardItem', 'New-BoardItem', 'Get-BoardItem', 'Set-BoardItemField', 'Set-BoardItemState', 'Test-BoardComment', 'Add-BoardComment', 'Add-BoardAttachment',
    'Get-BlobId', 'Test-Baseline', 'Test-StagedBlob', 'Update-MainBranch', 'Reset-PreparedFile', 'Copy-StagedFile', 'New-SignedCommit',
    'Get-ChangePullRequest', 'New-ChangePullRequest', 'Wait-PullRequestCheck', 'Get-ReviewState', 'Set-ReviewGateStatus', 'Wait-ReviewAndMerge', 'Wait-Deployment'
)
