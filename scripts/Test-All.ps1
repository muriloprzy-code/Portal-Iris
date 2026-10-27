[CmdletBinding()]
param(
    [string]$BaseUrl = 'http://localhost:52774',
    # An administrator of the instance (the suites create and remove their own fixtures).
    [Parameter(Mandatory)]
    [PSCredential]$Credential,
    # Optional: the demo account, for the REST part of the demo suite (needs MYOWN_DEMO_MODE=1).
    [PSCredential]$DemoCredential,
    [string]$Namespace = 'MYOWN',
    [string]$IrisImage = 'irishealth-community:2026.3.0AI.154.0',
    [ValidateSet('iris', 'irisforhealth')]
    [string]$Edition = 'irisforhealth',
    [string]$OutputDirectory = 'test-results/all',
    # Skips the adapter end-to-end check (a real task failing three times; about 3 to 5 minutes).
    [switch]$SkipEndToEnd
)

# Runs every test suite once against one instance, in order, and prints one table:
# suite, result, passed / failed / skipped, seconds. Each suite's console output goes to
# <OutputDirectory>/<suite>.txt and its JSON report next to it. The last row checks that the
# run left no error in the interoperability Event Log. Exit code 1 when anything failed.

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot
$out = if ([IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $projectRoot $OutputDirectory }
New-Item -ItemType Directory -Force -Path $out | Out-Null
$rel = $OutputDirectory.TrimEnd('/', '\')
$root = $BaseUrl.TrimEnd('/')
$token = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$($Credential.UserName):$($Credential.GetNetworkCredential().Password)"))

function Invoke-IrisSql([string]$Query, [object[]]$Parameters = @()) {
    $body = @{ query = $Query; parameters = $Parameters } | ConvertTo-Json -Compress
    $response = Invoke-RestMethod -Method Post -Uri "$root/api/atelier/v1/$Namespace/action/query" -Headers @{ Authorization = "Basic $token" } -ContentType 'application/json' -Body $body -TimeoutSec 120
    if ($response.status.errors.Count) { throw "SQL failed: $($response.status.errors | ConvertTo-Json -Compress)" }
    return $response.result.content
}

$demoArguments = @{}
if ($DemoCredential) { $demoArguments.DemoCredential = $DemoCredential }
$adapterArguments = @{}
if ($SkipEndToEnd) { $adapterArguments.SkipEndToEnd = $true }

# name, script block, JSON reports holding the counts (none: counted from PASS/FAIL/SKIP lines).
$suites = @(
    @{ name = 'Test-MyOwn'; run = { & .\scripts\Test-MyOwn.ps1 -BaseUrl $BaseUrl -Credential $Credential -ExpectedProduct $Edition }; reports = @() }
    @{ name = 'Test-SysAdminMutations'; run = { & .\scripts\Test-SysAdminMutations.ps1 -BaseUrl $BaseUrl -Credential $Credential }; reports = @() }
    @{ name = 'Test-Agents'; run = { & .\scripts\Test-Agents.ps1 -BaseUrl $BaseUrl -Credential $Credential -IrisImage $IrisImage -Edition $Edition -OutputPath "$rel/agents-core.json" }; reports = @('agents-core.json') }
    @{ name = 'Test-AgentAdversarial'; run = { & .\scripts\Test-AgentAdversarial.ps1 -BaseUrl $BaseUrl -Credential $Credential -IrisImage $IrisImage -Edition $Edition -OutputPath "$rel/agents-adversarial.json" }; reports = @('agents-adversarial.json') }
    @{ name = 'Test-AgentSmoke'; run = { & .\scripts\Test-AgentSmoke.ps1 -BaseUrl $BaseUrl -Credential $Credential -IrisImage $IrisImage -Edition $Edition -OutputDirectory $rel }; reports = @('agents-smoke-core.json', 'agents-smoke-integration.json') }
    @{ name = 'Test-Agents-AIHub'; run = { & .\scripts\Test-Agents-AIHub.ps1 -BaseUrl $BaseUrl -Credential $Credential -IrisImage $IrisImage -Edition $Edition -OutputPath "$rel/agents-aihub.json" }; reports = @('agents-aihub.json') }
    @{ name = 'Test-AgentDemo'; run = { & .\scripts\Test-AgentDemo.ps1 -BaseUrl $BaseUrl -Credential $Credential @demoArguments -OutputPath "$rel/agents-demo.json" }; reports = @('agents-demo.json') }
    @{ name = 'Test-PortalViewer'; run = { & .\scripts\Test-PortalViewer.ps1 -BaseUrl $BaseUrl -Credential $Credential -OutputPath "$rel/portal-viewer.json" }; reports = @('portal-viewer.json') }
    @{ name = 'Test-Adapters'; run = { & .\scripts\Test-Adapters.ps1 -BaseUrl $BaseUrl -Credential $Credential @adapterArguments -OutputPath "$rel/adapters.json" }; reports = @('adapters.json') }
    @{ name = 'Test-AgentsUI'; run = { & .\scripts\Test-AgentsUI.ps1 -BaseUrl $BaseUrl -Credential $Credential -OutputPath "$rel/agents-ui.json" -ScreenshotDirectory "$rel/ui" }; reports = @('agents-ui.json') }
    @{ name = 'Test-AgentSecretScan'; run = { & .\scripts\Test-AgentSecretScan.ps1 -OutputPath "$rel/agents-secrets.json" }; reports = @('agents-secrets.json') }
)

$startId = 0
try { $startId = [long](Invoke-IrisSql -Query 'SELECT MAX(ID) AS id FROM Ens_Util.Log')[0].id } catch { }
$rows = [System.Collections.Generic.List[object]]::new()
$runStarted = [DateTimeOffset]::Now
foreach ($suite in $suites) {
    $log = Join-Path $out "$($suite.name).txt"
    foreach ($report in $suite.reports) { Remove-Item -LiteralPath (Join-Path $out $report) -ErrorAction SilentlyContinue }
    Write-Host "Running $($suite.name)..." -ForegroundColor Cyan
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $errorText = ''
    try { & $suite.run *>&1 | Out-String -Width 300 | Set-Content -LiteralPath $log -Encoding UTF8 }
    catch { $errorText = $_.Exception.Message; Add-Content -LiteralPath $log -Value "ERROR: $errorText" }
    $seconds = [int]$watch.Elapsed.TotalSeconds
    $pass = 0; $fail = 0; $skip = 0; $counted = $false
    foreach ($report in $suite.reports) {
        $path = Join-Path $out $report
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $summary = (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json).summary
        if ($null -eq $summary) { continue }
        $pass += [int]$summary.pass; $fail += [int]$summary.fail; $skip += [int]$summary.skip; $counted = $true
    }
    if (-not $counted) {
        $lines = @(Get-Content -LiteralPath $log)
        $pass = @($lines | Where-Object { $_ -match '^\W*PASS\b' }).Count
        $fail = @($lines | Where-Object { $_ -match '^\W*FAIL\b' }).Count
        $skip = @($lines | Where-Object { $_ -match '^\W*SKIP\b' }).Count
    }
    $result = if ($errorText -or $fail -gt 0) { 'FAIL' } else { 'PASS' }
    if ($errorText -and $fail -eq 0) { $fail = 1 }
    $rows.Add([pscustomobject]@{ Suite = $suite.name; Result = $result; Passed = $pass; Failed = $fail; Skipped = $skip; Seconds = $seconds; Error = $errorText })
}

# Errors (and alerts) written to the Event Log of the namespace during this run.
$eventErrors = $null
try {
    $found = Invoke-IrisSql -Query 'SELECT ID, ConfigName, SourceClass, Text FROM Ens_Util.Log WHERE ID > ? AND Type IN (2, 6) ORDER BY ID' -Parameters @($startId)
    $eventErrors = @($found)
} catch { }
$eventLog = Join-Path $out 'Event-Log.txt'
if ($null -eq $eventErrors) {
    Set-Content -LiteralPath $eventLog -Value 'The Event Log could not be read.' -Encoding UTF8
    $rows.Add([pscustomobject]@{ Suite = 'Event Log clean'; Result = 'FAIL'; Passed = 0; Failed = 1; Skipped = 0; Seconds = 0; Error = 'The Event Log could not be read.' })
} else {
    $eventErrors | ForEach-Object { "$($_.ID) $($_.ConfigName) $($_.SourceClass): $($_.Text)" } | Set-Content -LiteralPath $eventLog -Encoding UTF8
    $clean = ($eventErrors.Count -eq 0)
    $rows.Add([pscustomobject]@{ Suite = 'Event Log clean'; Result = $(if ($clean) { 'PASS' } else { 'FAIL' }); Passed = $(if ($clean) { 1 } else { 0 }); Failed = $eventErrors.Count; Skipped = 0; Seconds = 0; Error = $(if ($clean) { '' } else { "$($eventErrors.Count) error(s) logged during the run, see Event-Log.txt" }) })
}

$summary = [ordered]@{
    baseUrl = $BaseUrl; iris = [ordered]@{ image = $IrisImage; edition = $Edition }
    startedAt = $runStarted.ToString('o'); finishedAt = [DateTimeOffset]::Now.ToString('o')
    suites = $rows
    total = [ordered]@{ passed = ($rows | Measure-Object Passed -Sum).Sum; failed = ($rows | Measure-Object Failed -Sum).Sum; skipped = ($rows | Measure-Object Skipped -Sum).Sum }
}
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $out 'test-all.json') -Encoding UTF8

$rows | Format-Table Suite, Result, Passed, Failed, Skipped, Seconds -AutoSize | Out-String -Width 200 | Write-Host
foreach ($row in $rows | Where-Object Result -eq 'FAIL') { Write-Host "FAIL  $($row.Suite): $($row.Error) (log: $rel/$($row.Suite).txt)" -ForegroundColor Red }
$failedSuites = @($rows | Where-Object Result -eq 'FAIL').Count
Write-Host ("Total: {0} passed, {1} failed, {2} skipped; {3} of {4} suites failed. Reports in {5}." -f $summary.total.passed, $summary.total.failed, $summary.total.skipped, $failedSuites, $rows.Count, $rel) -ForegroundColor $(if ($failedSuites) { 'Red' } else { 'Green' })
if ($failedSuites -gt 0) { exit 1 }
exit 0
