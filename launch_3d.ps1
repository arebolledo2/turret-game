#requires -Version 7.0
param([string]$GodotPath = $env:GODOT_BIN)
$ErrorActionPreference = 'Stop'
$version = (Get-Content (Join-Path $PSScriptRoot '.godot-version') -Raw).Trim()
if (-not $GodotPath) {
    $GodotPath = Join-Path $env:USERPROFILE "Godot/4.7/Godot_v$version-stable_win64.exe"
}
if (-not (Test-Path -LiteralPath $GodotPath)) { throw "Set GODOT_BIN or pass -GodotPath for Godot $version." }
& $GodotPath --path $PSScriptRoot res://scenes/three_d/proving_ground.tscn
exit $LASTEXITCODE
