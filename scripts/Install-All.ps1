<#
.SYNOPSIS
One-click installer for MyOwn Portal. Detects whether to use Docker or an
existing local IRIS installation and automates everything it safely can.

.DESCRIPTION
This script is meant to be started by double-clicking Instalar.bat at the
project root, not run by hand. It:

  1. Detects Docker Desktop and/or a local IRIS installation.
  2. If both are available, asks once which to use. If only one is
     available, uses it automatically.
  3. Docker path: builds and starts the container, waits for it to become
     healthy, and opens the browser - fully automatic, no manual step.
  4. Native path: checks the MYOWN namespace, builds the frontend
     (downloading a local copy of Node.js first if needed), deploys the
     files, and restarts the private web server automatically. The backend
     install (loading and compiling ObjectScript, running the installer)
     is also automatic: it uses IRIS's built-in Atelier REST API (the same
     mechanism the VS Code ObjectScript extension uses) instead of an
     interactive terminal. You are asked once, right here, for your IRIS
     username and password - they are used only for these HTTP calls and
     are never written to disk, logged, or sent anywhere else. Once that
     is done, it opens the browser.

If anything cannot be done safely without a person's judgment (for example,
the MYOWN namespace not existing yet), the script stops and explains
exactly what to do, instead of guessing.
#>
[CmdletBinding()]
param(
    [string]$IrisInstallDir,
    [string]$Instance,
    [string]$Namespace = 'MYOWN'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

function Write-Step($text) {
    Write-Host ''
    Write-Host "== $text ==" -ForegroundColor Cyan
}

function Write-Ok($text) {
    Write-Host $text -ForegroundColor Green
}

function Write-Warn2($text) {
    Write-Host $text -ForegroundColor Yellow
}

function Fail($text) {
    Write-Host ''
    Write-Host "ERROR: $text" -ForegroundColor Red
    Write-Host ''
    Write-Host 'Installation stopped. No changes beyond what is listed above were made.' -ForegroundColor Red
    Read-Host 'Press Enter to close this window'
    exit 1
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Magenta
Write-Host '   MyOwn Portal - one-click installer' -ForegroundColor Magenta
Write-Host '========================================' -ForegroundColor Magenta

# ---------------------------------------------------------------------------
# Step 1: detect what is available
# ---------------------------------------------------------------------------
Write-Step 'Checking what is installed on this computer'

$dockerAvailable = $false
try {
    docker version --format '{{.Server.Version}}' *> $null
    if ($LASTEXITCODE -eq 0) {
        docker compose version *> $null
        if ($LASTEXITCODE -eq 0) { $dockerAvailable = $true }
    }
} catch { $dockerAvailable = $false }

if ($dockerAvailable) {
    Write-Ok 'Docker Desktop: found and running.'
} else {
    Write-Host 'Docker Desktop: not found (or not running).'
}

$candidateDirs = New-Object System.Collections.Generic.List[string]
if ($IrisInstallDir) { $candidateDirs.Add($IrisInstallDir) }
$candidateDirs.Add('C:\InterSystems\IRIS')
$candidateDirs.Add('D:\InterSystems\IRIS')
foreach ($root in @('C:\InterSystems', 'D:\InterSystems')) {
    if (Test-Path -LiteralPath $root) {
        Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $candidateDirs.Add($_.FullName)
        }
    }
}

$resolvedIrisDir = $null
foreach ($dir in ($candidateDirs | Select-Object -Unique)) {
    $exe = Join-Path $dir 'bin\iris.exe'
    if (Test-Path -LiteralPath $exe) { $resolvedIrisDir = $dir; break }
}

if ($resolvedIrisDir) {
    Write-Ok "Local IRIS installation: found at $resolvedIrisDir."
} else {
    Write-Host 'Local IRIS installation: not found in the usual locations.'
}

if (-not $dockerAvailable -and -not $resolvedIrisDir) {
    Fail "Neither Docker Desktop nor a local IRIS installation was found.`n`nInstall one of the two:`n  - Docker Desktop: https://www.docker.com/products/docker-desktop/ (fastest way to try MyOwn Portal)`n  - InterSystems IRIS Community Edition, if you want to install onto a real instance.`n`nThen run this installer again."
}

# ---------------------------------------------------------------------------
# Step 2: choose a path
# ---------------------------------------------------------------------------
$useDocker = $false
if ($dockerAvailable -and $resolvedIrisDir) {
    Write-Host ''
    Write-Host 'Both Docker and a local IRIS installation were found. Choose how to install MyOwn Portal:'
    Write-Host '  [1] Docker  - fastest, a brand-new disposable IRIS, only demo data (recommended to just try it out)'
    Write-Host '  [2] Local IRIS - installs onto the IRIS you already have, shows your real users, roles, tasks, and logs'
    $choice = Read-Host 'Type 1 or 2 and press Enter (default: 1)'
    if ($choice -eq '2') { $useDocker = $false } else { $useDocker = $true }
} elseif ($dockerAvailable) {
    $useDocker = $true
    Write-Host 'Only Docker was found - using it automatically.'
} else {
    $useDocker = $false
    Write-Host 'Only a local IRIS installation was found - using it automatically.'
}

# ---------------------------------------------------------------------------
# Path A: Docker
# ---------------------------------------------------------------------------
if ($useDocker) {
    Write-Step 'Building and starting the Docker container (this can take a few minutes the first time)'
    docker compose up --build -d
    if ($LASTEXITCODE -ne 0) { Fail 'docker compose failed. Scroll up for the error from Docker.' }

    Write-Step 'Waiting for the instance to become healthy'
    $healthy = $false
    for ($i = 0; $i -lt 40; $i++) {
        $status = docker inspect --format '{{.State.Health.Status}}' myown-portal-iris 2>$null
        if ($status -match 'healthy') { $healthy = $true; break }
        Start-Sleep -Seconds 5
        Write-Host '.' -NoNewline
    }
    Write-Host ''
    if (-not $healthy) {
        Write-Warn2 'The container did not report healthy within the expected time, but it may still finish starting up. Opening the browser anyway - if the page does not load yet, wait a minute and refresh.'
    } else {
        Write-Ok 'Instance is healthy.'
    }

    $demoPassword = 'ChangeMe2026!'
    if (Test-Path -LiteralPath '.env') {
        $envLine = Get-Content -LiteralPath '.env' | Where-Object { $_ -match '^\s*MYOWN_DEMO_PASSWORD\s*=' }
        if ($envLine) { $demoPassword = ($envLine -split '=', 2)[1].Trim() }
    }

    Start-Process 'http://localhost:52774/myown/index.html'

    Write-Host ''
    Write-Ok 'Done! MyOwn Portal should now be open in your browser.'
    Write-Host "Sign in with username _SYSTEM and password $demoPassword"
    Write-Host 'To stop it later: docker compose down (add -v to also delete the demo data).'
    Read-Host 'Press Enter to close this window'
    exit 0
}

# ---------------------------------------------------------------------------
# Path B: local IRIS
# ---------------------------------------------------------------------------
if (-not $Instance) {
    $Instance = (Split-Path -Leaf $resolvedIrisDir)
    if (-not $Instance) { $Instance = 'IRIS' }
}
$IrisInstallDir = $resolvedIrisDir
$irisExecutable = Join-Path $IrisInstallDir 'bin\iris.exe'
$httpdExecutable = Join-Path $IrisInstallDir 'httpd\bin\httpd.exe'
$httpdConfig = Join-Path $IrisInstallDir 'httpd\conf\httpd-local.conf'
$sourceDir = Join-Path $projectRoot 'src\objectscript'
$frontendDir = Join-Path $projectRoot 'frontend'
$distDir = Join-Path $frontendDir 'dist'
$targetDir = Join-Path $IrisInstallDir 'CSP\myown'
$configTemplate = Join-Path $projectRoot 'deploy\httpd-myown.conf'
$configStart = '# BEGIN MYOWN PORTAL'
$configEnd = '# END MYOWN PORTAL'

# Check for administrator rights - needed to restart the private web server.
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Fail 'This step needs administrator rights (to restart the IRIS private web server). Right-click Instalar.bat and choose "Run as administrator", or approve the permission prompt if one appeared.'
}

