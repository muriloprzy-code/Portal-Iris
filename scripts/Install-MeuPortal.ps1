<#
.SYNOPSIS
Installs Meu Portal end to end: builds and deploys the frontend, restarts the
private IRIS web server, and prepares the backend install command.

.DESCRIPTION
This single script replaces the previous multi-step manual process (VS Code
class compile + separate frontend script + manual httpd edit). It still needs
one interactive step it cannot safely automate: pasting three lines into an
authenticated IRIS terminal, because that requires your IRIS login and this
script never stores or types a password for you. Everything else runs
automatically.

Prerequisite: the target namespace (MEUPORTAL by default) must already exist.
Create it once in the native Management Portal: System Administration >
Configuration > System Configuration > Namespaces > New Namespace.
#>
[CmdletBinding()]
param(
    [string]$IrisInstallDir = 'C:\InterSystems\IRIS',
    [string]$Instance = 'IRIS',
    [string]$Namespace = 'MEUPORTAL',
    [switch]$SkipBuild,
    [switch]$SkipWebServerRestart,
    [switch]$SkipBackendPrompt
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$frontendDir = Join-Path $projectRoot 'frontend'
$distDir = Join-Path $frontendDir 'dist'
$sourceDir = Join-Path $projectRoot 'src\objectscript'
$targetDir = Join-Path $IrisInstallDir 'CSP\meuportal'
$httpdConfig = Join-Path $IrisInstallDir 'httpd\conf\httpd-local.conf'
$httpdExecutable = Join-Path $IrisInstallDir 'httpd\bin\httpd.exe'
$irisExecutable = Join-Path $IrisInstallDir 'bin\iris.exe'
$configTemplate = Join-Path $projectRoot 'deploy\httpd-meuportal.conf'
$configStart = '# BEGIN MEU PORTAL'
$configEnd = '# END MEU PORTAL'

if (-not (Test-Path -LiteralPath $IrisInstallDir)) {
    throw "IRIS installation directory was not found: $IrisInstallDir"
}
if (-not (Test-Path -LiteralPath $irisExecutable)) {
    throw "iris.exe was not found at $irisExecutable"
}

Write-Host '== Step 1/3: Frontend build ==' -ForegroundColor Cyan
if (-not $SkipBuild) {
    Push-Location $frontendDir
    try {
        if (-not (Test-Path -LiteralPath (Join-Path $frontendDir 'node_modules'))) {
            npm install
            if ($LASTEXITCODE -ne 0) { throw 'npm install failed.' }
        }
        npm run build
        if ($LASTEXITCODE -ne 0) { throw 'The frontend build failed.' }
    } finally {
        Pop-Location
    }
} else {
    Write-Host 'Skipped (-SkipBuild).'
}

if (-not (Test-Path -LiteralPath (Join-Path $distDir 'index.html'))) {
    throw 'frontend/dist/index.html was not found. Run the build first (remove -SkipBuild), or use build-frontend.bat / install-node-local.bat if Node.js is not on PATH.'
}

Write-Host '== Step 2/3: Deploy frontend and restart the private web server ==' -ForegroundColor Cyan
New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
$targetAssets = Join-Path $targetDir 'assets'
if (Test-Path -LiteralPath $targetAssets) {
    Remove-Item -LiteralPath $targetAssets -Recurse -Force
}
New-Item -ItemType Directory -Path $targetAssets -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $distDir 'index.html') -Destination $targetDir -Force
Copy-Item -Path (Join-Path $distDir 'assets\*') -Destination $targetAssets -Force

if (-not (Test-Path -LiteralPath $httpdConfig)) {
    throw "IRIS private web server configuration was not found: $httpdConfig"
}

$currentConfig = Get-Content -LiteralPath $httpdConfig -Raw
if (($currentConfig -notmatch [regex]::Escape($configStart)) -and ($currentConfig -notmatch '<Location\s+/meuportal/>')) {
    $portalConfig = Get-Content -LiteralPath $configTemplate -Raw
    Add-Content -LiteralPath $httpdConfig -Value "`r`n$configStart`r`n$portalConfig`r`n$configEnd`r`n"
}

& $httpdExecutable -t -f (Join-Path $IrisInstallDir 'httpd\conf\httpd.conf')
if ($LASTEXITCODE -ne 0) { throw 'The private web server configuration is invalid.' }

if (-not $SkipWebServerRestart) {
    $restarted = $false
    try {
        Restart-Service -Name 'IRIShttpd' -ErrorAction Stop
        $restarted = $true
    } catch {
        Write-Host 'The IRIShttpd Windows service did not restart cleanly; falling back to "iris stop"/"iris start" (this also restarts the private web server, and is known to work even when the service does not).' -ForegroundColor Yellow
    }
    if (-not $restarted) {
        & $irisExecutable stop $Instance quietly
        & $irisExecutable start $Instance
    }
} else {
    Write-Host 'Skipped web server restart (-SkipWebServerRestart). The new files will only be served after a manual restart.'
}

Write-Host 'Frontend installed.' -ForegroundColor Green

Write-Host '== Step 3/3: Backend (needs your IRIS login — this script does not store or type it for you) ==' -ForegroundColor Cyan
Write-Host "This assumes the '$Namespace' namespace already exists (create it once in the Management Portal: System Administration > Configuration > System Configuration > Namespaces > New Namespace, if you have not yet)."
Write-Host ''

$backendCommands = @"
zn "$Namespace"
Do `$System.OBJ.LoadDir("$sourceDir", "ck", , 1)
Set status = ##class(MeuPortal.Installer).Setup()
Write "Meu Portal installer status: ", `$System.Status.GetErrorText(status), !
"@

Write-Host 'Paste these lines into the IRIS terminal window (opening now), then press Enter after the last line:' -ForegroundColor Yellow
Write-Host '----------------------------------------------------------------------'
Write-Host $backendCommands
Write-Host '----------------------------------------------------------------------'

if (-not $SkipBackendPrompt) {
    Start-Process -FilePath $irisExecutable -ArgumentList "session $Instance"
} else {
    Write-Host 'Skipped opening the terminal automatically (-SkipBackendPrompt). Run the lines above yourself in an IRIS terminal.'
}

Write-Host ''
Write-Host 'Once the backend command above finishes without an error, open http://localhost:52773/meuportal/ and sign in.' -ForegroundColor Green
Write-Host 'First time only: grant yourself (or whichever account should use Meu Portal) the MeuPortalAdministrator role — see "Signing in" in docs/REFERENCE.md, or sign in with _SYSTEM, which already works.' -ForegroundColor Green
