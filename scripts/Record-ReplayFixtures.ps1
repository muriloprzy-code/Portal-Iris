[CmdletBinding()]
param(
    [string]$BaseUrl = 'http://localhost:52774',
    [Parameter(Mandatory)]
    [PSCredential]$Credential,
    [string]$Namespace = 'MYOWN',
    # Default: every scenario still pending recording in aihub/fixtures.
    [string[]]$Scenarios,
    [string]$Requester = 'demo.viewer',
    [int]$SpacingSeconds = 15,
    [int]$MaxCalls = 6,
    # Also upload and compile the regenerated MyOwn.AIHub.Fixtures on the instance.
    [switch]$Deploy
)

# Records replay fixtures from real decisions (MyOwn_AIHub.RecordScenario on an instance in
# MYOWN_AI_MODE=live with a key): one real call per scenario, at least SpacingSeconds apart, at
# most MaxCalls, stopping at the first quota error (HTTP 429). A recorded answer replaces
# aihub/fixtures/<scenario>.json with the model, provider and UTC date in its header; then
# Build-ReplayFixtures.ps1 regenerates the class. Failed scenarios stay "pending".

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$fixtureDirectory = Join-Path $root 'aihub\fixtures'
$password = $Credential.GetNetworkCredential().Password
$token = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$($Credential.UserName):$password"))
$headers = @{ Authorization = "Basic $token"; Accept = 'application/json' }
$atelier = "$($BaseUrl.TrimEnd('/'))/api/atelier/v1/$Namespace"

function Invoke-IrisSql {
    param([string]$Query, [object[]]$Parameters = @())
    $body = @{ query = $Query; parameters = $Parameters } | ConvertTo-Json -Compress
    $response = Invoke-RestMethod -Method Post -Uri "$atelier/action/query" -Headers $headers -ContentType 'application/json' -Body $body -TimeoutSec 120
    if ($response.status.errors.Count) { throw "SQL failed: $($response.status.errors | ConvertTo-Json -Compress)" }
    return $response.result.content
}

if (-not $Scenarios) {
    $Scenarios = foreach ($index in 1..10) {
        $fixture = Get-Content -LiteralPath (Join-Path $fixtureDirectory "S$index.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($fixture.status -eq 'pending') { "S$index" }
    }
}
if (-not $Scenarios) { Write-Host 'No scenario is pending recording.' -ForegroundColor Green; return }

$calls = 0
foreach ($scenario in $Scenarios) {
    if ($calls -ge $MaxCalls) { Write-Host "Stopped: $MaxCalls real calls made." -ForegroundColor Yellow; break }
    if ($calls -gt 0) { Start-Sleep -Seconds $SpacingSeconds }
    # Only S2/S3 read the demonstration task through SysAdmin, with the caller's credential.
    $authorization = if ($scenario -in @('S2', 'S3')) { "Basic $token" } else { '' }
    $calls++
    $raw = (Invoke-IrisSql -Query 'SELECT MyOwn_AIHub.RecordScenario(?, ?, 0, ?) AS r' -Parameters @($scenario, $authorization, $Requester))[0].r
    $result = if ($raw -is [string]) { $raw | ConvertFrom-Json } else { $raw }
    if ($result.status -eq 'recorded') {
        # The server already returns the fixture JSON; store it as is (UTF-8 without BOM).
        $text = if ($raw -is [string]) { $raw } else { $raw | ConvertTo-Json -Depth 10 -Compress }
        [IO.File]::WriteAllText((Join-Path $fixtureDirectory "$scenario.json"), $text + "`n", [Text.UTF8Encoding]::new($false))
        Write-Host "RECORDED  $scenario  $($result.provider)/$($result.model) at $($result.recordedAt), $($result.latencyMs) ms" -ForegroundColor Green
    } else {
        $tools = @($result.toolCalls | ForEach-Object { "$($_.name):$($_.status) $($_.summary)" })
        Write-Host "PENDING   $scenario  $($result.reason): $($result.detail)$(if ($tools) { ' | tools: ' + ($tools -join '; ') } else { ' | no tool call' })" -ForegroundColor Yellow
        if ($result.detail -match '429|quota|Rate limit') { Write-Host 'Stopped at the provider quota error.' -ForegroundColor Yellow; break }
        # The provider retries a 429 internally, so a quota error can also surface as a timeout.
        if ($result.reason -in @('provider_timeout', 'provider_error')) { Write-Host "Stopped at a provider failure ($($result.reason))." -ForegroundColor Yellow; break }
        if ($result.reason -in @('not_live', 'no_key', 'budget', 'kill_switch')) { break }
    }
}

& (Join-Path $PSScriptRoot 'Build-ReplayFixtures.ps1')

if ($Deploy) {
    $name = 'MyOwn.AIHub.Fixtures.cls'
    $lines = [IO.File]::ReadAllText((Join-Path $root 'aihub\src\MyOwn\AIHub\Fixtures.cls'), [Text.Encoding]::UTF8) -split "`r?`n"
    $body = @{ enc = $false; content = $lines } | ConvertTo-Json -Depth 3 -Compress
    Invoke-RestMethod -Method Put -Uri "$atelier/doc/${name}?ignoreConflict=1" -Headers $headers -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
    $compile = Invoke-RestMethod -Method Post -Uri "$atelier/action/compile?flags=ck" -Headers $headers -ContentType 'application/json' -Body (ConvertTo-Json -InputObject @($name) -Compress)
    if ($compile.status.errors.Count) { throw "Compile failed: $($compile.status.errors | ConvertTo-Json -Compress)" }
    Write-Host 'MyOwn.AIHub.Fixtures compiled on the instance.' -ForegroundColor Cyan
}
