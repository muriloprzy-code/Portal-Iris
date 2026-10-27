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
# One module: every package and top-level class under MyOwn is a resource, the tests only in the test scope.
$resources = @($module.Resource)
foreach ($item in Get-ChildItem -LiteralPath (Join-Path $sourceRoot 'MyOwn')) {
    $expected = if ($item.PSIsContainer) { "MyOwn.$($item.Name).PKG" } else { "MyOwn.$($item.BaseName).CLS" }
    $resource = $resources | Where-Object Name -eq $expected
    if (-not $resource) { throw "module.xml has no resource for $expected." }
    if (($item.Name -eq 'Test') -ne ($resource.Scope -eq 'test')) { throw "$expected must be in the test scope only if it is the test package." }
}
if ((($resources | Where-Object Name -eq 'MyOwn.Bootstrap.CLS').Preload -ne 'true') -or -not (Test-Path -LiteralPath (Join-Path $projectRoot 'preload\cls\MyOwn\Bootstrap.cls'))) {
    throw 'MyOwn.Bootstrap must be preloaded from preload/: it enables interoperability before the Ens-based classes compile.'
}
$invokes = @($module.Invoke)
foreach ($method in 'EnableInteroperability', 'LoadAIHub', 'Setup', 'Unconfigure') {
    if (-not ($invokes | Where-Object Method -eq $method)) { throw "module.xml does not invoke $method." }
}
if (-not (@($module.FileCopy) | Where-Object Name -eq 'aihub/src/')) { throw 'The AI Hub sources (aihub/src/) are not copied into the package.' }
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'aihub\src\MyOwn\AIHub\Engine.cls'))) { throw 'The AI Hub sources are missing.' }
if (Test-Path -LiteralPath (Join-Path $projectRoot 'aihub\module.xml')) { throw 'aihub/module.xml must not exist: the AI Hub engine is part of myown-portal.' }
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

$classCount = @(Get-ChildItem -LiteralPath $sourceRoot -Filter '*.cls' -Recurse | Where-Object { $_.FullName -notmatch '\\MyOwn\\Test\\' }).Count
$testCount = @(Get-ChildItem -LiteralPath (Join-Path $sourceRoot 'MyOwn\Test') -Filter '*.cls').Count
$aihubCount = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'aihub\src') -Filter '*.cls' -Recurse | Where-Object { $_.FullName -notmatch '\\AIHub\\Test\\' }).Count
Write-Host "IPM manifest valid: $($module.Name) $($module.Version)" -ForegroundColor Green
Write-Host "Core classes: $classCount; test classes (developer mode only): $testCount; AI Hub classes (where %AI exists): $aihubCount" -ForegroundColor Green
Write-Host "Compiled frontend assets verified: $($assetReferences.Matches.Count)" -ForegroundColor Green
