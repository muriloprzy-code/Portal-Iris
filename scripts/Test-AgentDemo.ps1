[CmdletBinding()]
param(
    [string]$BaseUrl = 'http://localhost:52774',
    # An administrator (runs the in-IRIS suite and creates a test proposal on a real task).
    [Parameter(Mandatory)]
    [PSCredential]$Credential,
    # The public demo account ("demo"); its password is MYOWN_DEMO_USER_PASSWORD in .env.
    [PSCredential]$DemoCredential,
    [string]$Namespace = 'MYOWN',
    [string]$OutputPath = 'test-results/agents-demo.json'
)

# Public demo suite. Always: MyOwn_Test.DemoSmoke() (demo mode forced for that process: reset,
# synthetic targets, refusal of real targets, simulated confirmations, rate limit). With
# -DemoCredential on a server running MYOWN_DEMO_MODE=1: the demo account over REST (allowed and
# refused routes, scenario + confirmation on synthetic targets, refusal of a real target, reset,
# rate limit, real-system routes refused for the administrator too).

$ErrorActionPreference = 'Stop'
$startedAt = [DateTimeOffset]::Now
$root = $BaseUrl.TrimEnd('/')
$results = [System.Collections.Generic.List[object]]::new()

function New-Headers([PSCredential]$cred) {
    $token = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$($cred.UserName):$($cred.GetNetworkCredential().Password)"))
    @{ Authorization = "Basic $token"; 'X-MyOwn-SysAdmin-Authorization' = "Basic $token"; Accept = 'application/json' }
}
$adminHeaders = New-Headers $Credential

function Invoke-Portal {
    param([hashtable]$Headers, [string]$Method, [string]$Path, [object]$Body)
    $arguments = @{ Uri = "$root/myown/api$Path"; Method = $Method; Headers = $Headers; UseBasicParsing = $true; TimeoutSec = 60 }
    if ($null -ne $Body) { $arguments.ContentType = 'application/json'; $arguments.Body = ($Body | ConvertTo-Json -Depth 10 -Compress) }
    try {
        $response = Invoke-WebRequest @arguments
        return [pscustomobject]@{ status = [int]$response.StatusCode; body = ($response.Content | ConvertFrom-Json); headers = $response.Headers }
    } catch [System.Net.WebException] {
        $http = $_.Exception.Response
        if ($null -eq $http) { throw }
        # Windows PowerShell keeps the error body in ErrorDetails.Message.
        $parsed = $null
        try { $parsed = $_.ErrorDetails.Message | ConvertFrom-Json } catch { }
        return [pscustomobject]@{ status = [int]$http.StatusCode; body = $parsed; headers = $http.Headers }
    }
}

function Invoke-IrisSql {
    param([string]$Query, [object[]]$Parameters = @())
    $body = @{ query = $Query; parameters = $Parameters } | ConvertTo-Json -Compress
    $response = Invoke-RestMethod -Method Post -Uri "$root/api/atelier/v1/$Namespace/action/query" -Headers $adminHeaders -ContentType 'application/json' -Body $body -TimeoutSec 120
    if ($response.status.errors.Count) { throw "SQL failed: $($response.status.errors | ConvertTo-Json -Compress)" }
    return $response.result.content
}

function Add-Result([string]$Id, [string]$Status, [string]$Details) {
    $results.Add([ordered]@{ id = $Id; status = $Status; details = $Details })
    $color = if ($Status -eq 'pass') { 'Green' } elseif ($Status -eq 'fail') { 'Red' } else { 'Yellow' }
    Write-Host ("{0,-5} {1}  {2}" -f $Status.ToUpper(), $Id, $Details) -ForegroundColor $color
}

function Wait-Audit([string]$Event, [string]$Marker, [int]$TimeoutSeconds = 120) {
    $started = Get-Date
    while (((Get-Date) - $started).TotalSeconds -lt $TimeoutSeconds) {
        $raw = (Invoke-IrisSql -Query 'SELECT MyOwn_Test.DemoAuditCheck(?, ?) AS r' -Parameters @($Event, $Marker))[0].r
        $check = if ($raw -is [string]) { $raw | ConvertFrom-Json } else { $raw }
        if ($check.done) { return [int]((Get-Date) - $started).TotalSeconds }
        Start-Sleep -Seconds 2
    }
    return -1
}

