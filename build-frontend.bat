@echo off
setlocal
set NODEDIR=%~dp0.tools\node
set PATH=%NODEDIR%;%PATH%
cd /d "%~dp0frontend"

echo ==START==> build_result.log
echo %DATE% %TIME% >> build_result.log
where node >> build_result.log 2>&1
where npm >> build_result.log 2>&1
node -v >> build_result.log 2>&1
call npm -v >> build_result.log 2>&1

echo ==STEP1 tsc app== >> build_result.log
call node node_modules\typescript\bin\tsc --noEmit -p tsconfig.app.json > step1_tsc_app.log 2>&1
echo STEP1_EXIT=%ERRORLEVEL% >> build_result.log

echo ==STEP2 tsc node== >> build_result.log
call node node_modules\typescript\bin\tsc --noEmit -p tsconfig.node.json > step2_tsc_node.log 2>&1
echo STEP2_EXIT=%ERRORLEVEL% >> build_result.log

echo ==STEP3 vite build== >> build_result.log
call node node_modules\vite\bin\vite.js build > step3_vite.log 2>&1
echo STEP3_EXIT=%ERRORLEVEL% >> build_result.log

echo ==COPY== >> build_result.log
if exist "..\web\assets" rmdir /s /q "..\web\assets"
if exist "..\web\index.html" del /f /q "..\web\index.html"
xcopy /s /e /y "dist\*" "..\web\" >> build_result.log 2>&1
echo COPY_EXIT=%ERRORLEVEL% >> build_result.log

echo ==ALL_DONE== >> build_result.log
