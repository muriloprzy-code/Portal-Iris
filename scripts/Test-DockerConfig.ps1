[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$requiredFiles = @(
    'Dockerfile',
    'compose.yaml',
    '.dockerignore',
    'docker\merge.cpf',
    'docker\iris.script',
    'module.xml',
    'web\index.html'
)

foreach ($relativePath in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot $relativePath))) {
        throw "Required Docker file '$relativePath' is missing."
    }
}

$dockerfile = Get-Content -LiteralPath (Join-Path $projectRoot 'Dockerfile') -Raw
$compose = Get-Content -LiteralPath (Join-Path $projectRoot 'compose.yaml') -Raw
$merge = Get-Content -LiteralPath (Join-Path $projectRoot 'docker\merge.cpf') -Raw
$init = Get-Content -LiteralPath (Join-Path $projectRoot 'docker\iris.script') -Raw
[xml]$manifest = Get-Content -LiteralPath (Join-Path $projectRoot 'module.xml')

$checks = [ordered]@{
    'Community IRIS image' = $dockerfile -match 'intersystems/iris-community'
    'CPF initialization' = $dockerfile -match 'ISC_CPF_MERGE_FILE'
    'IPM bootstrap' = $dockerfile -match '/tmp/zpm\.xml'
    'MEUPORTAL namespace' = $merge -match 'CreateNamespace:Name=MEUPORTAL'
    'IPM package load' = $init -match 'zpm "load /home/irisowner/dev -v"'
    'Administrative login initialization' = $init -match 'UnExpireUserPasswords\("_SYSTEM"\)'
    'Web port mapping' = $compose -match '52774.*:52773'
    'Durable IRIS data' = ($compose -match 'ISC_DATA_DIRECTORY: /durable/iris') -and ($compose -match 'meu-portal-data:/durable')
    'Static web application' = $null -ne $manifest.Export.Document.Module.WebApplication
}

$failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value })
if ($failed.Count -gt 0) {
    throw "Docker configuration checks failed: $($failed.Name -join ', ')"
}

$checks.GetEnumerator() | ForEach-Object {
    Write-Host "PASS  $($_.Name)" -ForegroundColor Green
}
Write-Host 'Docker configuration is complete.' -ForegroundColor Green