# In-IRIS suite (audit checks returned as pending and polled here, see Test-AgentSmoke.ps1).
$raw = (Invoke-IrisSql -Query 'SELECT MyOwn_Test.DemoSmoke(0) AS r')[0].r
$smoke = if ($raw -is [string]) { $raw | ConvertFrom-Json } else { $raw }
foreach ($item in $smoke.results) {
    if ($item.status -eq 'pending') {
        $seconds = Wait-Audit -Event $item.poll.args[0] -Marker $item.poll.args[1]
        if ($seconds -ge 0) { Add-Result $item.id 'pass' "$($item.details) (audit visible after $seconds s)" } else { Add-Result $item.id 'fail' "$($item.details) Audit event not visible after 120 s." }
    } else {
        Add-Result $item.id $item.status $item.details
    }
}

$session = Invoke-Portal $adminHeaders GET '/session'
$demoMode = [bool][int]$session.body.data.demoMode
if (-not $DemoCredential -or -not $demoMode) {
    Add-Result 'DM-REST' 'skip' 'REST checks need MYOWN_DEMO_MODE=1 on the server and -DemoCredential (the demo account).'
} else {
    $demoHeaders = New-Headers $DemoCredential
    $me = Invoke-Portal $demoHeaders GET '/session'
    Add-Result 'DM-10-SESSION' $(if ($me.status -eq 200 -and [bool][int]$me.body.data.isDemoUser -and -not [bool][int]$me.body.data.canManage) { 'pass' } else { 'fail' }) "The demo account signs in as the public demo user without administrator access (HTTP $($me.status))."

    $allowed = foreach ($path in '/health', '/agent/status', '/agent/decisions', '/agent/proposals', '/demo/state') { "$path=$((Invoke-Portal $demoHeaders GET $path).status)" }
    Add-Result 'DM-11-VIEW' $(if (-not ($allowed | Where-Object { $_ -notmatch '=200$' })) { 'pass' } else { 'fail' }) "The demo account can view the portal: $($allowed -join ', ')."

    $refusedCalls = @(
        @('PUT', '/agent/config', @{ killSwitch = $true }), @('GET', '/agent/config', $null), @('POST', '/agent/killswitch', @{ enabled = $true }),
        @('POST', '/agent/production/stop', @{}), @('POST', '/agent/analyze', @{}), @('GET', '/agent/pricing', $null), @('PUT', '/agent/pricing', @{ model = 'x' }),
        @('POST', '/agent/access-requests', @{ role = 'DemoOperator'; justification = 'test' }), @('POST', '/tasks/action', @{ id = 1; action = 'suspend' }),
        @('POST', '/applications/state', @{ name = '/csp/user'; enabled = $false }), @('POST', '/permissions/users/demo/roles', @{ role = '%All' })
    )
    $statuses = foreach ($call in $refusedCalls) { "$($call[0]) $($call[1])=$((Invoke-Portal $demoHeaders $call[0] $call[1] $call[2]).status)" }
    Add-Result 'DM-12-ADMIN-REFUSED' $(if (-not ($statuses | Where-Object { $_ -notmatch '=403$' })) { 'pass' } else { 'fail' }) "Administration, settings and real-system routes are refused for the demo account: $($statuses -join ', ')."

    $realSystem = Invoke-Portal $adminHeaders POST '/tasks/action' @{ id = 1; action = 'suspend' }
    Add-Result 'DM-13-REAL-SYSTEM' $(if ($realSystem.status -eq 403 -and $realSystem.body.error.code -eq 'DEMO_MODE_FORBIDDEN') { 'pass' } else { 'fail' }) "In demo mode even an administrator cannot change real tasks through the portal (HTTP $($realSystem.status) $($realSystem.body.error.code))."

    $reset = Invoke-Portal $demoHeaders POST '/demo/reset' @{}
    $simulation = Invoke-Portal $demoHeaders POST '/agent/simulate' @{ scenario = 'S2' }
    $proposalId = [int]$simulation.body.data.proposalId
    $confirm = if ($proposalId) { Invoke-Portal $demoHeaders POST "/agent/proposals/$proposalId/confirm" @{} } else { $null }
    $state = (Invoke-Portal $demoHeaders GET '/demo/state').body.data
    $task = @($state.targets.tasks | Where-Object { $_.id -eq 9001 })[0]
    $ok = ($reset.status -eq 200) -and ($simulation.status -eq 200) -and $proposalId -and ($confirm.status -eq 200) -and ($confirm.body.data.state -eq 'simulated') -and ([int]$task.suspended -eq 1)
    Add-Result 'DM-14-CONFIRM-SYNTHETIC' $(if ($ok) { 'pass' } else { 'fail' }) "Reset, S2 and confirmation by the demo account: proposal $proposalId ended '$($confirm.body.data.state)', synthetic task 9001 suspended=$($task.suspended) (reset $($reset.status), simulate $($simulation.status), confirm $($confirm.status))."

    $realProposal = [int](Invoke-IrisSql -Query 'SELECT MyOwn_Test.DemoRealProposal() AS r')[0].r
    $refused = Invoke-Portal $demoHeaders POST "/agent/proposals/$realProposal/confirm" @{}
    $seconds = if ($refused.status -eq 403) { Wait-Audit -Event 'DemoRefused' -Marker "proposal $realProposal" } else { -1 }
    Invoke-Portal $adminHeaders POST "/agent/proposals/$realProposal/reject" @{ reason = 'demo test cleanup' } | Out-Null
    Add-Result 'DM-15-REAL-REFUSED' $(if ($refused.status -eq 403 -and $refused.body.error.code -eq 'DEMO_TARGET_REFUSED' -and $seconds -ge 0) { 'pass' } else { 'fail' }) "Confirming a proposal on a real task is refused (HTTP $($refused.status) $($refused.body.error.code)) and audited as DemoRefused$(if ($seconds -ge 0) { " (visible after $seconds s)" })."

    $reset = Invoke-Portal $demoHeaders POST '/demo/reset' @{}
    $state = (Invoke-Portal $demoHeaders GET '/demo/state').body.data
    $task = @($state.targets.tasks | Where-Object { $_.id -eq 9001 })[0]
    $seconds = if ($reset.status -eq 200) { Wait-Audit -Event 'DemoReset' -Marker 'button by demo' } else { -1 }
    Add-Result 'DM-16-RESET' $(if ($reset.status -eq 200 -and [int]$task.suspended -eq 0 -and $seconds -ge 0) { 'pass' } else { 'fail' }) "The demo account's Reset demo restores task 9001 (suspended=$($task.suspended)) and is audited as DemoReset (HTTP $($reset.status))."

    $codes = foreach ($attempt in 1..12) { (Invoke-Portal $demoHeaders POST '/agent/simulate' @{ scenario = 'S4' }).status }
    $firstLimited = [array]::IndexOf([int[]]$codes, 429)
    Add-Result 'DM-17-RATE-LIMIT' $(if ($firstLimited -ge 1) { 'pass' } else { 'fail' }) "Rapid scenarios from one client are limited per minute: HTTP $($codes -join ',')."
}

$pass = @($results | Where-Object status -eq 'pass').Count
$fail = @($results | Where-Object status -eq 'fail').Count
$skip = @($results | Where-Object status -eq 'skip').Count
$report = [ordered]@{ suite = 'agents-demo'; startedAt = $startedAt.ToString('o'); finishedAt = [DateTimeOffset]::Now.ToString('o'); demoMode = $demoMode; results = $results; summary = [ordered]@{ pass = $pass; fail = $fail; skip = $skip } }
$projectRoot = Split-Path -Parent $PSScriptRoot
$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $projectRoot $OutputPath }
$directory = Split-Path -Parent $resolvedOutput
if (-not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resolvedOutput -Encoding UTF8
Write-Host "Report written to $resolvedOutput" -ForegroundColor Cyan
if ($fail -gt 0) { throw "$fail demo test(s) failed." }
Write-Host "Demo suite completed: $pass passed, $skip skipped." -ForegroundColor Green
