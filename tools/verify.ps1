$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$engine = Join-Path $PSScriptRoot 'godot/Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $engine)) { throw 'Run tools/setup.ps1 to install the pinned Godot runtime.' }
Push-Location $projectRoot
try {
    foreach ($test in @('test_battle', 'test_campaign', 'test_save', 'test_flow', 'test_inspection', 'test_world')) {
        & $engine --headless --path game --script "res://tests/$test.gd"
        if ($LASTEXITCODE -ne 0) { throw "$test failed with exit code $LASTEXITCODE" }
    }
    & $engine --headless --path game -- --smoke-test
    if ($LASTEXITCODE -ne 0) { throw 'UI smoke test failed.' }
} finally { Pop-Location }
