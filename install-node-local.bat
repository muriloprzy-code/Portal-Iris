@echo off
setlocal
cd /d "%~dp0"
set "LOG=%~dp0.tools\install-node.log"
if not exist ".tools" mkdir ".tools"
echo ==START== > "%LOG%"
echo %date% %time% >> "%LOG%"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;" ^
  "$dest = Join-Path (Get-Location) '.tools';" ^
  "Write-Output ('DEST=' + $dest);" ^
  "$json = Invoke-RestMethod -Uri 'https://nodejs.org/dist/index.json';" ^
  "$lts = $json | Where-Object { $_.lts -ne $false } | Select-Object -First 1;" ^
  "$version = $lts.version;" ^
  "Write-Output ('VERSION=' + $version);" ^
  "$url = \"https://nodejs.org/dist/$version/node-$version-win-x64.zip\";" ^
  "Write-Output ('URL=' + $url);" ^
  "$zipPath = Join-Path $dest 'node.zip';" ^
  "Invoke-WebRequest -Uri $url -OutFile $zipPath;" ^
  "Write-Output 'DOWNLOAD_OK';" ^
  "Expand-Archive -Path $zipPath -DestinationPath $dest -Force;" ^
  "Write-Output 'EXTRACT_OK';" ^
  "$extracted = Join-Path $dest ('node-' + $version + '-win-x64');" ^
  "$target = Join-Path $dest 'node';" ^
  "if (Test-Path $target) { Remove-Item $target -Recurse -Force };" ^
  "Rename-Item -Path $extracted -NewName 'node';" ^
  "Remove-Item $zipPath -Force;" ^
  "Write-Output 'NODE_READY';" ^
  "& (Join-Path $target 'node.exe') -v;" ^
  "& (Join-Path $target 'npm.cmd') -v" >> "%LOG%" 2>&1

echo INSTALL_EXIT=%errorlevel% >> "%LOG%"
echo ==ALL_DONE== >> "%LOG%"
endlocal
