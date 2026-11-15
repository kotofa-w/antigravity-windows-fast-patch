@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"

set "PS_CMD=powershell.exe"
where pwsh.exe >nul 2>&1
if %ERRORLEVEL% equ 0 (
    set "PS_CMD=pwsh.exe"
)

%PS_CMD% -NoProfile -ExecutionPolicy Bypass -File "%~dp0Check-And-Fix-Antigravity.ps1"

echo.
pause