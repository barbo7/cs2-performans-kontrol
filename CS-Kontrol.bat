@echo off
title CS2 Kasma Kontrolu
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0CS-Kontrol.ps1" %*
echo.
pause
