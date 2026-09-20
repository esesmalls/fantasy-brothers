@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "tools\build_paperdoll.ps1" -IfStale
if errorlevel 1 exit /b 1
start "" "builds\paperdoll\windows\FantasyBrothers-Paperdoll.exe" -- --paperdoll
