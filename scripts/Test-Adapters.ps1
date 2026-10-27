[CmdletBinding()]
param(
    [string]$BaseUrl = 'http://localhost:52774',
    [Parameter(Mandatory)]
    [PSCredential]$Credential,
    [string]$Namespace = 'MYOWN',
    [string]$OutputPath = 'test-results/adapters.json',
    # Skips the end-to-end check (about 4 to 6 minutes: the task manager and the TaskWatcher poll).
    [switch]$SkipEndToEnd
)

# Inbound adapter tests. AD-01..07 run the adapters without a production (MyOwn_Test.AdapterSmoke).
# AD-E2E drives the running production: a temporary task of the namespace fails three times
# through the task manager, the TaskWatcher (through its adapter) hands it to the triage, and a
# pending task.suspend proposal appears for it. The task and its proposal are removed at the end.

$ErrorActionPreference = 'Stop'
$startedAt = [DateTimeOffset]::Now
$root = $BaseUrl.TrimEnd('/')
$results = [System.Collections.Generic.List[object]]::new()
$token = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$($Credential.UserName):$($Credential.GetNetworkCredential().Password)"))
$headers = @{ Authorization = "Basic $token"; Accept = 'application/json' }

function Invoke-IrisSql([string]$Query, [object[]]$Parameters = @()) {
    $body = @{ query = $Query; parameters = $Parameters } | ConvertTo-Json -Compress
    $response = Invoke-RestMethod -Method Post -Uri "$root/api/atelier/v1/$Namespace/action/query" -Headers $headers -ContentType 'application/json' -Body $body -TimeoutSec 120
    if ($response.status.errors.Count) { throw "SQL failed: $($response.status.errors | ConvertTo-Json -Compress)" }
    return $response.result.content
}

function Add-Result([string]$Id, [string]$Status, [string]$Details) {
    $results.Add([ordered]@{ id = $Id; status = $Status; details = $Details })
    $color = switch ($Status) { 'pass' { 'Green' } 'skip' { 'Yellow' } default { 'Red' } }
    Write-Host ("{0,-5} {1}  {2}" -f $Status.ToUpper(), $Id, $Details) -ForegroundColor $color
}

function Get-TaskState([int]$TaskId) {
    $raw = (Invoke-IrisSql -Query 'SELECT MyOwn_Test.TestFailingTaskState(?) AS r' -Parameters @($TaskId))[0].r
    if ($raw -is [string]) { return $raw | ConvertFrom-Json }
    return $raw
}

$smoke = (Invoke-IrisSql -Query 'SELECT MyOwn_Test.AdapterSmoke() AS r')[0].r
if ($smoke -is [string]) { $smoke = $smoke | ConvertFrom-Json }
foreach ($item in $smoke.results) { Add-Result $item.id $item.status $item.details }

if ($SkipEndToEnd) {
    Add-Result 'AD-E2E' 'skip' 'End-to-end check skipped (-SkipEndToEnd).'
} else {
    $taskId = [int](Invoke-IrisSql -Query 'SELECT MyOwn_Test.TestFailingTaskCreate() AS id')[0].id
    try {
        if ($taskId -le 0) { throw 'The temporary failing task could not be created.' }
        $watch = [Diagnostics.Stopwatch]::StartNew()
        foreach ($run in 1..3) {
            $started = (Invoke-IrisSql -Query 'SELECT MyOwn_Test.TestFailingTaskRun(?) AS r' -Parameters @($taskId))[0].r
            if ($started -ne 'ok') { throw "Run $run could not be scheduled: $started" }
            # The task manager picks up a RunNow within about 60 s.
            $deadline = [DateTime]::Now.AddSeconds(150)
            do { Start-Sleep -Seconds 5; $state = Get-TaskState $taskId } until ($state.failures -ge $run -or [DateTime]::Now -gt $deadline)
            if ($state.failures -lt $run) { throw "Run $run did not fail in the task history within 150 s." }
        }
        $failedAt = $watch.Elapsed.TotalSeconds
        # The TaskWatcher polls every CallInterval (120 s); then triage, Gate and proposal.
        $deadline = [DateTime]::Now.AddSeconds(300)
        do { Start-Sleep -Seconds 10; $state = Get-TaskState $taskId } until (($state.messages -gt 0 -and $state.proposal) -or [DateTime]::Now -gt $deadline)
        $passed = ($state.failures -ge 3) -and ($state.adapter.handedOn -eq 1) -and ($state.adapter.failures -ge 3) -and ($state.messages -gt 0) -and ($state.proposal.kind -eq 'task.suspend') -and ($state.proposal.state -eq 'pending') -and ($state.decision.action -eq 'propose_task_suspend')
        Add-Result 'AD-E2E' $(if ($passed) { 'pass' } else { 'fail' }) ("Task $taskId failed $($state.failures) times (task history, $([int]$failedAt) s); the adapter hands it on with $($state.adapter.failures) failures; TaskWatcher sent $($state.messages) IncidentEvent(s); decision $($state.decision.action) by $($state.decision.engine) (event source $($state.decision.eventSource)); proposal $($state.proposal.id) $($state.proposal.kind) $($state.proposal.state), after $([int]$watch.Elapsed.TotalSeconds) s.")
    } catch {
        Add-Result 'AD-E2E' 'fail' $_.Exception.Message
    } finally {
        if ($taskId -gt 0) {
            $removed = (Invoke-IrisSql -Query 'SELECT MyOwn_Test.TestFailingTaskRemove(?) AS r' -Parameters @($taskId))[0].r
            if ($removed -ne 'ok') { Write-Host "The temporary task $taskId was not removed: $removed" -ForegroundColor Yellow }
        }
    }
}

$pass = @($results | Where-Object status -eq 'pass').Count
$fail = @($results | Where-Object status -eq 'fail').Count
$skip = @($results | Where-Object status -eq 'skip').Count
$report = [ordered]@{ suite = 'adapters'; startedAt = $startedAt.ToString('o'); finishedAt = [DateTimeOffset]::Now.ToString('o'); results = $results; summary = [ordered]@{ pass = $pass; fail = $fail; skip = $skip } }
$projectRoot = Split-Path -Parent $PSScriptRoot
$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $projectRoot $OutputPath }
$directory = Split-Path -Parent $resolvedOutput
if (-not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resolvedOutput -Encoding UTF8
Write-Host "Report written to $resolvedOutput" -ForegroundColor Cyan
if ($fail -gt 0) { throw "$fail adapter test(s) failed." }
Write-Host "Adapter suite completed: $pass passed, $skip skipped." -ForegroundColor Green
