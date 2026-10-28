[CmdletBinding()]
param(
    [string]$BaseUrl = 'http://localhost:52774',
    [Parameter(Mandatory)]
    [PSCredential]$Credential,
    [string]$OutputPath = 'test-results/agents-ui.json',
    [string]$ScreenshotDirectory = 'test-results/ui'
)

# Runs the Agents screens in an isolated browser (Playwright's bundled Chromium with a fresh
# profile, never the user's browser): S1..S10 from the Overview simulator, then each decision
# drawer, and "Open trace" on a scenario result. Installs the pinned test dependency and browser
# on first use. The credential is passed to Node through process environment variables only,
# never on the command line.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$testDirectory = Join-Path $root 'tests\ui'
$localNode = Join-Path $root '.tools\node'
if (Test-Path -LiteralPath (Join-Path $localNode 'node.exe')) { $env:PATH = "$localNode;$env:PATH" }
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw 'Node.js was not found (expected in .tools\node or on PATH).' }
# npm writes "npm notice" update hints to stderr, which Windows PowerShell turns into a terminating
# error when the output is redirected (as Test-All.ps1 does); this process does not need them.
$env:NPM_CONFIG_UPDATE_NOTIFIER = 'false'

Push-Location $testDirectory
try {
    if (-not (Test-Path -LiteralPath (Join-Path $testDirectory 'node_modules\playwright'))) {
        Write-Host 'Installing the pinned Playwright test dependency...' -ForegroundColor Cyan
        & npm ci --no-fund --no-audit
        if ($LASTEXITCODE -ne 0) { throw 'npm ci failed.' }
    }
    & npx playwright install chromium
    if ($LASTEXITCODE -ne 0) { throw 'The Playwright Chromium browser could not be installed.' }

    $resolve = { param($path) if ([IO.Path]::IsPathRooted($path)) { $path } else { Join-Path $root $path } }
    # index.html explicitly: the private web server of the IRIS containers serves no default document for /myown/.
    $env:MYOWN_UI_URL = "$($BaseUrl.TrimEnd('/'))/myown/index.html"
    $env:MYOWN_UI_USER = $Credential.UserName
    $env:MYOWN_UI_PASSWORD = $Credential.GetNetworkCredential().Password
    $env:MYOWN_UI_OUT = & $resolve $ScreenshotDirectory
    $env:MYOWN_UI_REPORT = & $resolve $OutputPath
    & node agents-ui.mjs
    $exitCode = $LASTEXITCODE
} finally {
    Remove-Item Env:MYOWN_UI_PASSWORD, Env:MYOWN_UI_USER -ErrorAction SilentlyContinue
    Pop-Location
}

if ($exitCode -ne 0) { throw 'The agents UI test failed. See the report and screenshots.' }
Write-Host 'All agents UI checks passed.' -ForegroundColor Green
