@echo off
setlocal
REM Host-built JARs + prebuilt images (no Gradle in Docker). Requires Docker Compose 2.17+.
set "SCRIPT_DIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%docker-local-prebuilt.ps1" %*
endlocal
exit /b %ERRORLEVEL%
