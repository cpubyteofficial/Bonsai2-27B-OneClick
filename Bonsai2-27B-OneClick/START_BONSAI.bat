@echo off
setlocal
title Bonsai 2 27B - Local AI Chat (keep this window open)
cd /d "%~dp0"
echo Starting Bonsai 2 27B - please keep this window open...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer.ps1"
if errorlevel 1 (
    echo.
    echo [X] Something went wrong - read the [ERROR] messages above.
    echo     If it was a download problem, just double-click START_BONSAI.bat
    echo     again - it resumes where it stopped.
) else (
    echo.
    echo Bonsai chat closed. You can close this window.
)
pause
