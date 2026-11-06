@echo off
rem Wi-Fi profil ayari yonetici izni istedigi icin kendini yonetici olarak yeniden acar
net session >nul 2>&1
if %errorlevel% neq 0 (
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
title CS2 Kasma Duzeltme
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0CS-Kontrol.ps1" -Duzelt
echo.
pause
