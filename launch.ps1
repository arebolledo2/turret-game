# Launch script for Brotato-like Survivor game
# Finds and runs Godot with this project

$projectPath = $PSScriptRoot
$godotPaths = @(
    "$env:USERPROFILE\Godot\4.6\Godot_v4.6-stable_win64.exe",
    "C:\Users\AndresRebolledo\AppData\Local\Godot\Godot_v4.5.1-stable_win64.exe",
    "$env:LOCALAPPDATA\Godot\Godot_v4.5.1-stable_win64.exe",
    "C:\Users\AndresRebolledo\AppData\Local\Godot\Godot_v4.3-stable_win64.exe"
)

# Find first available Godot installation
$godotExe = $null
foreach ($path in $godotPaths) {
    if (Test-Path $path) {
        $godotExe = $path
        break
    }
}

# If not found in known locations, search
if (-not $godotExe) {
    Write-Host "Searching for Godot installation..."
    $godotExe = Get-Command godot -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
}

if (-not $godotExe) {
    Write-Host "Godot not found. Please install Godot 4.3 or later."
    Write-Host "Download from: https://godotengine.org/download"
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Starting game with Godot: $godotExe"
& $godotExe --path $projectPath
