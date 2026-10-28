[CmdletBinding()]
param(
    [string]$BaseUrl = 'http://localhost:52774',
    # An administrator: creates and removes the temporary web application /myown/test-docs.
    [Parameter(Mandatory)]
    [PSCredential]$Credential,
    [string]$Namespace = 'MYOWN',
    [string]$OutputPath = 'test-results/api-docs.json'
)

# Tests of the API documentation (MyOwn.REST.Docs): DOC-01..04 inside IRIS (MyOwn_Test.DocsSmoke),
# then over HTTP: authentication, method, JSON and route coverage against the UrlMap in
# src/objectscript/MyOwn/REST.cls, a self-contained page, no secrets, and a second class that
# only extends the base (served by a temporary web application, removed at the end).

$ErrorActionPreference = 'Stop'
$startedAt = [DateTimeOffset]::Now
$root = $BaseUrl.TrimEnd('/')
$projectRoot = Split-Path -Parent $PSScriptRoot
$results = [System.Collections.Generic.List[object]]::new()
$token = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$($Credential.UserName):$($Credential.GetNetworkCredential().Password)"))
$auth = @{ Authorization = "Basic $token" }

function Invoke-IrisSql([string]$Query, [object[]]$Parameters = @()) {
    $body = @{ query = $Query; parameters = $Parameters } | ConvertTo-Json -Compress
    $response = Invoke-RestMethod -Method Post -Uri "$root/api/atelier/v1/$Namespace/action/query" -Headers $auth -ContentType 'application/json' -Body $body -TimeoutSec 120
    if ($response.status.errors.Count) { throw "SQL failed: $($response.status.errors | ConvertTo-Json -Compress)" }
    return $response.result.content
}

function Invoke-Http([string]$Method, [string]$Path, [hashtable]$Headers = @{}) {
    try {
        $r = Invoke-WebRequest -Uri "$root$Path" -Method $Method -Headers $Headers -UseBasicParsing -TimeoutSec 60
        return [pscustomobject]@{ status = [int]$r.StatusCode; body = $r.Content; headers = $r.Headers }
    } catch [System.Net.WebException] {
        if ($null -eq $_.Exception.Response) { throw }
        return [pscustomobject]@{ status = [int]$_.Exception.Response.StatusCode; body = ''; headers = $_.Exception.Response.Headers }
    }
}

function Add-Result([string]$Id, [bool]$Passed, [string]$Details) {
    $status = if ($Passed) { 'pass' } else { 'fail' }
    $results.Add([ordered]@{ id = $Id; status = $status; details = $Details })
    Write-Host ("{0,-5} {1}  {2}" -f $status.ToUpper(), $Id, $Details) -ForegroundColor $(if ($Passed) { 'Green' } else { 'Red' })
}

function Test-Leaks([string]$Text) {
    $found = @()
    foreach ($pattern in 'AIza[0-9A-Za-z_-]{20,}', 'sk-[A-Za-z0-9_-]{20,}', 'AQ\.[A-Za-z0-9_-]{8,}', 'ChangeMe2026', '(?i)"(api_?key|password|secret)"\s*:\s*"[^"]+"') {
        if ([regex]::IsMatch($Text, $pattern)) { $found += $pattern }
    }
    return $found
}

$smoke = (Invoke-IrisSql -Query 'SELECT MyOwn_Test.DocsSmoke() AS r')[0].r
if ($smoke -is [string]) { $smoke = $smoke | ConvertFrom-Json }
foreach ($item in $smoke.results) { Add-Result $item.id ($item.status -eq 'pass') $item.details }

# Authentication: the documentation follows the web application (401 without credentials).
$codes = foreach ($path in '/myown/api/openapi.json', '/myown/api/docs') { "$path=$((Invoke-Http GET $path).status)/$((Invoke-Http GET $path $auth).status)" }
$post = (Invoke-Http POST '/myown/api/docs' $auth).status
Add-Result 'DOC-10-AUTH' ((-not ($codes | Where-Object { $_ -notmatch '=401/200$' })) -and ($post -eq 405)) "Without/with credentials: $($codes -join ', '); POST /docs answers $post (read-only)."

