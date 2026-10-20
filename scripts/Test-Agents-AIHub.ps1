[CmdletBinding()]
param(
    [string]$BaseUrl = 'http://localhost:52774',
    [Parameter(Mandatory)]
    [PSCredential]$Credential,
    [string]$OutputPath = 'test-results/agents-aihub.json'
)

$ErrorActionPreference = 'Stop'
$startedAt = [DateTimeOffset]::Now
$root = $BaseUrl.TrimEnd('/')
$password = $Credential.GetNetworkCredential().Password
$token = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$($Credential.UserName):$password"))
$headers = @{ Authorization = "Basic $token"; 'X-MyOwn-SysAdmin-Authorization' = "Basic $token"; Accept = 'application/json' }
$results = [System.Collections.Generic.List[object]]::new()

function Invoke-PortalJson {
    param([string]$Method, [string]$Path, [object]$Body)
    $arguments = @{ Uri = "$root/myown/api$Path"; Method = $Method; Headers = $headers }
    if ($null -ne $Body) {
        $arguments.ContentType = 'application/json'
        $arguments.Body = $Body | ConvertTo-Json -Depth 12 -Compress
    }
    Invoke-RestMethod @arguments
}

function Add-Result {
    param([string]$Id, [string]$Status, [string]$Details)
    $results.Add([ordered]@{ id = $Id; status = $Status; durationMs = 0; details = $Details })
    $color = if ($Status -eq 'pass') { 'Green' } elseif ($Status -eq 'fail') { 'Red' } else { 'Yellow' }
    Write-Host "$($Status.ToUpper())  $Id  $Details" -ForegroundColor $color
}

function Add-Check {
    param([string]$Id, [string]$Details, [scriptblock]$Action)
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $passed = $false
    $failure = ''
    try {
        $passed = [bool](& $Action)
        if (-not $passed) { $failure = 'The returned value did not meet the expected condition.' }
    } catch {
        $failure = $_.Exception.Message
    } finally {
        $watch.Stop()
    }
    $results.Add([ordered]@{
        id = $Id
        status = if ($passed) { 'pass' } else { 'fail' }
        durationMs = [int]$watch.ElapsedMilliseconds
        details = if ($failure) { "$Details $failure" } else { $Details }
    })
    $color = if ($passed) { 'Green' } else { 'Red' }
    $statusLabel = if ($passed) { 'PASS' } else { 'FAIL' }
    $failureSuffix = if ([string]::IsNullOrEmpty($failure)) { '' } else { " $failure" }
    Write-Host "$statusLabel  $Id  $Details$failureSuffix" -ForegroundColor $color
}

$health = Invoke-PortalJson -Method GET -Path '/health'
$status = Invoke-PortalJson -Method GET -Path '/agent/status'
$aiHubAvailable = [bool]$status.data.aiHubAvailable

if (-not $aiHubAvailable) {
    foreach ($id in 'AH-01','AH-02','AH-03','AH-04','AH-05','AH-06') {
        Add-Result -Id $id -Status 'skip' -Details 'The connected IRIS instance does not contain the MyOwn AI Hub engine. Run this suite against build 154.'
    }
} else {
    Add-Check -Id 'AH-01' -Details 'The AI Hub module is installed and selected by the portal.' -Action {
        [bool]$status.data.aiHubAvailable -and $status.data.activeEngine -eq 'aihub'
    }

    $guardrails = Invoke-PortalJson -Method GET -Path '/agent/guardrails'
    Add-Check -Id 'AH-02' -Details 'The portal reports read-only agent tools and human confirmation for state changes.' -Action {
        [bool]$guardrails.data.agentToolsAreReadOnly -and [bool]$guardrails.data.stateChangesRequireConfirmation
    }

    Add-Result -Id 'AH-03' -Status 'skip' -Details 'Tool authorization denial requires build-154 ToolSet introspection and is enabled after the real API signatures are recorded.'

    if ([string]::IsNullOrWhiteSpace($env:MYOWN_AI_API_KEY)) {
        foreach ($id in 'AH-04','AH-05','AH-06') {
            Add-Result -Id $id -Status 'skip' -Details 'Set MYOWN_AI_API_KEY only in the local environment to run provider-dependent AI Hub checks.'
        }
    } else {
        Add-Check -Id 'AH-04' -Details 'A real AI Hub decision is returned with nonzero token usage.' -Action {
            $decision = Invoke-PortalJson -Method POST -Path '/agent/simulate' -Body @{ scenario = 'S1' }
            $ledger = Invoke-PortalJson -Method GET -Path '/agent/ledger/summary'
            $decision.data.engine -eq 'aihub' -and [double]$ledger.data.totalTokens -gt 0
        }
        Add-Result -Id 'AH-05' -Status 'skip' -Details 'Invalid-provider-output repair will be enabled after the build-154 provider test hook is confirmed.'
        Add-Result -Id 'AH-06' -Status 'skip' -Details 'Provider-timeout fallback will be enabled after the build-154 provider configuration API is confirmed.'
    }
}

$pass = @($results | Where-Object status -eq 'pass').Count
$fail = @($results | Where-Object status -eq 'fail').Count
$skip = @($results | Where-Object status -eq 'skip').Count
$report = [ordered]@{
    suite = 'agents-aihub'
    startedAt = $startedAt.ToString('o')
    finishedAt = [DateTimeOffset]::Now.ToString('o')
    iris = [ordered]@{ version = [string]$health.data.version; aiHubAvailable = $aiHubAvailable }
    results = $results
    summary = [ordered]@{ pass = $pass; fail = $fail; skip = $skip }
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $projectRoot $OutputPath }
$outputDirectory = Split-Path -Parent $resolvedOutput
if (-not (Test-Path -LiteralPath $outputDirectory)) { New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null }
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resolvedOutput -Encoding UTF8
Write-Host "Report written to $resolvedOutput" -ForegroundColor Cyan

if ($fail -gt 0) { throw "$fail AI Hub test(s) failed." }
Write-Host "AI Hub suite completed: $pass passed, $skip skipped." -ForegroundColor Green
