[CmdletBinding()]
param(
    [string]$PackageManager
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$frontendRoot = Join-Path $projectRoot 'frontend'
$distributionRoot = Join-Path $frontendRoot 'dist'
$packageWebRoot = Join-Path $projectRoot 'web'

if ([string]::IsNullOrWhiteSpace($PackageManager)) {
    $packageManagerCommand = Get-Command pnpm -ErrorAction SilentlyContinue
    if (-not $packageManagerCommand) {
        $packageManagerCommand = Get-Command npm -ErrorAction SilentlyContinue
    }
    if (-not $packageManagerCommand) {
        throw 'npm or pnpm is required to build the frontend.'
    }
    $PackageManager = $packageManagerCommand.Source
}
elseif (-not (Test-Path -LiteralPath $PackageManager)) {
    $packageManagerCommand = Get-Command $PackageManager -ErrorAction SilentlyContinue
    if (-not $packageManagerCommand) {
        throw "The package manager '$PackageManager' was not found."
    }
    $PackageManager = $packageManagerCommand.Source
}

Push-Location $frontendRoot
try {
    if (-not (Test-Path -LiteralPath (Join-Path $frontendRoot 'node_modules'))) {
        & $PackageManager install
        if ($LASTEXITCODE -ne 0) {
            throw 'Frontend dependency installation failed.'
        }
    }

    & $PackageManager run build
    if ($LASTEXITCODE -ne 0) {
        throw 'The frontend build failed.'
    }
}
finally {
    Pop-Location
}

if (-not (Test-Path -LiteralPath $distributionRoot)) {
    throw "The frontend distribution was not created at '$distributionRoot'."
}

New-Item -ItemType Directory -Path $packageWebRoot -Force | Out-Null
Get-ChildItem -LiteralPath $packageWebRoot -Force |
    Where-Object { $_.Name -ne '.gitkeep' } |
    Remove-Item -Recurse -Force
Copy-Item -Path (Join-Path $distributionRoot '*') -Destination $packageWebRoot -Recurse -Force

[xml]$manifest = Get-Content -LiteralPath (Join-Path $projectRoot 'module.xml')
if ($manifest.Export.Document.Module.Name -ne 'meu-portal') {
    throw 'module.xml does not define the expected meu-portal package.'
}

Write-Host "IPM package assets are ready in '$packageWebRoot'." -ForegroundColor Green
Write-Host "Load the package from MEUPORTAL with: zpm `"load $projectRoot`"" -ForegroundColor Cyan