Write-Step 'Choosing the IRIS namespace'
Write-Host "By default, MyOwn Portal installs into its own namespace (keeps its classes, security roles and tables separate from anything else on this instance)."
$namespaceChoice = Read-Host "Type the namespace to install into, or press Enter for the default ('$Namespace')"
if ($namespaceChoice) { $Namespace = $namespaceChoice.Trim() }

Write-Step "Checking the '$Namespace' namespace"
# Read iris.cpf directly instead of opening an IRIS terminal for this check -
# iris.exe's session/console commands always open a real, separately
# authenticated console on this system (confirmed live), so they cannot be
# used for a silent pre-check. The .cpf file is plain text and needs no
# login.
$cpfPath = Join-Path $IrisInstallDir 'iris.cpf'
if (Test-Path -LiteralPath $cpfPath) {
    $cpfLines = Get-Content -LiteralPath $cpfPath
    $inNamespaces = $false
    $namespaceExists = $false
    foreach ($line in $cpfLines) {
        $t = $line.Trim()
        if ($t -match '^\[(.+)\]$') {
            $inNamespaces = ($Matches[1] -eq 'Namespaces')
            continue
        }
        if ($inNamespaces -and $t -match ('^' + [regex]::Escape($Namespace) + '\s*=')) {
            $namespaceExists = $true
            break
        }
    }
    if (-not $namespaceExists) {
        Fail "The '$Namespace' namespace does not exist yet on this IRIS instance. This is a one-time, 30-second step: open the Management Portal (http://localhost:52773/csp/sys/UtilHome.csp) and go to System Administration > Configuration > System Configuration > Namespaces > New Namespace, create '$Namespace' with the default database settings, then run this installer again."
    }
    Write-Ok "Namespace '$Namespace' exists."
} else {
    Write-Warn2 "Could not read $cpfPath to check the namespace in advance - continuing anyway; the backend step later will show clearly if '$Namespace' still needs to be created."
}

