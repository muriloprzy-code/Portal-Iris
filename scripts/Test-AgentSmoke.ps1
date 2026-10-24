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
    param([string]$Query, [object[]]$Parameters = @())
    $body = @{ query = $Query; parameters = $Parameters } | ConvertTo-Json -Compress
    $response = Invoke-RestMethod -Method Post -Uri $queryUri -Headers $headers -ContentType 'application/json' -Body $body
    if ($response.status.errors.Count) { throw "SQL failed: $($response.status.errors | ConvertTo-Json -Compress)" }
    return $response.result.content[0]
}

# Checks returned as "pending" (audit records appear only after IRIS flushes its audit buffer)
# are resolved here with short polls, so no single request has to outlast the 60 s web gateway.
function Resolve-PendingChecks {
    param([object[]]$Results, [int]$TimeoutSeconds = 120, [int]$IntervalSeconds = 2)
    foreach ($item in @($Results | Where-Object { $_.status -eq 'pending' })) {
        $started = Get-Date
        while ($true) {
            $arguments = @($item.poll.args)
            $placeholders = ($arguments | ForEach-Object { '?' }) -join ', '
            $raw = (Invoke-IrisSql -Query "SELECT $($item.poll.proc)($placeholders) AS r" -Parameters $arguments).r
            $check = if ($raw -is [string]) { $raw | ConvertFrom-Json } else { $raw }
            $elapsed = [int]((Get-Date) - $started).TotalSeconds
            if ($check.done) {
                $item.status = if ($check.pass) { 'pass' } else { 'fail' }
                $item.details = "$($item.details) (audit record visible $elapsed s after the suite returned)"
                break
            }
            if ($elapsed -ge $TimeoutSeconds) {
                $item.status = 'fail'
                $item.details = "$($item.details) Audit record not visible after $TimeoutSeconds s."
                break
            }
            Start-Sleep -Seconds $IntervalSeconds
        }
    }
}

$resolvedDirectory = if ([IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path (Split-Path -Parent $PSScriptRoot) $OutputDirectory }
if (-not (Test-Path -LiteralPath $resolvedDirectory)) { New-Item -ItemType Directory -Path $resolvedDirectory -Force | Out-Null }

$version = [string](Invoke-IrisSql -Query 'SELECT $ZVERSION AS v').v
$suites = @(
    @{ Method = 'AgentCoreSmoke'; File = 'agents-smoke-core.json' },
    @{ Method = 'AgentIntegrationSmoke'; Arguments = '0'; File = 'agents-smoke-integration.json' }
)
$totalFail = 0

foreach ($suite in $suites) {
    $startedAt = [DateTimeOffset]::Now
    $request = [Diagnostics.Stopwatch]::StartNew()
    $raw = (Invoke-IrisSql -Query "SELECT MyOwn_Test.$($suite.Method)($($suite.Arguments)) AS r").r
    $request.Stop()
    $data = if ($raw -is [string]) { $raw | ConvertFrom-Json } else { $raw }
    Resolve-PendingChecks -Results $data.results
    $pass = @($data.results | Where-Object status -eq 'pass').Count
    $fail = @($data.results | Where-Object status -ne 'pass').Count
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
        source = "SELECT MyOwn_Test.$($suite.Method)($($suite.Arguments))"
        # Duration of the suite request itself (must stay well under the 60 s web gateway limit).
        requestMs = [int]$request.ElapsedMilliseconds
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
