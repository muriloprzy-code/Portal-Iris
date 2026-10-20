[CmdletBinding()]
param(
    [string]$BaseUrl = 'http://localhost:52774',
    [Parameter(Mandatory)]
    [PSCredential]$Credential,
    [PSCredential]$ViewerCredential,
    [string]$IrisImage = 'unknown',
    [ValidateSet('iris', 'irisforhealth', 'unknown')]
    [string]$Edition = 'unknown',
    [string]$OutputPath = 'test-results/agents-core.json'
)

$ErrorActionPreference = 'Stop'
$startedAt = [DateTimeOffset]::Now
$root = $BaseUrl.TrimEnd('/')
$password = $Credential.GetNetworkCredential().Password
$token = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$($Credential.UserName):$password"))
$headers = @{
    Authorization = "Basic $token"
    'X-MyOwn-SysAdmin-Authorization' = "Basic $token"
    Accept = 'application/json'
}
$results = [System.Collections.Generic.List[object]]::new()
$capturedPayloads = [System.Collections.Generic.List[string]]::new()
$originalConfig = $null
$originalTaskSuspended = $null
$demoTaskId = $null

function Invoke-PortalJson {
    param([string]$Method, [string]$Path, [object]$Body, [hashtable]$RequestHeaders = $headers)
    $arguments = @{ Uri = "$root/myown/api$Path"; Method = $Method; Headers = $RequestHeaders }
    if ($null -ne $Body) {
        $arguments.ContentType = 'application/json'
        $arguments.Body = $Body | ConvertTo-Json -Depth 12 -Compress
    }
    $response = Invoke-RestMethod @arguments
    Add-CapturedPayload -Value $response
    return $response
}

function Invoke-PortalError {
    param([string]$Method, [string]$Path, [object]$Body, [hashtable]$RequestHeaders = $headers)
    try {
        Invoke-PortalJson -Method $Method -Path $Path -Body $Body -RequestHeaders $RequestHeaders | Out-Null
        return [pscustomobject]@{ StatusCode = 200; Code = ''; Message = '' }
    } catch {
        $statusCode = 0
        $payload = $null
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            try {
                if ($_.ErrorDetails.Message) {
                    $payload = $_.ErrorDetails.Message | ConvertFrom-Json
                } elseif ($_.Exception.Response.Content) {
                    $payload = $_.Exception.Response.Content.ReadAsStringAsync().GetAwaiter().GetResult() | ConvertFrom-Json
                } else {
                    $stream = $_.Exception.Response.GetResponseStream()
                    $reader = [IO.StreamReader]::new($stream)
                    $payload = $reader.ReadToEnd() | ConvertFrom-Json
                }
            } catch { $payload = $null }
        }
        return [pscustomobject]@{
            StatusCode = $statusCode
            Code = if ($payload) { [string]$payload.error.code } else { '' }
            Message = if ($payload) { [string]$payload.error.message } else { $_.Exception.Message }
        }
    }
}

function New-PortalHeaders {
    param([PSCredential]$ForCredential)
    $plainPassword = $ForCredential.GetNetworkCredential().Password
    $basicToken = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$($ForCredential.UserName):$plainPassword"))
    return @{
        Authorization = "Basic $basicToken"
        'X-MyOwn-SysAdmin-Authorization' = "Basic $basicToken"
        Accept = 'application/json'
    }
}

function Add-CapturedPayload {
    param([object]$Value)
    if ($null -ne $Value) {
        $capturedPayloads.Add(($Value | ConvertTo-Json -Depth 20 -Compress))
    }
}

function Wait-TaskSuspendedState {
    param([int]$Id, [bool]$Expected)
    for ($attempt = 0; $attempt -lt 25; $attempt++) {
        $detail = Invoke-PortalJson -Method GET -Path "/tasks/detail?id=$Id"
        if (([int]$detail.data.suspended -eq 1) -eq $Expected) { return $true }
        Start-Sleep -Milliseconds 200
    }
    return $false
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
    $status = if ($passed) { 'pass' } else { 'fail' }
    $resultDetails = if ($failure) { "$Details $failure" } else { $Details }
    $results.Add([ordered]@{
        id = $Id
        status = $status
        durationMs = [int]$watch.ElapsedMilliseconds
        details = $resultDetails
    })
    $color = if ($passed) { 'Green' } else { 'Red' }
    Write-Host "$($status.ToUpper())  $Id  $resultDetails" -ForegroundColor $color
}

