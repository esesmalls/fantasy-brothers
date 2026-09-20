@echo off
cd /d "%~dp0"
if exist "builds\motion-review\windows\FantasyBrothers-MotionReview.exe" (
  start "" "builds\motion-review\windows\FantasyBrothers-MotionReview.exe" -- --motion-review
) else (
  echo Please run tools/build_motion_review.ps1 to build the review package.
  pause
)
