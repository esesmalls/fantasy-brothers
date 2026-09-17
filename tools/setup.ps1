$ErrorActionPreference = 'Stop'
$version = '4.7.2-stable'
$engineDir = Join-Path $PSScriptRoot 'godot'
$engine = Join-Path $engineDir 'Godot_v4.7.2-stable_win64_console.exe'
$archiveName = "Godot_v$version`_win64.exe.zip"
if (-not (Test-Path -LiteralPath $engine)) {
    New-Item -ItemType Directory -Force $engineDir | Out-Null
    $archive = Join-Path $engineDir $archiveName
    Invoke-WebRequest -Uri "https://github.com/godotengine/godot-builds/releases/download/$version/$archiveName" -OutFile $archive
    $checksumLine = Get-Content (Join-Path $engineDir 'SHA512-SUMS.txt') | Where-Object { $_.EndsWith("  $archiveName") }
    if (-not $checksumLine) { throw 'Pinned checksum is missing.' }
    $expected = ($checksumLine -split '\s+')[0]
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA512).Hash.ToLowerInvariant() -ne $expected) { throw 'Godot archive checksum mismatch.' }
    Expand-Archive -LiteralPath $archive -DestinationPath $engineDir -Force
}
& $engine --version
if ($LASTEXITCODE -ne 0) { throw 'Godot runtime failed.' }
$templateDir = Join-Path $PSScriptRoot 'templates/4.7.2'
if (-not (Test-Path -LiteralPath (Join-Path $templateDir 'windows_release_x86_64.exe'))) {
    & python (Join-Path $PSScriptRoot 'fetch_windows_templates.py')
    if ($LASTEXITCODE -ne 0) { throw 'Template download failed. Python 3 and access to GitHub releases are required.' }
}
