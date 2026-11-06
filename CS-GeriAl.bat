@echo off
net session >nul 2>&1
if %errorlevel% neq 0 (
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
title CS2 Ayarlari Geri Al
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0CS-Kontrol.ps1" -GeriAl
echo.
pause
