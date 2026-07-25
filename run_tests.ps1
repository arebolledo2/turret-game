# Run GUT tests from command line
# Usage: .\run_tests.ps1 [options]
#
# Options:
#   -unit        Run only unit tests
#   -integration Run only integration tests
#   -verbose     Show verbose output
#   -full        Show full test output (default is quiet)
#   -filter      Filter tests by name pattern

param(
    [switch]$unit,
    [switch]$integration,
    [switch]$verbose,
    [switch]$full,
    [string]$filter = "",
    [int]$timeout = 120
)

# Find Godot executable
$godotPaths = @(
    "$env:USERPROFILE\Godot\4.7\Godot_v4.7.1-stable_win64.exe",
    "$env:USERPROFILE\Godot\4.6\Godot_v4.6-stable_win64.exe",
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
} elseif ($full) {
    $gutArgs += "-glog=2"
} else {
    $gutArgs += "-glog=1"
}

# Filter by test name
if ($filter) {
    $gutArgs += "-gtest=$filter"
    Write-Host "Filtering tests: $filter" -ForegroundColor Yellow
}

# Exit after tests complete
$gutArgs += "-gexit"

if ($full -or $verbose) {
    Write-Host ""
    Write-Host "Command: $godot $($gutArgs -join ' ')" -ForegroundColor DarkGray
    Write-Host ""
}

# Run tests with timeout using background process
$process = Start-Process -FilePath $godot -ArgumentList $gutArgs -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\gut_stdout.txt" -RedirectStandardError "$env:TEMP\gut_stderr.txt"

if (-not $process.WaitForExit($timeout * 1000)) {
    Write-Host "TIMEOUT: Tests exceeded ${timeout}s limit. Killing process." -ForegroundColor Red
    $process.Kill()
    exit 1
}

$exitCode = $process.ExitCode

# Read captured output
$output = @()
if (Test-Path "$env:TEMP\gut_stdout.txt") {
    $output = Get-Content "$env:TEMP\gut_stdout.txt"
}

if ($full -or $verbose) {
    $output | ForEach-Object { Write-Host $_ }
} else {
    # Filter output to only show errors, failures, and summary
    $inSummary = $false
    $output | ForEach-Object {
        $line = $_

        # Detect start of summary
        if ($line -match "--- GUT Finished ---" -or $line -match "Tests finished" -or $line -match "Passes.*Failures.*Pending" -or $line -match "\[  Summary  \]" -or $line -match "Totals") {
            $inSummary = $true
        }

        # Output logic
        if ($inSummary) {
            Write-Host $line
        } elseif ($line -match "\[ERROR\]" -or $line -match "\[FAIL\]" -or $line -match "failed" -or $line -match "error" -or $line -match "PARSE ERROR") {
            Write-Host $line -ForegroundColor Red
        } elseif ($line -match "SCRIPT ERROR") {
            Write-Host $line -ForegroundColor Yellow
        }
    }
}

Write-Host ""
if ($exitCode -eq 0) {
    Write-Host "All tests passed!" -ForegroundColor Green
} else {
    Write-Host "Some tests failed. Exit code: $exitCode" -ForegroundColor Red
}

exit $exitCode
