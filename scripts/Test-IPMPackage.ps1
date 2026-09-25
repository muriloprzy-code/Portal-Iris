[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $projectRoot 'module.xml'
$sourceRoot = Join-Path $projectRoot 'src\objectscript'
$webRoot = Join-Path $projectRoot 'web'

[xml]$manifest = Get-Content -LiteralPath $manifestPath
$module = $manifest.Export.Document.Module

if ($manifest.Export.Document.name -ne 'myown-portal.ZPM') {
    throw 'The IPM document name must be myown-portal.ZPM.'
}
if ($module.Name -ne 'myown-portal') {
    throw 'The IPM module name must be myown-portal.'
}
if ($module.SourcesRoot -ne 'src/objectscript') {
    throw 'The IPM SourcesRoot does not point to the ObjectScript source directory.'
}
if ($module.Resource.Name -notcontains 'MyOwn.PKG') {
    throw 'The MyOwn.PKG resource is missing from module.xml.'
}
if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot 'MyOwn\Installer.cls'))) {
    throw 'MyOwn.Installer is missing.'
}
if (-not (Test-Path -LiteralPath (Join-Path $webRoot 'index.html'))) {
    throw 'The packaged frontend is missing. Run scripts\Build-IPMPackage.ps1.'
}

$assetReferences = Select-String -LiteralPath (Join-Path $webRoot 'index.html') -Pattern '/myown/assets/[^"'']+' -AllMatches
if ($assetReferences.Matches.Count -lt 2) {
    throw 'The packaged index does not reference the expected JavaScript and CSS assets.'
}
foreach ($match in $assetReferences.Matches) {
    $relativePath = $match.Value.Substring('/myown/'.Length).Replace('/', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath (Join-Path $webRoot $relativePath))) {
        throw "Packaged frontend asset '$relativePath' is missing."
    }
}

$classCount = (Get-ChildItem -LiteralPath $sourceRoot -Filter '*.cls' -Recurse).Count
Write-Host "IPM manifest valid: $($module.Name) $($module.Version)" -ForegroundColor Green
Write-Host "ObjectScript classes included by MyOwn.PKG: $classCount" -ForegroundColor Green
Write-Host "Compiled frontend assets verified: $($assetReferences.Matches.Count)" -ForegroundColor Green