Write-Step 'Preparing the frontend build tools'
$env:PATH = "$projectRoot\.tools\node;$env:PATH"
$haveNode = $null -ne (Get-Command node -ErrorAction SilentlyContinue)
if (-not $haveNode) {
    Write-Host 'Node.js was not found on PATH. Downloading a local, admin-rights-free copy just for this build...'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $toolsDir = Join-Path $projectRoot '.tools'
    New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
    $json = Invoke-RestMethod -Uri 'https://nodejs.org/dist/index.json'
    $lts = $json | Where-Object { $_.lts -ne $false } | Select-Object -First 1
    $version = $lts.version
    $url = "https://nodejs.org/dist/$version/node-$version-win-x64.zip"
    $zipPath = Join-Path $toolsDir 'node.zip'
    Invoke-WebRequest -Uri $url -OutFile $zipPath
    Expand-Archive -Path $zipPath -DestinationPath $toolsDir -Force
    $extracted = Join-Path $toolsDir ('node-' + $version + '-win-x64')
    $target = Join-Path $toolsDir 'node'
    if (Test-Path $target) { Remove-Item $target -Recurse -Force }
    Rename-Item -Path $extracted -NewName 'node'
    Remove-Item $zipPath -Force
    $env:PATH = "$target;$env:PATH"
    Write-Ok "Node.js $version ready (local copy, not installed system-wide)."
} else {
    Write-Ok 'Node.js found on PATH.'
}

Write-Step 'Building the frontend (this can take a minute)'
Push-Location $frontendDir
try {
    if (-not (Test-Path -LiteralPath (Join-Path $frontendDir 'node_modules'))) {
        npm install
        if ($LASTEXITCODE -ne 0) { Fail 'npm install failed. Scroll up for the error.' }
    }
    npm run build
    if ($LASTEXITCODE -ne 0) { Fail 'The frontend build failed. Scroll up for the error.' }
} finally {
    Pop-Location
}
if (-not (Test-Path -LiteralPath (Join-Path $distDir 'index.html'))) {
    Fail 'frontend/dist/index.html was not created by the build.'
}
Write-Ok 'Frontend built.'

