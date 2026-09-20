@echo off
cd /d "%~dp0"
if exist "builds\hand-style-review\windows\FantasyBrothers-HandComparison.exe" (
  start "" "builds\hand-style-review\windows\FantasyBrothers-HandComparison.exe" -- --hand-style-review
) else if exist "tools\godot\Godot_v4.7.2-stable_win64.exe" (
  start "" "tools\godot\Godot_v4.7.2-stable_win64.exe" --path game -- --hand-style-review
) else (
  start "" "art\validation\2026-09-20-hand-comparison\index.html"
)
