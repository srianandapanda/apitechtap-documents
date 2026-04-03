@echo off
setlocal
REM Run from Command Prompt (cmd.exe). Uses PowerShell under the hood with execution policy bypass.
set "SCRIPT_DIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%docker-local.ps1" %*
endlocal
exit /b %ERRORLEVEL%