# The document over HTTP: valid JSON, every UrlMap route of the source file.
$spec = Invoke-Http GET '/myown/api/openapi.json' $auth
$parsed = $null
try { $parsed = $spec.body | ConvertFrom-Json } catch { }
$source = Get-Content -LiteralPath (Join-Path $projectRoot 'src\objectscript\MyOwn\REST.cls') -Raw -Encoding UTF8
$routes = [regex]::Matches($source, '<Route Url="([^"]+)" Method="([^"]+)"') | ForEach-Object { [pscustomobject]@{ path = ($_.Groups[1].Value -replace ':([A-Za-z0-9_]+)', '{$1}'); verb = $_.Groups[2].Value.ToLower() } }
$missing = @($routes | Where-Object { -not ($parsed.paths.PSObject.Properties.Name -contains $_.path) -or -not ($parsed.paths.($_.path).PSObject.Properties.Name -contains $_.verb) } | ForEach-Object { "$($_.verb) $($_.path)" })
$operations = @($parsed.paths.PSObject.Properties | ForEach-Object { $_.Value.PSObject.Properties.Name }).Count
Add-Result 'DOC-11-COVERAGE' (($null -ne $parsed) -and ($parsed.openapi -eq '3.0.3') -and ($missing.Count -eq 0)) "openapi.json is valid JSON (OpenAPI $($parsed.openapi), $operations operations); all $(@($routes).Count) routes of REST.cls are documented$(if ($missing.Count) { '; missing: ' + ($missing -join ', ') })."

# The page: self-contained and locked down.
$page = Invoke-Http GET '/myown/api/docs' $auth
$external = [regex]::Matches($page.body, '(src|href)\s*=\s*"(https?:)?//') | ForEach-Object { $_.Value }
$csp = "$($page.headers['Content-Security-Policy'])"
Add-Result 'DOC-12-PAGE' (($page.status -eq 200) -and ($external.Count -eq 0) -and ($csp -match "default-src 'none'") -and ($csp -match 'script-src .nonce-') -and ($page.body -match 'openapi\.json')) "The /docs page loads nothing from outside (no external src/href), sends a Content-Security-Policy with a script nonce, and reads openapi.json from the same application."

# No secrets in what the documentation serves.
$leaks = @(Test-Leaks ($spec.body + $page.body))
Add-Result 'DOC-13-NO-SECRETS' ($leaks.Count -eq 0) $(if ($leaks.Count) { "Found: $($leaks -join ', ')" } else { 'No key pattern, password value or demo password in /openapi.json or /docs.' })

# A second class that only extends the base gets /docs and /openapi.json.
$created = (Invoke-IrisSql -Query 'SELECT MyOwn_Test.TestDocsAppCreate() AS r')[0].r
try {
    if ($created -ne 'ok') { throw "The temporary web application could not be created: $created" }
    $sampleSpec = Invoke-Http GET '/myown/test-docs/openapi.json' $auth
    $sampleDocs = Invoke-Http GET '/myown/test-docs/docs' $auth
    $sampleNoAuth = (Invoke-Http GET '/myown/test-docs/docs').status
    $item = Invoke-Http GET '/myown/test-docs/items/7' $auth
    $sample = $null
    try { $sample = $sampleSpec.body | ConvertFrom-Json } catch { }
    $paths = if ($sample) { @($sample.paths.PSObject.Properties.Name) } else { @() }
    $ok = ($sampleSpec.status -eq 200) -and ($sampleDocs.status -eq 200) -and ($sampleNoAuth -eq 401) -and ($item.status -eq 200) -and ($paths -contains '/items') -and ($paths -contains '/items/{id}') -and ($paths -contains '/docs') -and -not ($paths -contains '/agent/status') -and ($sample.info.title -eq 'Docs sample')
    Add-Result 'DOC-14-SECOND-CLASS' $ok "MyOwn.Test.DocsSample on /myown/test-docs: openapi.json $($sampleSpec.status), docs $($sampleDocs.status), docs without credentials $sampleNoAuth, its own route /items/7 $($item.status); paths: $($paths -join ', ')."
} catch {
    Add-Result 'DOC-14-SECOND-CLASS' $false $_.Exception.Message
} finally {
    $removed = (Invoke-IrisSql -Query 'SELECT MyOwn_Test.TestDocsAppRemove() AS r')[0].r
    if ($removed -ne 'ok') { Write-Host "The temporary web application was not removed: $removed" -ForegroundColor Yellow }
}

$pass = @($results | Where-Object status -eq 'pass').Count
$fail = @($results | Where-Object status -eq 'fail').Count
$report = [ordered]@{ suite = 'api-docs'; startedAt = $startedAt.ToString('o'); finishedAt = [DateTimeOffset]::Now.ToString('o'); results = $results; summary = [ordered]@{ pass = $pass; fail = $fail; skip = 0 } }
$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $projectRoot $OutputPath }
$directory = Split-Path -Parent $resolvedOutput
if (-not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resolvedOutput -Encoding UTF8
Write-Host "Report written to $resolvedOutput" -ForegroundColor Cyan
if ($fail -gt 0) { throw "$fail API docs test(s) failed." }
Write-Host "API docs suite completed: $pass passed." -ForegroundColor Green
