# Run GUT tests from command line
# Usage: .\run_tests.ps1 [options]
#
# Options:
#   -unit       Run only unit tests
#   -integration Run only integration tests
#   -verbose    Show verbose output
#   -filter     Filter tests by name pattern

param(
    [switch]$unit,
    [switch]$integration,
    [switch]$verbose,
    [string]$filter = ""
)

# Find Godot executable
$godotPaths = @(
    "C:\Users\AndresRebolledo\AppData\Local\Godot\Godot_v4.5.1-stable_win64.exe",
    "$env:LOCALAPPDATA\Godot\Godot_v4.5.1-stable_win64.exe",
    "C:\Users\AndresRebolledo\AppData\Local\Godot\Godot_v4.3-stable_win64.exe",
    "$env:LOCALAPPDATA\Godot\godot.exe",
    "godot",
    "godot4"
)

$godot = $null
foreach ($path in $godotPaths) {
    if (Get-Command $path -ErrorAction SilentlyContinue) {
        $godot = $path
        break
    }
    if (Test-Path $path) {
        $godot = $path
        break
    }
}

if (-not $godot) {
    Write-Error "Could not find Godot executable. Please add it to PATH or update this script."
    exit 1
}

Write-Host "Using Godot: $godot" -ForegroundColor Cyan

# Build GUT command line arguments
$gutArgs = @(
    "--headless",
    "-s", "addons/gut/gut_cmdln.gd",
    "-ginclude_subdirs"
)

# Test directory selection
if ($unit) {
    $gutArgs += "-gdir=res://tests/unit"
    Write-Host "Running unit tests only..." -ForegroundColor Yellow
} elseif ($integration) {
    $gutArgs += "-gdir=res://tests/integration"
    Write-Host "Running integration tests only..." -ForegroundColor Yellow
} else {
    $gutArgs += "-gdir=res://tests"
    Write-Host "Running all tests..." -ForegroundColor Yellow
}

# Verbose output
if ($verbose) {
    $gutArgs += "-glog=3"
}

# Filter by test name
if ($filter) {
    $gutArgs += "-gtest=$filter"
    Write-Host "Filtering tests: $filter" -ForegroundColor Yellow
}

# Exit after tests complete
$gutArgs += "-gexit"

Write-Host ""
Write-Host "Command: $godot $($gutArgs -join ' ')" -ForegroundColor DarkGray
Write-Host ""

# Run tests
& $godot $gutArgs

$exitCode = $LASTEXITCODE

Write-Host ""
if ($exitCode -eq 0) {
    Write-Host "All tests passed!" -ForegroundColor Green
} else {
    Write-Host "Some tests failed. Exit code: $exitCode" -ForegroundColor Red
}

exit $exitCode
