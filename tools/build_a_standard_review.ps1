param([switch]$SkipTests)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$engine = Join-Path $PSScriptRoot 'godot/Godot_v4.7.2-stable_win64_console.exe'
Push-Location $projectRoot
try {
    & $engine --headless --editor --path game --import
    if ($LASTEXITCODE -ne 0) { throw 'Import failed.' }
    if (-not $SkipTests) {
        & $engine --headless --path game --script res://tests/test_a_standard.gd
        if ($LASTEXITCODE -ne 0) { throw 'A production checks failed.' }
    }
    New-Item -ItemType Directory -Force 'builds/a-standard/windows' | Out-Null
    & $engine --headless --path game --export-release 'Windows Desktop' '../builds/a-standard/windows/FantasyBrothers-AStandard.exe'
    if ($LASTEXITCODE -ne 0) { throw 'Export failed.' }
    Copy-Item -LiteralPath 'game/assets/godot-notices.txt' -Destination 'builds/a-standard/windows/GODOT-NOTICES.txt'
    Set-Content -LiteralPath 'builds/a-standard/windows/Review.cmd' -Encoding ascii -Value '@echo off', 'cd /d "%~dp0"', 'start "" "FantasyBrothers-AStandard.exe" -- --a-standard-review'
    Get-FileHash -Algorithm SHA256 -LiteralPath 'builds/a-standard/windows/FantasyBrothers-AStandard.exe'
} finally { Pop-Location }
