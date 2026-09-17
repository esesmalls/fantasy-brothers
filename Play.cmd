@echo off
if exist "%~dp0builds\windows\FantasyBrothers.exe" (
  start "" "%~dp0builds\windows\FantasyBrothers.exe"
) else (
  echo Build missing. See README.md for setup and build instructions.
  pause
)
