param([switch]$SkipTests, [switch]$IfStale)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$engine = Join-Path $PSScriptRoot 'godot/Godot_v4.7.2-stable_win64_console.exe'
Push-Location $projectRoot
try {
    $exportPath = Join-Path $projectRoot 'builds/paperdoll/windows/FantasyBrothers-Paperdoll.exe'
    if ($IfStale -and (Test-Path -LiteralPath $exportPath)) {
        $exportTime = (Get-Item -LiteralPath $exportPath).LastWriteTimeUtc
        $changed = Get-ChildItem -LiteralPath 'game' -Recurse -File |
            Where-Object { $_.FullName -notmatch '[\\/]\.godot[\\/]' -and $_.LastWriteTimeUtc -gt $exportTime } |
            Select-Object -First 1
        if (-not $changed -and (Get-Item -LiteralPath $PSCommandPath).LastWriteTimeUtc -le $exportTime) { return }
    }
    & $engine --headless --editor --path game --import
    if ($LASTEXITCODE -ne 0) { throw 'Import failed.' }
    if (-not $SkipTests) {
        & $engine --headless --path game --script res://tests/test_paperdoll.gd
        if ($LASTEXITCODE -ne 0) { throw 'Paperdoll checks failed.' }
        & $engine --headless --path game --script res://tests/test_paperdoll_modules.gd
        if ($LASTEXITCODE -ne 0) { throw 'Paperdoll module checks failed.' }
        & $engine --headless --path game --script res://tests/test_static_bust.gd
        if ($LASTEXITCODE -ne 0) { throw 'Static bust regression failed.' }
    }
    New-Item -ItemType Directory -Force 'builds/paperdoll/windows' | Out-Null
    & $engine --headless --path game --export-release 'Windows Desktop' '../builds/paperdoll/windows/FantasyBrothers-Paperdoll.exe'
    if ($LASTEXITCODE -ne 0) { throw 'Export failed.' }
    Copy-Item -LiteralPath 'game/assets/godot-notices.txt' -Destination 'builds/paperdoll/windows/GODOT-NOTICES.txt'
    Get-FileHash -Algorithm SHA256 -LiteralPath 'builds/paperdoll/windows/FantasyBrothers-Paperdoll.exe'
} finally { Pop-Location }
