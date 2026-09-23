[CmdletBinding()]
param(
    [string]$IrisInstallDir = 'C:\InterSystems\IRIS',
    [switch]$SkipBuild,
    [switch]$SkipWebServerRestart
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$frontendDir = Join-Path $projectRoot 'frontend'
$distDir = Join-Path $frontendDir 'dist'
$targetDir = Join-Path $IrisInstallDir 'CSP\meuportal'
$httpdConfig = Join-Path $IrisInstallDir 'httpd\conf\httpd-local.conf'
$httpdExecutable = Join-Path $IrisInstallDir 'httpd\bin\httpd.exe'
$configTemplate = Join-Path $projectRoot 'deploy\httpd-meuportal.conf'
$configStart = '# BEGIN MEU PORTAL'
$configEnd = '# END MEU PORTAL'

if (-not (Test-Path -LiteralPath $IrisInstallDir)) {
    throw "IRIS installation directory was not found: $IrisInstallDir"
}

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
}

if (-not (Test-Path -LiteralPath (Join-Path $distDir 'index.html'))) {
    throw 'frontend/dist/index.html was not found. Run the build first.'
}

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
    Restart-Service -Name 'IRIShttpd'
}

Write-Host 'Frontend installation completed.' -ForegroundColor Green
Write-Host 'Import and compile src/objectscript in the MEUPORTAL namespace, then run:'
Write-Host '  Do ##class(MeuPortal.Installer).Setup()'
Write-Host 'Portal URL: http://localhost:52773/meuportal/'
