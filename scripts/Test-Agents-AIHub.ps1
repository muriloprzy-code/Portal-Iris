[CmdletBinding()]
param(
    [string]$BaseUrl = 'http://localhost:52774',
    [Parameter(Mandatory)]
    [PSCredential]$Credential,
    [string]$Namespace = 'MYOWN',
    [string]$IrisImage = 'unknown',
    [ValidateSet('iris', 'irisforhealth', 'unknown')]
    [string]$Edition = 'unknown',
    [string]$OutputPath = 'test-results/agents-aihub.json',
    # Opt-in real provider calls through the portal (needs MYOWN_AI_MODE=live and a key in the
    # container environment). Calls are sequential, 15 s apart, and stop at the first HTTP 429.
    [switch]$Live,
    [string[]]$LiveScenarios = @('S2'),
    [int]$LiveSpacingSeconds = 15
)

# AI Hub engine suite. Always: MyOwn_AIHub_Test.AIHubEngineSmoke() in replay mode (no key, no
# network): valid and invalid JSON, timeout, provider error, budget, kill switch, write tool
# blocked by the policy, allow-list and delimiters. With -Live: real decisions through
# POST /agent/simulate, reporting engine, fallback reason, tokens and latency from the ledger.
# On an instance without the %AI package (or without the module) every check is skipped.

$ErrorActionPreference = 'Stop'
$startedAt = [DateTimeOffset]::Now
$root = $BaseUrl.TrimEnd('/')
$password = $Credential.GetNetworkCredential().Password
$token = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$($Credential.UserName):$password"))
$headers = @{ Authorization = "Basic $token"; 'X-MyOwn-SysAdmin-Authorization' = "Basic $token"; Accept = 'application/json' }
$queryUri = "$root/api/atelier/v1/$Namespace/action/query"
$results = [System.Collections.Generic.List[object]]::new()

function Invoke-PortalJson {
    param([string]$Method, [string]$Path, [object]$Body)
    $arguments = @{ Uri = "$root/myown/api$Path"; Method = $Method; Headers = $headers; TimeoutSec = 90 }
    if ($null -ne $Body) {
        $arguments.ContentType = 'application/json'
        $arguments.Body = $Body | ConvertTo-Json -Depth 12 -Compress
    }
    Invoke-RestMethod @arguments
}

function Invoke-IrisSql {
    param([string]$Query, [object[]]$Parameters = @())
    $body = @{ query = $Query; parameters = $Parameters } | ConvertTo-Json -Compress
    $response = Invoke-RestMethod -Method Post -Uri $queryUri -Headers $headers -ContentType 'application/json' -Body $body -TimeoutSec 300
    if ($response.status.errors.Count) { throw "SQL failed: $($response.status.errors | ConvertTo-Json -Compress)" }
    return $response.result.content
}

function Add-Result {
    param([string]$Id, [string]$Status, [string]$Details, [object]$Data = $null)
    $item = [ordered]@{ id = $Id; status = $Status; details = $Details }
    if ($null -ne $Data) { $item.data = $Data }
    $results.Add($item)
    $color = if ($Status -eq 'pass') { 'Green' } elseif ($Status -eq 'fail') { 'Red' } else { 'Yellow' }
    Write-Host ("{0,-5} {1}  {2}" -f $Status.ToUpper(), $Id, $Details) -ForegroundColor $color
}

$version = [string](Invoke-IrisSql -Query 'SELECT $ZVERSION AS v')[0].v
$config = (Invoke-PortalJson -Method GET -Path '/agent/config').data
$installed = [bool][int]$config.aiHubInstalled

if (-not $installed) {
    Add-Result -Id 'AH-ENGINE' -Status 'skip' -Details 'The MyOwn AI Hub module is not installed here (it needs the %AI package of build 154); Rules decide.'
} else {
    Add-Result -Id 'AH-00-CONFIG' -Status $(if ($config.aiConfigSource -eq 'environment') { 'pass' } else { 'fail' }) -Details "Provider settings come from the environment: provider '$($config.provider)', model '$($config.model)', mode $($config.aiMode), timeout $($config.aiTimeoutSeconds) s, key configured: $([bool][int]$config.apiKeyConfigured)."

    $raw = (Invoke-IrisSql -Query 'SELECT MyOwn_AIHub_Test.AIHubEngineSmoke() AS r')[0].r
    $smoke = if ($raw -is [string]) { $raw | ConvertFrom-Json } else { $raw }
    if ($smoke.error) { Add-Result -Id 'AH-SMOKE' -Status 'fail' -Details $smoke.error }
    foreach ($item in $smoke.results) { Add-Result -Id $item.id -Status $item.status -Details $item.details }

    if ($Live) {
        if ($config.aiMode -ne 'live' -or -not [bool][int]$config.apiKeyConfigured) {
            Add-Result -Id 'AH-LIVE' -Status 'skip' -Details 'Live calls need MYOWN_AI_MODE=live and a key in the container environment.'
        } else {
            $first = $true
            foreach ($scenario in $LiveScenarios) {
                if (-not $first) { Start-Sleep -Seconds $LiveSpacingSeconds }
                $first = $false
                try {
                    $watch = [Diagnostics.Stopwatch]::StartNew()
                    $simulation = (Invoke-PortalJson -Method POST -Path '/agent/simulate' -Body @{ scenario = $scenario }).data
                    $watch.Stop()
                    $ledger = Invoke-IrisSql -Query "SELECT Engine, Provider, Model, DurationMs, PromptTokens, CompletionTokens, TotalTokens, Iterations, ToolCallCount, CostEstimateUSD, Outcome, ErrorSummary FROM MyOwn_Agent.Ledger WHERE TraceId = ? AND Engine = 'aihub'" -Parameters @($simulation.traceId)
                    $row = @($ledger)[0]
                    $data = [ordered]@{ scenario = $scenario; engine = $simulation.engine; fallbackReason = $simulation.fallbackReason; action = $simulation.decision.action; httpMs = [int]$watch.ElapsedMilliseconds; ledger = $row }
                    $status = if ($simulation.engine -eq 'aihub' -and $row) { 'pass' } else { 'fail' }
                    Add-Result -Id "AH-LIVE-$scenario" -Status $status -Details "engine $($simulation.engine)$(if ($simulation.fallbackReason) { " ($($simulation.fallbackReason))" }), action $($simulation.decision.action), provider latency $($row.DurationMs) ms, HTTP $([int]$watch.ElapsedMilliseconds) ms, tokens $($row.PromptTokens)/$($row.CompletionTokens)/$($row.TotalTokens)." -Data $data
                } catch {
                    $message = $_.Exception.Message
                    Add-Result -Id "AH-LIVE-$scenario" -Status 'fail' -Details "The live call failed: $message"
                    if ($message -match '429') { break }
                }
            }
        }
    }
}

$pass = @($results | Where-Object status -eq 'pass').Count
$fail = @($results | Where-Object status -eq 'fail').Count
$skip = @($results | Where-Object status -eq 'skip').Count
$report = [ordered]@{
    suite = 'agents-aihub'
    startedAt = $startedAt.ToString('o')
    finishedAt = [DateTimeOffset]::Now.ToString('o')
    iris = [ordered]@{ version = $version; image = $IrisImage; edition = $Edition; namespace = $Namespace; aiHubInstalled = $installed }
    source = 'SELECT MyOwn_AIHub_Test.AIHubEngineSmoke()' + $(if ($Live) { ' and POST /agent/simulate (live)' } else { '' })
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
