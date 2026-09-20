@echo off
cd /d "%~dp0"
if not exist "builds\static-bust\windows\FantasyBrothers-StaticBust.exe" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "tools\build_static_bust_review.ps1"
  if errorlevel 1 exit /b 1
)
start "" "builds\static-bust\windows\FantasyBrothers-StaticBust.exe" -- --static-bust-review
