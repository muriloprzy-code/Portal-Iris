@echo off
:: MyOwn Portal - one-click installer.
:: Just double-click this file. It asks Windows for permission (needed to
:: restart the IRIS private web server on the local-install path), then does
:: everything else automatically: Docker or local IRIS, whichever you have.

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting administrator permission...
    echo A Windows permission prompt should appear now - click "Yes" to continue.
    echo ^(If nothing seems to happen, check for that prompt behind other windows,
    echo and make sure Windows SmartScreen did not block it.^)
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    if errorlevel 1 (
        echo.
        echo Could not request administrator permission automatically - it was
        echo likely declined or blocked. Right-click Instalar.bat yourself and
        echo choose "Run as administrator" instead.
        echo.
        pause
    )
    exit /b
)

cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Install-All.ps1"
pause
