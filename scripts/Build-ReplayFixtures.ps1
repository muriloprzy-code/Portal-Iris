[CmdletBinding()]
param(
    # Only compare: fail when MyOwn.AIHub.Fixtures does not match aihub/fixtures/*.json.
    [switch]$Check
)

# Writes the replay fixtures (aihub/fixtures/S1.json..S10.json and tests.json) into the XData
# block of aihub/src/MyOwn/AIHub/Fixtures.cls. Each scenario file is either a recorded real
# answer with its header (provider, model, recordedAt, source, context, substitutions) or a
# placeholder with status "pending" / "not_applicable".

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$fixtureDirectory = Join-Path $root 'aihub\fixtures'
$classPath = Join-Path $root 'aihub\src\MyOwn\AIHub\Fixtures.cls'

$scenarios = [ordered]@{}
foreach ($index in 1..10) {
    $path = Join-Path $fixtureDirectory "S$index.json"
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing fixture file $path." }
    $fixture = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($fixture.scenario -ne "S$index") { throw "S$index.json declares scenario '$($fixture.scenario)'." }
    if ($fixture.status -notin @('recorded', 'pending', 'not_applicable')) { throw "S$index.json has an unknown status '$($fixture.status)'." }
    if ($fixture.status -eq 'recorded') {
        foreach ($field in 'provider', 'model', 'recordedAt', 'source', 'raw') {
            if ([string]::IsNullOrWhiteSpace([string]$fixture.$field)) { throw "S$index.json is recorded but has no $field." }
        }
    }
    $scenarios["S$index"] = $fixture
}
$tests = Get-Content -LiteralPath (Join-Path $fixtureDirectory 'tests.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$json = [ordered]@{ scenarios = $scenarios; tests = $tests } | ConvertTo-Json -Depth 20 -Compress

$class = [IO.File]::ReadAllText($classPath, [Text.Encoding]::UTF8)
$pattern = '(?s)(XData Cases \[ MimeType = application/json \]\r?\n\{\r?\n).*?(\r?\n\}\r?\n\r?\n\}\s*)$'
if ($class -notmatch $pattern) { throw 'The XData Cases block was not found in Fixtures.cls.' }
$updated = [regex]::Replace($class, $pattern, { param($m) $m.Groups[1].Value + $json + $m.Groups[2].Value })

$pending = @($scenarios.Values | Where-Object status -eq 'pending' | ForEach-Object scenario)
$notApplicable = @($scenarios.Values | Where-Object status -eq 'not_applicable' | ForEach-Object scenario)
$recorded = @($scenarios.Values | Where-Object status -eq 'recorded' | ForEach-Object scenario)
if ($Check) {
    if ($updated -ne $class) { throw 'Fixtures.cls is out of date: run scripts/Build-ReplayFixtures.ps1.' }
    Write-Host 'PASS  Fixtures.cls matches aihub/fixtures.' -ForegroundColor Green
} else {
    [IO.File]::WriteAllText($classPath, $updated, [Text.UTF8Encoding]::new($false))
    Write-Host "Fixtures.cls updated." -ForegroundColor Cyan
}
Write-Host "Recorded: $($recorded -join ', '). Pending recording: $(if ($pending) { $pending -join ', ' } else { 'none' }). Not applicable: $($notApplicable -join ', ')."
