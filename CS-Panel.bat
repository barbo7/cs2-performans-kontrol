@echo off
rem Wi-Fi duzeltmeleri yonetici izni istedigi icin panel yonetici olarak acilir
net session >nul 2>&1
if %errorlevel% neq 0 (
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0CS-Panel.ps1"
