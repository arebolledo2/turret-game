#requires -Version 7.0
# Run isolated GUT tests. Full logs and structured results are retained per run.
param(
    [switch]$unit,
    [switch]$integration,
    [switch]$verbose,
    [switch]$full,
    [string]$filter = "",
    [ValidateRange(1, 3600)][int]$timeout = 120,
    [string]$GodotPath = $env:GODOT_BIN
)
$ErrorActionPreference = 'Stop'
if ($unit -and $integration) { throw 'Select either -unit or -integration.' }
$requiredVersion = (Get-Content (Join-Path $PSScriptRoot '.godot-version') -Raw).Trim()
$candidates = @($GodotPath, "$env:USERPROFILE/Godot/4.7/Godot_v$($requiredVersion)-stable_win64.exe", 'godot', 'godot4')
$godot = $null
foreach ($candidate in $candidates) {
    if (-not $candidate) { continue }
    $command = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($command) { $godot = $command.Source; break }
}
if (-not $godot) { throw "Install Godot $requiredVersion and set GODOT_BIN or pass -GodotPath." }
$version = (& $godot --version | Out-String).Trim()
if ($version -notlike "$requiredVersion.stable.*") { throw "Expected Godot $requiredVersion stable, found $version." }

$runDirectory = Join-Path $PSScriptRoot ('.test-results/' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $runDirectory -Force
$stdoutPath = Join-Path $runDirectory 'stdout.log'
$stderrPath = Join-Path $runDirectory 'stderr.log'
$resultPath = Join-Path $runDirectory 'results.json'
Write-Host "Using Godot: $version"
Write-Host "Test artifacts: $runDirectory"

$testDirectory = if ($unit) { 'res://tests/unit' } elseif ($integration) { 'res://tests/integration' } else { 'res://tests/unit,res://tests/integration' }
$arguments = @('--headless', '--path', $PSScriptRoot, '--log-file', (Join-Path $runDirectory 'engine.log'), '-s', 'addons/gut/gut_cmdln.gd', '-ginclude_subdirs', "-gdir=$testDirectory", '-gexit', '-gpost_run_script=res://tests/helpers/export_results.gd', '-gdisable_colors')
$arguments += if ($verbose) { '-glog=3' } elseif ($full) { '-glog=2' } else { '-glog=1' }
if ($filter) { $arguments += "-gselect=$filter" }

$startInfo = [System.Diagnostics.ProcessStartInfo]::new($godot)
$startInfo.WorkingDirectory = $PSScriptRoot
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
foreach ($argument in $arguments) { $startInfo.ArgumentList.Add($argument) }
# Child-only isolation: Godot's user:// and logs never touch the player's data.
$startInfo.Environment['APPDATA'] = $runDirectory
$startInfo.Environment['XDG_DATA_HOME'] = $runDirectory
$startInfo.Environment['TURRET_TEST_RESULTS'] = $resultPath
$process = [System.Diagnostics.Process]::new()
$process.StartInfo = $startInfo
$null = $process.Start()
$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
$timedOut = -not $process.WaitForExit($timeout * 1000)
if ($timedOut) { $process.Kill($true) }
$process.WaitForExit()
$stdout = $stdoutTask.GetAwaiter().GetResult()
$stderr = $stderrTask.GetAwaiter().GetResult()
[IO.File]::WriteAllText($stdoutPath, $stdout)
[IO.File]::WriteAllText($stderrPath, $stderr)
$exitCode = $process.ExitCode
$process.Dispose()
if ($full -or $verbose) { Write-Host $stdout } else {
    $stdout -split '\r?\n' | Where-Object { $_ -match '^(Totals|Tests |Passing Tests |Scripts |Asserts |Orphans |Time |Risky/Pending )|\[(Failed|Risky|Error)\]' } | ForEach-Object { Write-Host $_ }
}
# Always surface stderr; expected validation warnings remain informational.
if ($stderr) { Write-Host $stderr }
if ($timedOut) { throw "Tests exceeded ${timeout}s. See $runDirectory" }
. (Join-Path $PSScriptRoot 'tools/test_gate.ps1')
if (-not (Test-Path $resultPath)) { throw 'GUT did not produce a completed result file.' }
$results = Get-Content $resultPath -Raw | ConvertFrom-Json
Assert-CleanTestRun -ExitCode $exitCode -Stdout $stdout -Stderr $stderr -Results $results
$totals = $results.test_scripts.props
Write-Host "All $($totals.tests) tests passed with no risky tests, errors, or remaining orphans." -ForegroundColor Green
