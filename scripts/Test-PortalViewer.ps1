[CmdletBinding()]
param(
    [string]$BaseUrl = 'http://localhost:52774',
    # An administrator: creates and removes the temporary viewer account.
    [Parameter(Mandatory)]
    [PSCredential]$Credential,
    [string]$Namespace = 'MYOWN',
    [string]$OutputPath = 'test-results/portal-viewer.json'
)

# Role test for MyOwnViewer without %All: a temporary account "myown.test.viewer" with only that
# role (random password, kept in memory) signs in and calls every route of the screens a viewer
# sees (Overview, Logs, Agents), then the administration routes, which must answer 403.
# The account is removed at the end.

$ErrorActionPreference = 'Stop'
$startedAt = [DateTimeOffset]::Now
$root = $BaseUrl.TrimEnd('/')
$results = [System.Collections.Generic.List[object]]::new()
$user = 'myown.test.viewer'

function New-Headers([string]$name, [string]$secret) {
    $token = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("${name}:$secret"))
    @{ Authorization = "Basic $token"; 'X-MyOwn-SysAdmin-Authorization' = "Basic $token"; Accept = 'application/json' }
}
$adminHeaders = New-Headers $Credential.UserName $Credential.GetNetworkCredential().Password

function Invoke-Portal([hashtable]$Headers, [string]$Method, [string]$Path, [object]$Body) {
    $arguments = @{ Uri = "$root/myown/api$Path"; Method = $Method; Headers = $Headers; UseBasicParsing = $true; TimeoutSec = 60 }
    if ($null -ne $Body) { $arguments.ContentType = 'application/json'; $arguments.Body = ($Body | ConvertTo-Json -Depth 10 -Compress) }
    try {
        $response = Invoke-WebRequest @arguments
        return [pscustomobject]@{ status = [int]$response.StatusCode; body = ($response.Content | ConvertFrom-Json) }
    } catch [System.Net.WebException] {
        if ($null -eq $_.Exception.Response) { throw }
        $parsed = $null
        try { $parsed = $_.ErrorDetails.Message | ConvertFrom-Json } catch { }
        return [pscustomobject]@{ status = [int]$_.Exception.Response.StatusCode; body = $parsed }
    }
}

function Invoke-IrisSql([string]$Query, [object[]]$Parameters = @()) {
    $body = @{ query = $Query; parameters = $Parameters } | ConvertTo-Json -Compress
    $response = Invoke-RestMethod -Method Post -Uri "$root/api/atelier/v1/$Namespace/action/query" -Headers $adminHeaders -ContentType 'application/json' -Body $body -TimeoutSec 120
    if ($response.status.errors.Count) { throw "SQL failed: $($response.status.errors | ConvertTo-Json -Compress)" }
    return $response.result.content
}

function Add-Result([string]$Id, [bool]$Passed, [string]$Details) {
    $status = if ($Passed) { 'pass' } else { 'fail' }
    $results.Add([ordered]@{ id = $Id; status = $status; details = $Details })
    Write-Host ("{0,-5} {1}  {2}" -f $status.ToUpper(), $Id, $Details) -ForegroundColor $(if ($Passed) { 'Green' } else { 'Red' })
}

$alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'.ToCharArray()
$bytes = [byte[]]::new(24)
[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$secret = -join ($bytes | ForEach-Object { $alphabet[$_ % $alphabet.Length] })

try {
    $created = (Invoke-IrisSql -Query 'SELECT MyOwn_Test.TestEnsureUser(?, ?, ?) AS r' -Parameters @($user, 'MyOwnViewer', $secret))[0].r
    if ($created -ne 'ok') { throw "The temporary viewer account could not be created: $created" }
    $viewer = New-Headers $user $secret

    $session = Invoke-Portal $viewer GET '/session'
    Add-Result 'VW-01-SESSION' (($session.status -eq 200) -and ($session.body.data.accessLevel -eq 'Viewer') -and -not [bool][int]$session.body.data.canManage) "A MyOwnViewer-only account signs in as Viewer (HTTP $($session.status), level $($session.body.data.accessLevel))."

    # Routes of the Overview, Logs and Agents screens for a viewer.
    $routes = '/health', '/system/summary', '/system/health-report', '/logs', '/agent/status', '/agent/decisions', '/agent/access-requests', '/agent/ledger/summary', '/agent/production/status', '/agent/guardrails', '/demo/state'
    $statuses = foreach ($path in $routes) { $r = Invoke-Portal $viewer GET $path; "$path=$($r.status)$(if ($r.status -ne 200 -and $r.body.error.code) { " $($r.body.error.code)" })" }
    Add-Result 'VW-02-SCREENS' (-not ($statuses | Where-Object { $_ -notmatch '=200$' })) "Viewer screens: $($statuses -join ', ')."

    $decisions = (Invoke-Portal $viewer GET '/agent/decisions').body.data
    if (@($decisions).Count -gt 0) {
        $first = @($decisions)[0]
        $detail = Invoke-Portal $viewer GET "/agent/decisions/$($first.id)"
        $trace = Invoke-Portal $viewer GET "/agent/traces/$($first.traceId)"
        Add-Result 'VW-03-DETAIL' (($detail.status -eq 200) -and ($trace.status -eq 200)) "Decision drawer and trace for decision $($first.id): HTTP $($detail.status), $($trace.status)."
    } else {
        Add-Result 'VW-03-DETAIL' $false 'No decision to open; run a scenario first.'
    }

    $request = Invoke-Portal $viewer POST '/agent/access-requests' @{ role = 'MyOwnViewer'; justification = 'Viewer role test.' }
    # The privilege delta of a request is read through SysAdmin API v2 with the requester's own credentials.
    try { $sysadmin = [int](Invoke-WebRequest "$root/api/admin/v2/security/user?name=$user" -Headers $viewer -UseBasicParsing -TimeoutSec 30).StatusCode } catch { $sysadmin = [int]$_.Exception.Response.StatusCode }

    # Documented limitation: SysAdmin API v2 refuses a viewer even its own account (403), so the
    # portal refuses the request clearly instead of failing with 500.
    Add-Result 'VW-04-ACCESS-REQUEST' (($request.status -eq 403) -and ($request.body.error.code -eq 'ACCESS_REQUEST_NEEDS_SECURITY_READ') -and ($sysadmin -eq 403)) "A viewer cannot file an access request (HTTP $($request.status) $($request.body.error.code)) because SysAdmin API v2 refuses it even its own account (HTTP $sysadmin); the refusal is explicit, not a 500."

    $refusedCalls = @(
        @('GET', '/agent/config'), @('PUT', '/agent/config'), @('GET', '/agent/proposals'), @('POST', '/agent/simulate'), @('POST', '/agent/killswitch'),
        @('POST', '/agent/production/stop'), @('POST', '/tasks/action'), @('POST', '/applications/state'), @('POST', '/permissions/users/x/roles'), @('GET', '/agent/pricing')
    )
    $codes = foreach ($call in $refusedCalls) { $body = if ($call[0] -eq 'GET') { $null } else { @{} }; "$($call[0]) $($call[1])=$((Invoke-Portal $viewer $call[0] $call[1] $body).status)" }
    Add-Result 'VW-05-ADMIN-REFUSED' (-not ($codes | Where-Object { $_ -notmatch '=403$' })) "Administration routes are refused for a viewer: $($codes -join ', ')."
} finally {
    $removed = (Invoke-IrisSql -Query 'SELECT MyOwn_Test.TestRemoveUser(?) AS r' -Parameters @($user))[0].r
    if ($removed -ne 'ok') { Write-Host "The temporary account was not removed: $removed" -ForegroundColor Yellow }
    Remove-Variable secret -ErrorAction SilentlyContinue
}

$pass = @($results | Where-Object status -eq 'pass').Count
$fail = @($results | Where-Object status -eq 'fail').Count
$report = [ordered]@{ suite = 'portal-viewer'; startedAt = $startedAt.ToString('o'); finishedAt = [DateTimeOffset]::Now.ToString('o'); results = $results; summary = [ordered]@{ pass = $pass; fail = $fail; skip = 0 } }
$projectRoot = Split-Path -Parent $PSScriptRoot
$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $projectRoot $OutputPath }
$directory = Split-Path -Parent $resolvedOutput
if (-not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resolvedOutput -Encoding UTF8
Write-Host "Report written to $resolvedOutput" -ForegroundColor Cyan
if ($fail -gt 0) { throw "$fail viewer test(s) failed." }
Write-Host "Viewer suite completed: $pass passed." -ForegroundColor Green
