[CmdletBinding()]
param(
    [string]$BaseUrl = 'http://localhost:52774',
    # An administrator of the instance (the test procedures create and delete a task in %SYS).
    [Parameter(Mandatory)]
    [PSCredential]$Credential,
    [string]$Namespace = 'MYOWN',
    # Leave the test task and its proposal in place for inspection; remove it later with
    # SELECT MyOwn_Test.TestFailingTaskRemove(<id>).
    [switch]$KeepTask
)

# A real incident, without /agent/simulate: a temporary task of the namespace fails three times
# through the task manager, the TaskWatcher reads it from %SYS_Task.History on its next scan, and
# the event goes TriageProcess -> AgentGateway -> Gate -> ProposalStore. Uses the test procedures
# of MyOwn.Test.Adapter (loaded by the Docker build). With a provider key and engine preference
# "auto", the decision is one real model call. Prints the evidence and removes the task.

$ErrorActionPreference = 'Stop'
$root = $BaseUrl.TrimEnd('/')
$token = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$($Credential.UserName):$($Credential.GetNetworkCredential().Password)"))
$headers = @{ Authorization = "Basic $token"; Accept = 'application/json' }

function Invoke-IrisSql([string]$Query, [object[]]$Parameters = @()) {
    $body = @{ query = $Query; parameters = $Parameters } | ConvertTo-Json -Compress
    $response = Invoke-RestMethod -Method Post -Uri "$root/api/atelier/v1/$Namespace/action/query" -Headers $headers -ContentType 'application/json' -Body $body -TimeoutSec 120
    if ($response.status.errors.Count) { throw "SQL failed: $($response.status.errors | ConvertTo-Json -Compress)" }
    return $response.result.content
}

function Get-TaskState([int]$TaskId) {
    $raw = (Invoke-IrisSql -Query 'SELECT MyOwn_Test.TestFailingTaskState(?) AS r' -Parameters @($TaskId))[0].r
    if ($raw -is [string]) { return $raw | ConvertFrom-Json }
    return $raw
}

$taskId = [int](Invoke-IrisSql -Query 'SELECT MyOwn_Test.TestFailingTaskCreate() AS id')[0].id
if ($taskId -le 0) { throw 'The test task could not be created.' }
Write-Host "Created test task $taskId (class MyOwn.Test.FailingTask, namespace $Namespace)." -ForegroundColor Cyan
try {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    foreach ($run in 1..3) {
        $started = (Invoke-IrisSql -Query 'SELECT MyOwn_Test.TestFailingTaskRun(?) AS r' -Parameters @($taskId))[0].r
        if ($started -ne 'ok') { throw "Run $run could not be scheduled: $started" }
        $deadline = [DateTime]::Now.AddSeconds(150)
        do { Start-Sleep -Seconds 5; $state = Get-TaskState $taskId } until ($state.failures -ge $run -or [DateTime]::Now -gt $deadline)
        if ($state.failures -lt $run) { throw "Run $run did not fail in the task history within 150 s." }
        Write-Host ("Run {0} failed in the task history ({1:N0} s)." -f $run, $watch.Elapsed.TotalSeconds)
    }
    Write-Host 'Waiting for the TaskWatcher scan (every 120 s) and the decision...'
    $deadline = [DateTime]::Now.AddSeconds(360)
    do { Start-Sleep -Seconds 10; $state = Get-TaskState $taskId } until (($state.messages -gt 0 -and $state.decision) -or [DateTime]::Now -gt $deadline)
    if (-not ($state.messages -gt 0 -and $state.decision)) { throw "No decision for task $taskId within 360 s (IncidentEvents from TaskWatcher: $($state.messages))." }
    Write-Host ("Done in {0:N0} s." -f $watch.Elapsed.TotalSeconds) -ForegroundColor Green

    $trace = $state.decision.traceId
    $session = Invoke-IrisSql -Query "SELECT h.SessionId, h.TimeCreated, h.SourceConfigName, h.TargetConfigName, h.MessageBodyClassName FROM Ens.MessageHeader h WHERE h.SessionId = (SELECT MAX(x.SessionId) FROM Ens.MessageHeader x JOIN MyOwn_Production_Msg.IncidentEvent e ON e.ID = x.MessageBodyId WHERE x.SourceConfigName = 'TaskWatcher' AND e.TraceId = ?) ORDER BY h.ID" -Parameters @($trace)
    $ledger = Invoke-IrisSql -Query 'SELECT Engine, Model, TotalTokens, DurationMs, Outcome FROM MyOwn_Agent.Ledger WHERE TraceId = ?' -Parameters @($trace)

    Write-Host "`nIncidentEvent from TaskWatcher: $($state.messages) message(s) for task $taskId; the adapter hands it on with $($state.adapter.failures) failures."
    Write-Host "Decision: engine $($state.decision.engine), action $($state.decision.action), event source $($state.decision.eventSource), trace $trace"
    if ($state.proposal) { Write-Host "Proposal: #$($state.proposal.id) $($state.proposal.kind) ($($state.proposal.state))" } else { Write-Host 'Proposal: none' }
    $ledger | ForEach-Object { Write-Host "Ledger: $($_.Engine) $($_.Model), $($_.TotalTokens) tokens, $($_.DurationMs) ms, $($_.Outcome)" }
    Write-Host "`nVisual Trace (session $(@($session)[0].SessionId)):"
    $session | ForEach-Object { Write-Host ("  {0}  {1} -> {2}  {3}" -f $_.TimeCreated, $_.SourceConfigName, $_.TargetConfigName, $_.MessageBodyClassName) }
} finally {
    if ($KeepTask) {
        Write-Host "`nTest task $taskId kept. Remove it with: SELECT MyOwn_Test.TestFailingTaskRemove($taskId)" -ForegroundColor Yellow
    } else {
        $removed = (Invoke-IrisSql -Query 'SELECT MyOwn_Test.TestFailingTaskRemove(?) AS r' -Parameters @($taskId))[0].r
        Write-Host "`nTest task $taskId removed (pending proposals rejected): $removed" -ForegroundColor Cyan
    }
}
