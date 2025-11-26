@echo off
REM Launch script for Brotato-like Survivor game
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0launch.ps1"
