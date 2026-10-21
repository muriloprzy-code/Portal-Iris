[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$requiredFiles = @(
    'Dockerfile',
    'compose.yaml',
    'compose.aihub.yaml',
    '.dockerignore',
    'docker\merge.cpf',
    'docker\iris.script',
    'docker\start-iris.sh',
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
$start = Get-Content -LiteralPath (Join-Path $projectRoot 'docker\start-iris.sh') -Raw
[xml]$manifest = Get-Content -LiteralPath (Join-Path $projectRoot 'module.xml')

$checks = [ordered]@{
    'AI Hub Community build 154' = ($dockerfile -match '2026\.3\.0AI\.154\.0') -and ($compose -match '2026\.3\.0AI\.154\.0')
    'CPF initialization' = $dockerfile -match 'ISC_CPF_MERGE_FILE'
    'IPM bootstrap' = $dockerfile -match '/tmp/zpm\.xml'
    'MYOWN namespace' = $merge -match 'CreateNamespace:Name=MYOWN'
    # The production classes extend Ens.*; they only compile in an interoperability-enabled namespace.
    # EnableNamespace (not Interop=1, which makes an IRIS for Health Foundation namespace with its own production).
    'MYOWN interoperability' = ($merge -match 'CreateNamespace:Name=MYOWN[^\r\n]*Interop=0') -and ($init -match '(?s)EnableNamespace\("MYOWN".*zpm "load')
    'IPM package load' = $init -match 'zpm "load /home/irisowner/dev -v"'
    'Non-interactive password bootstrap' = ($dockerfile -match 'MYOWN_DEMO_PASSWORD') -and ($start -match '--password-file') -and ($start -match 'iris\.cpf') -and ($start -match 'CSPpwd')
    'Web port mapping' = $compose -match '52774.*:52773'
    'Durable IRIS data' = ($compose -match 'ISC_DATA_DIRECTORY: /durable/iris') -and ($compose -match 'myown-portal-data:/durable')
    'AI provider environment' = ($compose -match 'MYOWN_AI_API_KEY') -and ($compose -match 'MYOWN_AI_PROVIDER') -and ($compose -match 'MYOWN_AI_MODEL')
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
