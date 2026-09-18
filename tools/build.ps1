param([switch]$SkipTests)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$engine = Join-Path $PSScriptRoot 'godot/Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $engine)) { throw 'Run tools/setup.ps1 first.' }
if (-not $SkipTests) { & (Join-Path $PSScriptRoot 'verify.ps1') }
Push-Location $projectRoot
try {
    New-Item -ItemType Directory -Force 'builds/windows' | Out-Null
    & $engine --headless --path game --export-release 'Windows Desktop'
    if ($LASTEXITCODE -ne 0) { throw 'Windows export failed.' }
    Copy-Item -LiteralPath 'game/assets/godot-notices.txt' -Destination 'builds/windows/GODOT-NOTICES.txt'
    Copy-Item -LiteralPath 'docs/PLAYTEST.md' -Destination 'builds/windows/PLAYTEST.md'
    Compress-Archive -Path 'builds/windows/*' -DestinationPath 'builds/FantasyBrothers-0.1.2-windows.zip' -Force
    Get-FileHash -Algorithm SHA256 -LiteralPath 'builds/windows/FantasyBrothers.exe', 'builds/FantasyBrothers-0.1.2-windows.zip'
} finally { Pop-Location }
