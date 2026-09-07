#requires -Version 7.0
param([Parameter(Mandatory)][string]$Destination)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot
$version = (Get-Content (Join-Path $projectRoot '.godot-version') -Raw).Trim()
$expectedHash = (Get-Content (Join-Path $projectRoot '.godot-windows-sha512') -Raw).Trim()
$null = New-Item -ItemType Directory -Path $Destination -Force
$archive = Join-Path $Destination 'godot.zip'
$url = "https://github.com/godotengine/godot-builds/releases/download/$version-stable/Godot_v$version-stable_win64.exe.zip"
Invoke-WebRequest $url -OutFile $archive
if ((Get-FileHash $archive -Algorithm SHA512).Hash -ne $expectedHash) { throw 'Godot archive checksum mismatch.' }
Expand-Archive -LiteralPath $archive -DestinationPath $Destination -Force
$executable = Join-Path $Destination "Godot_v$version-stable_win64.exe"
if (-not (Test-Path $executable)) { throw 'Godot archive did not contain the expected executable.' }
Write-Output $executable
