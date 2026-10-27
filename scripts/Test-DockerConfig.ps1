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
    'docker\demo-start.sh',
    'module.xml',
    'aihub\src\MyOwn\AIHub\Engine.cls',
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
    # One module, in developer mode so the test classes the scripts use are loaded too.
    'IPM package load' = $init -match 'zpm "load /home/irisowner/dev -v -dev"'
    # Scope="test" resources are not loaded by -dev; the image loads them and the install check requires them.
    'Test classes in the image' = ($init -match 'LoadDir\("/home/irisowner/dev/src/objectscript/MyOwn/Test/"') -and ((Get-Content -LiteralPath (Join-Path $projectRoot 'docker\finish-build.script') -Raw) -match 'MyOwn\.Test\.AgentCore')
    # The AI Hub engine is part of the module, compiled by the installer only where %AI exists.
    'AI Hub engine in the module' = (@($manifest.Export.Document.Module.Invoke) | Where-Object Method -eq 'LoadAIHub') -and ($init -notmatch 'dev/aihub')
    'Non-interactive password bootstrap' = ($dockerfile -match 'MYOWN_DEMO_PASSWORD') -and ($start -match '--password-file') -and ($start -match 'iris\.cpf') -and ($start -match 'CSPpwd')
    # Demo settings (MYOWN_DEMO_*) are applied after every start; the demo password is never in the image.
    'Demo setup after start' = ($start -match '-a "\$\{after_start\}"') -and ($start -match 'demo-start\.sh') -and ($compose -match 'MYOWN_DEMO_MODE') -and ($dockerfile -notmatch 'MYOWN_DEMO_USER_PASSWORD')
    # An incomplete install fails the build and never starts silently.
    'Install completion check' = ($dockerfile -match 'install-complete') -and ($start -match 'install-complete') -and ((Get-Content -LiteralPath (Join-Path $projectRoot 'docker\finish-build.script') -Raw) -match 'install-complete')
    'Web port mapping' = $compose -match '52774.*:52773'
    'Durable IRIS data' = ($compose -match 'ISC_DATA_DIRECTORY: /durable/iris') -and ($compose -match 'myown-portal-data:/durable')
    'AI provider environment' = ($compose -match 'MYOWN_AI_API_KEY') -and ($compose -match 'MYOWN_AI_PROVIDER') -and ($compose -match 'MYOWN_AI_MODEL') -and ($compose -match 'MYOWN_AI_MODE') -and ($compose -match 'MYOWN_AI_TIMEOUT_SECONDS')
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
