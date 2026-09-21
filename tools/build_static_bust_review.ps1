param([switch]$SkipTests)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$engine = Join-Path $PSScriptRoot 'godot/Godot_v4.7.2-stable_win64_console.exe'
Push-Location $projectRoot
try {
    & $engine --headless --editor --path game --import
    if ($LASTEXITCODE -ne 0) { throw 'Import failed.' }
    if (-not $SkipTests) {
        & $engine --headless --path game --script res://tests/test_static_bust.gd
        if ($LASTEXITCODE -ne 0) { throw 'Static bust checks failed.' }
    }
    New-Item -ItemType Directory -Force 'builds/static-bust/windows' | Out-Null
    & $engine --headless --path game --export-release 'Windows Desktop' '../builds/static-bust/windows/FantasyBrothers-StaticBust.exe'
    if ($LASTEXITCODE -ne 0) { throw 'Export failed.' }
    Copy-Item -LiteralPath 'game/assets/godot-notices.txt' -Destination 'builds/static-bust/windows/GODOT-NOTICES.txt'
    Set-Content -LiteralPath 'builds/static-bust/windows/Review.cmd' -Encoding ascii -Value '@echo off', 'cd /d "%~dp0"', 'start "" "FantasyBrothers-StaticBust.exe" -- --static-bust-review'
    Get-FileHash -Algorithm SHA256 -LiteralPath 'builds/static-bust/windows/FantasyBrothers-StaticBust.exe'
} finally { Pop-Location }
