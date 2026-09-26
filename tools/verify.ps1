$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$engine = Join-Path $PSScriptRoot 'godot/Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $engine)) { throw 'Run tools/setup.ps1 to install the pinned Godot runtime.' }
Push-Location $projectRoot
try {
    foreach ($test in @('test_battle', 'test_campaign', 'test_save', 'test_flow', 'test_inspection', 'test_world', 'test_equipment', 'test_character_layers', 'test_characters', 'test_progression_regression', 'test_motion_events', 'test_tactical_expansion', 'test_tactical_integrity', 'test_foundation_integration', 'test_foundation_library', 'test_company_expansion', 'test_weapon_feedback', 'test_asset_review', 'test_facing_and_render', 'test_battle_controller', 'test_movement_overlay')) {
        $testOutput = & $engine --headless --path game --script "res://tests/$test.gd" 2>&1
        $testOutput | Write-Output
        if ($LASTEXITCODE -ne 0 -or ($testOutput | Out-String) -match 'SCRIPT ERROR:|Parse Error:') { throw "$test failed with exit code $LASTEXITCODE" }
    }
    & $engine --headless --path game -- --foundation-smoke "--foundation-output=$projectRoot/builds/foundation/headless"
    if ($LASTEXITCODE -ne 0) { throw 'UI smoke test failed.' }
} finally { Pop-Location }
