@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0Install-NoitaWaves.ps1"
if errorlevel 1 (
    echo Noita Waves installer could not start. Make sure Windows PowerShell is available.
    pause
)
endlocal
