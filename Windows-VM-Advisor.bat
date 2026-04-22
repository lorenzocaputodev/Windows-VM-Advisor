@echo off
setlocal EnableExtensions EnableDelayedExpansion

pushd "%~dp0"

set "SCRIPT_PATH=%~dp0src\entrypoints\Start-Windows-VM-Advisor.ps1"
set "OUTPUT_FILE=%TEMP%\windows-vm-advisor-%RANDOM%-%RANDOM%.log"
set "RESULTS_FILE=%TEMP%\windows-vm-advisor-results-%RANDOM%-%RANDOM%.txt"
set "RESULTS_PATH="

if not exist "%SCRIPT_PATH%" (
    echo [FAILURE] Start-Windows-VM-Advisor.ps1 was not found.
    popd
    pause
    exit /b 1
)

if exist "%RESULTS_FILE%" del "%RESULTS_FILE%" >nul 2>&1

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%" -ResultsPathFile "%RESULTS_FILE%" %* > "%OUTPUT_FILE%" 2>&1
set "PS_EXIT=%ERRORLEVEL%"

type "%OUTPUT_FILE%"

if exist "%RESULTS_FILE%" (
    for /f "usebackq delims=" %%L in ("%RESULTS_FILE%") do (
        set "RESULTS_PATH=%%L"
    )
)

echo.
if "%PS_EXIT%"=="0" (
    echo [SUCCESS] Windows-VM-Advisor completed successfully.
    if defined RESULTS_PATH (
        set /p "OPEN_RESULTS=Open the results folder now? [Y/N]: "
        if /i "!OPEN_RESULTS!"=="Y" (
            explorer.exe "!RESULTS_PATH!" >nul 2>&1
        )
    )
) else (
    echo [FAILURE] Windows-VM-Advisor failed with exit code %PS_EXIT%.
)

if exist "%OUTPUT_FILE%" del "%OUTPUT_FILE%" >nul 2>&1
if exist "%RESULTS_FILE%" del "%RESULTS_FILE%" >nul 2>&1

popd
pause
exit /b %PS_EXIT%
