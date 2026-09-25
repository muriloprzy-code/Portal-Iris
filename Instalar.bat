@echo off
:: MyOwn Portal - one-click installer.
:: Just double-click this file. It asks Windows for permission (needed to
:: restart the IRIS private web server on the local-install path), then does
:: everything else automatically: Docker or local IRIS, whichever you have.

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting administrator permission...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Install-All.ps1"
pause