Write-Step 'Deploying the frontend and restarting the private web server'
New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
$targetAssets = Join-Path $targetDir 'assets'
if (Test-Path -LiteralPath $targetAssets) { Remove-Item -LiteralPath $targetAssets -Recurse -Force }
New-Item -ItemType Directory -Path $targetAssets -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $distDir 'index.html') -Destination $targetDir -Force
Copy-Item -Path (Join-Path $distDir 'assets\*') -Destination $targetAssets -Force
# Vite also places public/ assets (logos, favicon) directly at the root of dist/,
# alongside index.html rather than inside assets/ - copy those too, or the
# page ends up with broken images.
Get-ChildItem -LiteralPath $distDir -File | Where-Object { $_.Name -ne 'index.html' } | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $targetDir -Force
}

if (-not (Test-Path -LiteralPath $httpdConfig)) {
    Fail "IRIS private web server configuration was not found: $httpdConfig"
}
$currentConfig = Get-Content -LiteralPath $httpdConfig -Raw
if (($currentConfig -notmatch [regex]::Escape($configStart)) -and ($currentConfig -notmatch '<Location\s+/myown/>')) {
    $portalConfig = Get-Content -LiteralPath $configTemplate -Raw
    Add-Content -LiteralPath $httpdConfig -Value "`r`n$configStart`r`n$portalConfig`r`n$configEnd`r`n"
}

& $httpdExecutable -t -f (Join-Path $IrisInstallDir 'httpd\conf\httpd.conf')
if ($LASTEXITCODE -ne 0) { Fail 'The private web server configuration is invalid.' }

$restarted = $false
try {
    Restart-Service -Name 'IRIShttpd' -ErrorAction Stop
    $restarted = $true
} catch {
    Write-Warn2 'The IRIShttpd Windows service did not restart cleanly; falling back to "iris stop"/"iris start".'
}
if (-not $restarted) {
    & $irisExecutable stop $Instance quietly
    & $irisExecutable start $Instance
}
Write-Ok 'Frontend deployed and web server restarted.'

Write-Step 'Installing the backend'
# iris.exe's session/console commands always open a real, separately authenticated
# console window on this system (confirmed live) that cannot receive piped input, so
# it cannot be scripted without also handling your password, which this script will
# not do by typing it into a terminal for you. Instead, this step uses IRIS's own
# Atelier REST API (already built into the instance, no setup needed - it is the same
# mechanism the VS Code ObjectScript extension uses) to load and compile the code and
# run the installer over HTTP. Your IRIS username and password are asked for once,
# right here, used only for these HTTP calls, and are never written to disk or sent
# anywhere else.
$mgmtBaseUrl = 'http://localhost:52773'
$cred = Get-Credential -Message 'Digite seu usuario e senha do IRIS (usados so para esta instalacao, nunca sao salvos)' -UserName '_SYSTEM'
$pair = $cred.UserName + ':' + $cred.GetNetworkCredential().Password
$authHeader = @{ Authorization = 'Basic ' + [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($pair)) }
Remove-Variable pair

function Invoke-Atelier {
    param($Method, $Path, $Body, $ContentType)
    # Using [System.Net.HttpWebRequest] directly instead of Invoke-RestMethod: on
    # Windows PowerShell 5.1, Invoke-RestMethod silently appends "; charset=utf-8"
    # to whatever -ContentType is given, and the Atelier API's PUT route matches
    # Content-Type literally against "text/plain" with no charset suffix - that
    # mismatch was causing 415s no matter what -ContentType value was passed in.
    # HttpWebRequest.ContentType is set exactly as assigned, with no rewriting.
    $uri = "$mgmtBaseUrl/api/atelier$Path"
    $request = [System.Net.HttpWebRequest]::Create($uri)
    $request.Method = $Method
    $request.Headers.Add('Authorization', $authHeader.Authorization)
    $request.Accept = 'application/json'
    $request.Timeout = 60000
    # The pattern seen live - requests succeed, then the 4th one in a row comes back
    # with a docname corrupted into a fragment of an earlier request's query string -
    # matches the IRIS private web server's known keep-alive/connection-reuse bugs.
    # A fresh TCP connection per call avoids it entirely.
    $request.KeepAlive = $false
    if ($null -ne $Body) {
        $request.ContentType = $ContentType
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
        $request.ContentLength = $bytes.Length
        $requestStream = $request.GetRequestStream()
        $requestStream.Write($bytes, 0, $bytes.Length)
        $requestStream.Close()
    }
    try {
        $response = $request.GetResponse()
    } catch [System.Net.WebException] {
        $errorResponse = $_.Exception.Response
        if ($errorResponse) {
            $reader = New-Object System.IO.StreamReader($errorResponse.GetResponseStream())
            $errorText = $reader.ReadToEnd()
            $reader.Close()
            $errorResponse.Close()
            throw "$($_.Exception.Message) - $errorText"
        }
        throw
    }
    $responseStream = $response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($responseStream)
    $text = $reader.ReadToEnd()
    $reader.Close()
    $response.Close()
    if ($text) {
        try { return $text | ConvertFrom-Json } catch { return $text }
    }
    return $null
}

