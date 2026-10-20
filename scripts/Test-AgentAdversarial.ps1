[CmdletBinding()]
param(
    [string]$BaseUrl = 'http://localhost:52774',
    [Parameter(Mandatory)]
    [PSCredential]$Credential,
    [string]$Namespace = 'MYOWN',
    [string]$IrisImage = 'unknown',
    [ValidateSet('iris', 'irisforhealth', 'unknown')]
    [string]$Edition = 'unknown',
    [string]$OutputPath = 'test-results/agents-adversarial.json'
)

# Runs the adversarial corpus (MyOwn_Test.AgentAdversarialSmoke) against the
# Validator, Gate and Sanitize through the Atelier SQL endpoint. The corpus uses
# canned model responses only: no engine, network call or persisted proposal.

$ErrorActionPreference = 'Stop'
$startedAt = [DateTimeOffset]::Now
$password = $Credential.GetNetworkCredential().Password
$token = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$($Credential.UserName):$password"))
$headers = @{ Authorization = "Basic $token"; Accept = 'application/json' }
$queryUri = "$($BaseUrl.TrimEnd('/'))/api/atelier/v1/$Namespace/action/query"

function Invoke-IrisSql {
    param([string]$Query)
    $body = @{ query = $Query } | ConvertTo-Json -Compress
    $response = Invoke-RestMethod -Method Post -Uri $queryUri -Headers $headers -ContentType 'application/json' -Body $body
    if ($response.status.errors.Count) { throw "SQL failed: $($response.status.errors | ConvertTo-Json -Compress)" }
    return $response.result.content[0]
}

$version = [string](Invoke-IrisSql -Query 'SELECT $ZVERSION AS v').v
$raw = (Invoke-IrisSql -Query 'SELECT MyOwn_Test.AgentAdversarialSmoke() AS r').r
$data = if ($raw -is [string]) { $raw | ConvertFrom-Json } else { $raw }
$pass = [int]$data.summary.pass
$fail = [int]$data.summary.fail

$categories = [ordered]@{}
foreach ($result in $data.results) {
    if (-not $categories.Contains($result.category)) { $categories[$result.category] = [ordered]@{ pass = 0; fail = 0 } }
    $categories[$result.category][$result.status] += 1
    $color = if ($result.status -eq 'pass') { 'Green' } else { 'Red' }
    Write-Host ("{0,-5} {1,-18} {2}" -f $result.status.ToUpper(), $result.id, $result.details) -ForegroundColor $color
    if ($result.status -ne 'pass') { Write-Host "      expected: $($result.expected)`n      observed: $($result.observed)" -ForegroundColor Red }
}

$report = [ordered]@{
    suite = [string]$data.suite
    startedAt = $startedAt.ToString('o')
    finishedAt = [DateTimeOffset]::Now.ToString('o')
    iris = [ordered]@{
        version = $version
        image = $IrisImage
        edition = $Edition
        namespace = $Namespace
    }
    engine = 'canned-responses'
    source = 'SELECT MyOwn_Test.AgentAdversarialSmoke()'
    results = $data.results
    categories = $categories
    summary = [ordered]@{ total = $pass + $fail; pass = $pass; fail = $fail; skip = 0 }
}

$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path (Split-Path -Parent $PSScriptRoot) $OutputPath }
$outputDirectory = Split-Path -Parent $resolvedOutput
if (-not (Test-Path -LiteralPath $outputDirectory)) { New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null }
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resolvedOutput -Encoding UTF8
Write-Host "Report written to $resolvedOutput" -ForegroundColor Cyan

if ($fail -gt 0) { throw "$fail of $($pass + $fail) adversarial case(s) failed." }
Write-Host "All $pass adversarial cases passed." -ForegroundColor Green
