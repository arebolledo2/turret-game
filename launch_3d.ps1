# Compatibility entry point: the main game is now 3D.
#requires -Version 7.0
param([string]$GodotPath = $env:GODOT_BIN)
& (Join-Path $PSScriptRoot 'launch.ps1') -GodotPath $GodotPath
exit $LASTEXITCODE
