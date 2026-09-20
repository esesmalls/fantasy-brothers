param([switch]$SkipTests)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$engine = Join-Path $PSScriptRoot 'godot/Godot_v4.7.2-stable_win64_console.exe'
Push-Location $projectRoot
try {
    if (-not $SkipTests) {
        & $engine --headless --editor --path game --import
        if ($LASTEXITCODE -ne 0) { throw 'Godot import failed.' }
        & $engine --headless --path game --script res://tests/test_hand_style_review.gd
        if ($LASTEXITCODE -ne 0) { throw 'Comparison checks failed.' }
    }
    New-Item -ItemType Directory -Force 'builds/hand-style-review/windows' | Out-Null
    & $engine --headless --path game --export-release 'Windows Desktop' '../builds/hand-style-review/windows/FantasyBrothers-HandComparison.exe'
    if ($LASTEXITCODE -ne 0) { throw 'Comparison export failed.' }
    Copy-Item -LiteralPath 'game/assets/godot-notices.txt' -Destination 'builds/hand-style-review/windows/GODOT-NOTICES.txt'
    Set-Content -LiteralPath 'builds/hand-style-review/windows/Review.cmd' -Encoding ascii -Value '@echo off', 'cd /d "%~dp0"', 'start "" "FantasyBrothers-HandComparison.exe" -- --hand-style-review'
    Get-FileHash -Algorithm SHA256 -LiteralPath 'builds/hand-style-review/windows/FantasyBrothers-HandComparison.exe'
} finally { Pop-Location }
