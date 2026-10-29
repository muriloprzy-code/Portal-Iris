[CmdletBinding()]
param(
    [string]$BaseUrl = 'http://localhost:52774',
    # The defaults are the public credentials of the hosted demo only; for your own instance pass
    # the demo password from your .env (MYOWN_DEMO_USER_PASSWORD).
    [string]$User = 'demo',
    [string]$Password = 'demo',
    [string[]]$Scenarios = @('S1', 'S2', 'S5'),
    [int]$TimeoutSec = 90
)

# Runs demonstration scenarios through the REST API as the demo account, the same calls the
# Agents screen makes: POST /agent/simulate {"scenario": "S1"} (in demo mode the server picks its
# synthetic targets, so no taskId is sent), then GET /agent/traces/<traceId> for the ledger
# (tokens and tool calls) and GET /agent/proposals for the proposal state. Prints one row per
# scenario. Nothing sensitive is printed: no password, no Authorization header, no model text.

$ErrorActionPreference = 'Stop'
$root = $BaseUrl.TrimEnd('/')
$token = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("${User}:$Password"))
$headers = @{ Authorization = "Basic $token"; Accept = 'application/json' }

function Invoke-Demo([string]$Method, [string]$Path, [object]$Body) {
    $arguments = @{ Uri = "$root/myown/api$Path"; Method = $Method; Headers = $headers; UseBasicParsing = $true; TimeoutSec = $TimeoutSec }
    if ($null -ne $Body) { $arguments.ContentType = 'application/json'; $arguments.Body = ($Body | ConvertTo-Json -Compress) }
    try {
        return (Invoke-WebRequest @arguments).Content | ConvertFrom-Json
    } catch [System.Net.WebException] {
        $exception = $_.Exception
        if ($exception.Status -eq [System.Net.WebExceptionStatus]::Timeout) { throw "$Method $Path timed out after $TimeoutSec s. The server may be busy; try again, or raise -TimeoutSec." }
        if ($null -eq $exception.Response) { throw "$Method $Path could not reach $root ($($exception.Status))." }
        $status = [int]$exception.Response.StatusCode
        $code = ''
        try { $code = ($_.ErrorDetails.Message | ConvertFrom-Json).error.code } catch { }
        switch ($status) {
            401 { throw "Sign-in refused (HTTP 401): wrong user or password, or demo mode is off on $root." }
            403 { throw "Refused (HTTP 403 $code): this account cannot call $Method $Path. Scenarios need demo mode on the server (the demo account), or an administrator with Demo mode on in Agents > Settings." }
            429 { throw "Rate limited (HTTP 429): too many scenarios this minute; try again in $($exception.Response.Headers['Retry-After']) s." }
            default { throw "$Method $Path failed: HTTP $status $code." }
        }
    }
}

try {
    $status = (Invoke-Demo GET '/agent/status').data
    Write-Host "Server $root, AI mode $($status.aiMode), engine preference $($status.enginePreference), model $($status.model)." -ForegroundColor Cyan

    $rows = foreach ($scenario in $Scenarios) {
        $run = (Invoke-Demo POST '/agent/simulate' @{ scenario = $scenario }).data
        $ledger = @((Invoke-Demo GET "/agent/traces/$($run.traceId)").data.timeline | Where-Object { $_.type -eq 'ledger' })
        $tokens = ($ledger | Measure-Object -Property totalTokens -Sum).Sum
        $tools = ($ledger | Measure-Object -Property toolCallCount -Sum).Sum
        $proposal = '-'
        if ([int]$run.proposalId -gt 0) {
            $item = @((Invoke-Demo GET '/agent/proposals').data | Where-Object { [int]$_.id -eq [int]$run.proposalId })[0]
            $proposal = if ($item) { "#$($run.proposalId) $($item.kind) ($($item.state))" } else { "#$($run.proposalId)" }
        }
        [pscustomobject]@{
            Scenario  = $scenario
            Action    = $run.decision.action
            Engine    = if ($run.fallbackReason) { "$($run.engine) ($($run.fallbackReason))" } else { $run.engine }
            Tokens    = [int]$tokens
            ToolCalls = [int]$tools
            Proposal  = $proposal
        }
    }
    $rows | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
    Write-Host 'Proposals stay pending until a human confirms or rejects them in Agents > Approvals.'
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
