@echo off
cd /d "%~dp0"
if not exist "builds\a-standard\windows\FantasyBrothers-AStandard.exe" powershell -NoProfile -ExecutionPolicy Bypass -File "tools\build_a_standard_review.ps1"
if not exist "builds\a-standard\windows\FantasyBrothers-AStandard.exe" exit /b 1
start "" "builds\a-standard\windows\FantasyBrothers-AStandard.exe" -- --a-standard-review
