@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "tools\build_paperdoll.ps1" -IfStale
if errorlevel 1 exit /b 1
if not "%~1"=="" (
  start "" "builds\paperdoll\windows\FantasyBrothers-Paperdoll.exe" -- --paperdoll "--paperdoll-project=%~f1"
  exit /b
)
if exist "my_test-v2.json" (
  start "" "builds\paperdoll\windows\FantasyBrothers-Paperdoll.exe" -- --paperdoll "--paperdoll-project=%CD%\my_test-v2.json"
  exit /b
)
if exist "my_test.json" (
  start "" "builds\paperdoll\windows\FantasyBrothers-Paperdoll.exe" -- --paperdoll "--paperdoll-project=%CD%\my_test.json"
  exit /b
)
start "" "builds\paperdoll\windows\FantasyBrothers-Paperdoll.exe" -- --paperdoll
