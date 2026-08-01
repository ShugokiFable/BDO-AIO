@echo off
title BDO Modding AIO - 2026
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0bdo_aio.ps1"
if errorlevel 1 (
  echo.
  echo Something went wrong. Read the message above.
  pause
)