function Add-Skip {
    param([string]$Id, [string]$Details)
    $results.Add([ordered]@{
        id = $Id
        status = 'skip'
        durationMs = 0
        details = $Details
    })
    Write-Host "SKIP  $Id  $Details" -ForegroundColor Yellow
}

try {
    $viewerHeaders = if ($null -ne $ViewerCredential) { New-PortalHeaders -ForCredential $ViewerCredential } else { $null }

    Add-Check -Id 'IT-01' -Details 'The agent production is running with all ten configured items.' -Action {
        $script:production = Invoke-PortalJson -Method GET -Path '/agent/production/status'
        [bool]$production.data.running -and @($production.data.items).Count -eq 10
    }

    Add-Check -Id 'SEC-09' -Details 'Simulation is rejected while DemoMode is disabled.' -Action {
        $script:originalConfig = (Invoke-PortalJson -Method GET -Path '/agent/config').data
        Invoke-PortalJson -Method PUT -Path '/agent/config' -Body @{
            demoMode = $false
            enginePreference = 'rules'
            readOnly = $originalConfig.readOnly
        } | Out-Null
        $errorResult = Invoke-PortalError -Method POST -Path '/agent/simulate' -Body @{ scenario = 'S1' }
        $errorResult.StatusCode -eq 403 -and $errorResult.Code -eq 'AGENT_DISABLED'
    }

    Invoke-PortalJson -Method PUT -Path '/agent/config' -Body @{
        demoMode = $true
        enginePreference = 'rules'
        readOnly = $false
        cooldownMinutes = 15
    } | Out-Null
    Invoke-PortalJson -Method POST -Path '/agent/killswitch' -Body @{ enabled = $false } | Out-Null

    $tasks = Invoke-PortalJson -Method GET -Path '/tasks'
    $demoTask = @($tasks.data.tasks | Where-Object name -eq 'MyOwn Portal health snapshot' | Select-Object -First 1)
    if ($demoTask.Count -ne 1) { throw 'The MyOwn Portal health snapshot task is required for S2 and S3.' }
    $script:demoTaskId = [int]$demoTask[0].id
    $script:originalTaskSuspended = ([int]$demoTask[0].suspended -eq 1)
    if ($originalTaskSuspended) {
        Invoke-PortalJson -Method POST -Path '/tasks/action' -Body @{ id = $demoTaskId; action = 'resume' } | Out-Null
        if (-not (Wait-TaskSuspendedState -Id $demoTaskId -Expected $false)) { throw 'The demonstration task could not be resumed before the scenario suite.' }
    }

    Add-Check -Id 'IT-02' -Details 'Scenario S1 traverses the production and returns a Rules decision.' -Action {
        $script:s1 = Invoke-PortalJson -Method POST -Path '/agent/simulate' -Body @{ scenario = 'S1' }
        $s1.data.engine -eq 'rules' -and $s1.data.decision.action -eq 'notify' -and $s1.data.integrationSource -eq 'interoperability'
    }

    Add-Check -Id 'IT-02-TRACE' -Details 'The S1 trace contains event, decision, and ledger entries.' -Action {
        $encodedTrace = [Uri]::EscapeDataString([string]$s1.data.traceId)
        $script:trace = Invoke-PortalJson -Method GET -Path "/agent/traces/$encodedTrace"
        @($trace.data.timeline).Count -ge 3
    }

    Add-Check -Id 'IT-03-S2' -Details 'Scenario S2 creates a task-suspension proposal and confirmation changes the real task.' -Action {
        $script:s2 = Invoke-PortalJson -Method POST -Path '/agent/simulate' -Body @{ scenario = 'S2'; taskId = $demoTaskId }
        if ($s2.data.decision.action -ne 'propose_task_suspend' -or -not $s2.data.proposalId) { return $false }
        $script:s2Confirmation = Invoke-PortalJson -Method POST -Path "/agent/proposals/$($s2.data.proposalId)/confirm" -Body $null
        $s2Confirmation.data.state -eq 'executed' -and (Wait-TaskSuspendedState -Id $demoTaskId -Expected $true)
    }

    Add-Check -Id 'IT-04' -Details 'An executed proposal cannot be confirmed a second time.' -Action {
        $repeatError = Invoke-PortalError -Method POST -Path "/agent/proposals/$($s2.data.proposalId)/confirm" -Body $null
        $repeatError.StatusCode -eq 409 -and $repeatError.Code -eq 'PROPOSAL_ALREADY_RESOLVED'
    }

    Add-Check -Id 'S3' -Details 'Scenario S3 proposes resuming a recovered suspended task and confirmation restores it.' -Action {
        $script:s3 = Invoke-PortalJson -Method POST -Path '/agent/simulate' -Body @{ scenario = 'S3'; taskId = $demoTaskId }
        if ($s3.data.decision.action -ne 'propose_task_resume' -or -not $s3.data.proposalId) { return $false }
        $script:s3Confirmation = Invoke-PortalJson -Method POST -Path "/agent/proposals/$($s3.data.proposalId)/confirm" -Body $null
        $s3Confirmation.data.state -eq 'executed' -and (Wait-TaskSuspendedState -Id $demoTaskId -Expected $false)
    }

    Add-Check -Id 'S4' -Details 'Scenario S4 ignores a lock spike when there is not enough statistical evidence.' -Action {
        $script:s4 = Invoke-PortalJson -Method POST -Path '/agent/simulate' -Body @{ scenario = 'S4' }
        $s4.data.decision.action -eq 'ignore' -and -not $s4.data.proposalId
    }

    Add-Check -Id 'S5' -Details 'Scenario S5 creates a low-risk role-assignment proposal.' -Action {
        $script:s5 = Invoke-PortalJson -Method POST -Path '/agent/simulate' -Body @{ scenario = 'S5' }
        $s5.data.decision.action -eq 'approve' -and $s5.data.decision.riskLevel -eq 'low' -and [bool]$s5.data.proposalId
    }

    Add-Check -Id 'S6' -Details 'Scenario S6 escalates a high-risk access request without creating a proposal.' -Action {
        $script:s6 = Invoke-PortalJson -Method POST -Path '/agent/simulate' -Body @{ scenario = 'S6' }
        $s6.data.decision.action -eq 'escalate' -and $s6.data.decision.riskLevel -eq 'high' -and -not $s6.data.proposalId
    }

    Add-Check -Id 'IT-07-S7' -Details 'Scenario S7 blocks the protected %All role without creating a proposal.' -Action {
        $script:s7 = Invoke-PortalJson -Method POST -Path '/agent/simulate' -Body @{ scenario = 'S7' }
        $s7.data.decision.action -eq 'escalate' -and -not $s7.data.proposalId
    }

    Add-Check -Id 'SEC-01' -Details 'Scenario S8 cannot make injected log text escape the triage allow-list or invent a target.' -Action {
        $script:s8 = Invoke-PortalJson -Method POST -Path '/agent/simulate' -Body @{ scenario = 'S8' }
        $s8.data.decision.action -in @('ignore', 'notify', 'escalate') -and $s8.data.decision.targetType -eq 'none' -and -not $s8.data.proposalId
    }

    Add-Check -Id 'SEC-02' -Details 'Scenario S9 remains high risk despite the injected justification.' -Action {
        $script:s9 = Invoke-PortalJson -Method POST -Path '/agent/simulate' -Body @{ scenario = 'S9' }
        $s9.data.decision.action -eq 'escalate' -and $s9.data.decision.riskLevel -eq 'high' -and -not $s9.data.proposalId
    }

    Add-Check -Id 'IT-11' -Details 'Scenario S10 falls back to Rules when the budget is blocked.' -Action {
        $script:s10 = Invoke-PortalJson -Method POST -Path '/agent/simulate' -Body @{ scenario = 'S10' }
        $s10.data.engine -eq 'rules' -and $s10.data.outcome -eq 'budget_blocked'
    }

    if ($null -ne $viewerHeaders) {
        Add-Check -Id 'SEC-05' -Details 'A Viewer cannot confirm a proposal by calling the REST route directly.' -Action {
            $viewerError = Invoke-PortalError -Method POST -Path "/agent/proposals/$($s5.data.proposalId)/confirm" -Body $null -RequestHeaders $viewerHeaders
            $viewerError.StatusCode -eq 403 -and $viewerError.Code -eq 'FORBIDDEN'
        }
    } else {
        Add-Skip -Id 'SEC-05' -Details 'Pass -ViewerCredential to verify the Viewer REST authorization boundary.'
    }

    Add-Check -Id 'SEC-06' -Details 'A requester cannot confirm their own access proposal.' -Action {
        if (-not $s5.data.proposalId) { return $false }
        $confirmError = Invoke-PortalError -Method POST -Path "/agent/proposals/$($s5.data.proposalId)/confirm" -Body $null
        $blocked = $confirmError.StatusCode -eq 403 -and $confirmError.Code -eq 'SEPARATION_OF_DUTIES'
        Invoke-PortalJson -Method POST -Path "/agent/proposals/$($s5.data.proposalId)/reject" -Body @{ reason = 'Automated test cleanup' } | Out-Null
        $blocked
    }

    Add-Check -Id 'IT-13' -Details 'An access request is queued at once and its decision is readable later through REST.' -Action {
        $submitted = Invoke-PortalJson -Method POST -Path '/agent/access-requests' -Body @{ role = '%Operator'; justification = 'Automated test: asynchronous access request.' }
        $queued = $submitted.data.status -eq 'queued' -and [bool]$submitted.data.id -and [bool]$submitted.data.traceId
        $detail = $null
        for ($attempt = 0; $attempt -lt 60; $attempt++) {
            $detail = Invoke-PortalJson -Method GET -Path "/agent/access-requests/$($submitted.data.id)"
            if ($detail.data.status -ne 'queued') { break }
            Start-Sleep -Milliseconds 500
        }
        if ($detail.data.proposalId) {
            Invoke-PortalJson -Method POST -Path "/agent/proposals/$($detail.data.proposalId)/reject" -Body @{ reason = 'Automated test cleanup' } | Out-Null
        }
        $finished = $detail.data.status -eq 'suppressed' -or ($detail.data.status -eq 'decided' -and [bool]$detail.data.decision.action -and $detail.data.traceId -eq $submitted.data.traceId)
        $queued -and $finished
    }

    Add-Check -Id 'IT-10' -Details 'Read-only mode allows analysis but does not create a proposal.' -Action {
        Invoke-PortalJson -Method PUT -Path '/agent/config' -Body @{ readOnly = $true } | Out-Null
        $readOnlyResult = Invoke-PortalJson -Method POST -Path '/agent/simulate' -Body @{ scenario = 'S2'; taskId = $demoTaskId }
        Invoke-PortalJson -Method PUT -Path '/agent/config' -Body @{ readOnly = $false } | Out-Null
        $readOnlyResult.data.decision.action -eq 'propose_task_suspend' -and -not $readOnlyResult.data.proposalId
    }

    Add-Check -Id 'IT-09' -Details 'The kill switch prevents agent actions and keeps the Rules fallback available.' -Action {
        Invoke-PortalJson -Method POST -Path '/agent/killswitch' -Body @{ enabled = $true } | Out-Null
        $killed = Invoke-PortalJson -Method POST -Path '/agent/simulate' -Body @{ scenario = 'S1' }
        Invoke-PortalJson -Method POST -Path '/agent/killswitch' -Body @{ enabled = $false } | Out-Null
        $killed.data.outcome -eq 'killed' -and -not $killed.data.proposalId
    }

    Add-Check -Id 'GUARDRAILS' -Details 'The public guardrail description confirms human confirmation and read-only tools.' -Action {
        $script:guardrails = Invoke-PortalJson -Method GET -Path '/agent/guardrails'
        [bool]$guardrails.data.stateChangesRequireConfirmation -and [bool]$guardrails.data.agentToolsAreReadOnly
    }

    Add-Check -Id 'SEC-10' -Details 'Repeated identical health analysis is suppressed by the cooldown.' -Action {
        $firstFloodResult = Invoke-PortalJson -Method POST -Path '/agent/analyze' -Body $null
        $secondFloodResult = Invoke-PortalJson -Method POST -Path '/agent/analyze' -Body $null
        $secondFloodResult.data.status -eq 'suppressed'
    }

    Add-Check -Id 'IT-12' -Details 'The observability ledger contains coherent aggregate values.' -Action {
        $script:ledger = Invoke-PortalJson -Method GET -Path '/agent/ledger/summary'
        [int]$ledger.data.decisions -gt 0 -and [double]$ledger.data.totalTokens -ge 0
    }

    Add-Check -Id 'SEC-08' -Details 'Scenario responses do not expose credentials, authorization headers, tokens, or stack traces.' -Action {
        $combinedPayload = $capturedPayloads -join "`n"
        $secretPattern = '(?i)("(?:password|authorization)"\s*:\s*"[^"]+"|bearer\s+[A-Za-z0-9._-]{8,}|sk-[A-Za-z0-9_-]{8,}|<stack>|%Exception)'
        -not [regex]::IsMatch($combinedPayload, $secretPattern)
    }
} finally {
    if ($null -ne $originalTaskSuspended -and $null -ne $demoTaskId) {
        try {
            $currentTask = Invoke-PortalJson -Method GET -Path "/tasks/detail?id=$demoTaskId"
            $currentSuspended = ([int]$currentTask.data.suspended -eq 1)
            if ($currentSuspended -ne $originalTaskSuspended) {
                $restoreAction = if ($originalTaskSuspended) { 'suspend' } else { 'resume' }
                Invoke-PortalJson -Method POST -Path '/tasks/action' -Body @{ id = $demoTaskId; action = $restoreAction } | Out-Null
            }
        } catch {
            Write-Warning "Could not restore the demonstration task state: $($_.Exception.Message)"
        }
    }
    if ($null -ne $originalConfig) {
        try {
            Invoke-PortalJson -Method PUT -Path '/agent/config' -Body @{
                demoMode = [bool]$originalConfig.demoMode
                enginePreference = [string]$originalConfig.enginePreference
                readOnly = [bool]$originalConfig.readOnly
                cooldownMinutes = [int]$originalConfig.cooldownMinutes
            } | Out-Null
            Invoke-PortalJson -Method POST -Path '/agent/killswitch' -Body @{ enabled = [bool]$originalConfig.killSwitch } | Out-Null
        } catch {
            Write-Warning "Could not restore the original agent configuration: $($_.Exception.Message)"
        }
    }
}

$health = Invoke-PortalJson -Method GET -Path '/health'
$pass = @($results | Where-Object status -eq 'pass').Count
$fail = @($results | Where-Object status -eq 'fail').Count
$skip = @($results | Where-Object status -eq 'skip').Count
$report = [ordered]@{
    suite = 'agents-core'
    startedAt = $startedAt.ToString('o')
    finishedAt = [DateTimeOffset]::Now.ToString('o')
    iris = [ordered]@{
        version = [string]$health.data.version
        image = $IrisImage
        edition = $Edition
    }
    engine = 'rules'
    results = $results
    summary = [ordered]@{ pass = $pass; fail = $fail; skip = $skip }
}

$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path (Split-Path -Parent $PSScriptRoot) $OutputPath }
$outputDirectory = Split-Path -Parent $resolvedOutput
if (-not (Test-Path -LiteralPath $outputDirectory)) { New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null }
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resolvedOutput -Encoding UTF8
Write-Host "Report written to $resolvedOutput" -ForegroundColor Cyan

if ($fail -gt 0) { throw "$fail agent test(s) failed." }
Write-Host "All $pass executable agent tests passed; $skip optional test(s) skipped." -ForegroundColor Green
