param([switch]$SkipTests)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$engine = Join-Path $PSScriptRoot 'godot/Godot_v4.7.2-stable_win64_console.exe'
Push-Location $projectRoot
try {
    & python tools/validate_motion_assets.py
    if ($LASTEXITCODE -ne 0) { throw 'Motion asset contract failed.' }
    if (-not $SkipTests) {
        & tools/verify.ps1
    }
    New-Item -ItemType Directory -Force 'builds/motion-review/windows' | Out-Null
    & $engine --headless --path game --export-release 'Windows Desktop' '../builds/motion-review/windows/FantasyBrothers-MotionReview.exe'
    if ($LASTEXITCODE -ne 0) { throw 'Motion review export failed.' }
    Copy-Item -LiteralPath 'game/assets/godot-notices.txt' -Destination 'builds/motion-review/windows/GODOT-NOTICES.txt'
    Copy-Item -LiteralPath 'art/validation/2026-09-20-motion-templates/README.md' -Destination 'builds/motion-review/windows/README.md'
    Copy-Item -LiteralPath 'art/validation/2026-09-20-motion-templates/QA.md' -Destination 'builds/motion-review/windows/QA.md'
    Set-Content -LiteralPath 'builds/motion-review/windows/Review.cmd' -Encoding ascii -Value '@echo off', 'cd /d "%~dp0"', 'start "" "FantasyBrothers-MotionReview.exe" -- --motion-review'
    Compress-Archive -Path 'builds/motion-review/windows/*' -DestinationPath 'builds/FantasyBrothers-H-MotionReview.zip' -Force
    Get-FileHash -Algorithm SHA256 -LiteralPath 'builds/motion-review/windows/FantasyBrothers-MotionReview.exe', 'builds/FantasyBrothers-H-MotionReview.zip'
} finally { Pop-Location }