try {
    Invoke-Atelier -Method 'GET' -Path '/' | Out-Null
} catch {
    Fail "Nao foi possivel falar com a API do IRIS em $mgmtBaseUrl/api/atelier - confirme o usuario e a senha, e que a instancia IRIS esta rodando. Detalhe: $($_.Exception.Message)"
}

# Uploading every backend file one by one through the Atelier API's doc-put
# endpoint proved unreliable on this system (a request a few files into the batch
# would consistently come back with a corrupted document name). So instead, only
# this single class is uploaded over HTTP; it then tells the IRIS server process
# to load every other file directly off local disk (via $System.OBJ.LoadDir,
# exactly like the original, proven terminal-based install script did) - no
# further HTTP file transfer involved for the rest of the backend.
Write-Host 'Enviando o instalador para o IRIS...'
$installerRelativePath = Join-Path 'MyOwn' 'Installer.cls'
$installerFullPath = Join-Path $sourceDir $installerRelativePath
$installerContent = Get-Content -LiteralPath $installerFullPath -Raw
$installerLines = @($installerContent -split "`r`n|`r|`n")
$installerPutBody = @{ enc = $false; content = $installerLines } | ConvertTo-Json -Depth 5 -Compress
try {
    Invoke-Atelier -Method 'PUT' -Path "/v1/$Namespace/doc/MyOwn.Installer.cls?ignoreConflict=1" -Body $installerPutBody -ContentType 'application/json' | Out-Null
} catch {
    Fail "Falha ao enviar o instalador para o IRIS. Detalhe: $($_.Exception.Message)"
}
try {
    $compileResult = Invoke-Atelier -Method 'POST' -Path "/v1/$Namespace/action/compile?flags=ck" -Body '["MyOwn.Installer.cls"]' -ContentType 'application/json'
} catch {
    Fail "Falha ao compilar o instalador. Detalhe: $($_.Exception.Message)"
}
if ($compileResult.status.errors -and $compileResult.status.errors.Count -gt 0) {
    Fail ("Erros ao compilar o instalador:`n" + ($compileResult.status.errors -join "`n"))
}
Write-Ok 'Instalador enviado.'

Write-Host 'Carregando o restante do backend direto do disco e executando o instalador...'
try {
    $loadQueryBody = @{ query = 'SELECT MyOwn.MyOwnLoadAndSetup(?) AS Result'; parameters = @($sourceDir) } | ConvertTo-Json
    $loadResult = Invoke-Atelier -Method 'POST' -Path "/v1/$Namespace/action/query" -Body $loadQueryBody -ContentType 'application/json'
} catch {
    Fail "Falha ao carregar/instalar o backend. Detalhe: $($_.Exception.Message)"
}
if ($loadResult.status.errors -and $loadResult.status.errors.Count -gt 0) {
    Fail ("Erro ao carregar/instalar o backend:`n" + ($loadResult.status.errors -join "`n"))
}
$loadStatusText = $null
if ($loadResult.result.content -and $loadResult.result.content.Count -gt 0) {
    $loadStatusText = $loadResult.result.content[0].Result
}
if ($loadStatusText -and $loadStatusText -ne 'OK') {
    Fail "O carregamento/instalacao do backend reportou um erro: $loadStatusText"
}
Write-Ok 'Backend instalado.'

Start-Process 'http://localhost:52773/myown/index.html'

Write-Host ''
Write-Ok 'Done! MyOwn Portal should now be open in your browser.'
Write-Host 'Sign in with _SYSTEM, or grant your own account the MyOwnAdministrator role first (see "Signing in" in docs/REFERENCE.md).'
Read-Host 'Press Enter to close this window'
exit 0
