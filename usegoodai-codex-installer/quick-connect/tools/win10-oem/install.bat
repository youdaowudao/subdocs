@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File C:\OEM\setup.ps1 > C:\OEM\setup.log 2>&1
exit /b %ERRORLEVEL%
