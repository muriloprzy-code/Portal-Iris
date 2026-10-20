[CmdletBinding()]
param(
    [string]$BaseUrl = 'http://localhost:52774',
    [Parameter(Mandatory)]
    [PSCredential]$Credential,
    [string]$Namespace = 'MYOWN',
    [string]$IrisImage = 'unknown',
    [ValidateSet('iris', 'irisforhealth', 'unknown')]
    [string]$Edition = 'unknown',
    [string]$OutputDirectory = 'test-results'
)

# Runs the in-IRIS agent smoke suites (MyOwn_Test.AgentCoreSmoke and
# MyOwn_Test.AgentIntegrationSmoke) through the Atelier SQL endpoint and
# writes one JSON report per suite.

$ErrorActionPreference = 'Stop'
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

$resolvedDirectory = if ([IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path (Split-Path -Parent $PSScriptRoot) $OutputDirectory }
if (-not (Test-Path -LiteralPath $resolvedDirectory)) { New-Item -ItemType Directory -Path $resolvedDirectory -Force | Out-Null }

$version = [string](Invoke-IrisSql -Query 'SELECT $ZVERSION AS v').v
$suites = @(
    @{ Method = 'AgentCoreSmoke'; File = 'agents-smoke-core.json' },
    @{ Method = 'AgentIntegrationSmoke'; File = 'agents-smoke-integration.json' }
)
$totalFail = 0

foreach ($suite in $suites) {
    $startedAt = [DateTimeOffset]::Now
    $raw = (Invoke-IrisSql -Query "SELECT MyOwn_Test.$($suite.Method)() AS r").r
    $data = if ($raw -is [string]) { $raw | ConvertFrom-Json } else { $raw }
    $pass = [int]$data.summary.pass
    $fail = [int]$data.summary.fail
    $totalFail += $fail

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
        engine = 'rules'
        source = "SELECT MyOwn_Test.$($suite.Method)()"
        results = $data.results
        summary = [ordered]@{ pass = $pass; fail = $fail; skip = 0 }
    }
    $output = Join-Path $resolvedDirectory $suite.File
    $report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $output -Encoding UTF8

    foreach ($result in $data.results) {
        $color = if ($result.status -eq 'pass') { 'Green' } else { 'Red' }
        Write-Host ("{0,-5} {1}  {2}" -f $result.status.ToUpper(), $result.id, $result.details) -ForegroundColor $color
    }
    Write-Host "$($data.suite): $pass passed, $fail failed. Report written to $output" -ForegroundColor Cyan
}

if ($totalFail -gt 0) { throw "$totalFail agent smoke test(s) failed." }
Write-Host 'All agent smoke tests passed.' -ForegroundColor Green
