#requires -Version 7.0
# Run isolated GUT tests. Full logs and structured results are retained per run.
param(
    [switch]$unit,
    [switch]$integration,
    [switch]$verbose,
    [switch]$full,
    [switch]$Import,
    [switch]$Serial,
    [ValidateRange(1, 16)][int]$Shards = [Math]::Max(1, [Math]::Min(4, [int]([Environment]::ProcessorCount / 3))),
    [string]$filter = "",
    [ValidateRange(1, 3600)][int]$timeout = 120,
    [string]$GodotPath = $env:GODOT_BIN,
    [ValidateRange(1, 1000)][int]$KeepRuns = 10
)
$ErrorActionPreference = 'Stop'
if ($unit -and $integration) { throw 'Select either -unit or -integration.' }
$gutManifest = Get-Content (Join-Path $PSScriptRoot 'addons/gut/plugin.cfg') -Raw
if ($gutManifest -notmatch 'version="9\.5\.1"') { throw 'This runner is validated with vendored GUT 9.5.1. Update the compatibility checks when upgrading.' }
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

# Older isolated runs are disposable; keep the newest few for comparison.
$resultsRoot = Join-Path $PSScriptRoot '.test-results'
if (Test-Path $resultsRoot) {
    Get-ChildItem $resultsRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -Skip ($KeepRuns - 1) | Remove-Item -Recurse -Force
}
$runDirectory = Join-Path $PSScriptRoot ('.test-results/' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $runDirectory -Force
Write-Host "Using Godot: $version"
Write-Host "Test artifacts: $runDirectory"

# A default full run (no filter) splits unit and integration into two concurrent Godot
# processes; each part gets its own subdirectory so user:// data and results never collide.
function Get-IntegrationShards {
    # Greedy longest-first packing by file size (a cheap proxy for runtime) into balanced shards.
    $files = Get-ChildItem (Join-Path $PSScriptRoot 'tests/integration') -Recurse -Filter 'test_*.gd' | Sort-Object Length -Descending
    $count = [Math]::Min($Shards, [Math]::Max(1, $files.Count))
    $bins = 1..$count | ForEach-Object { [pscustomobject]@{ Size = 0L; Files = [Collections.Generic.List[string]]::new() } }
    foreach ($file in $files) {
        $bin = $bins | Sort-Object Size | Select-Object -First 1
        $bin.Size += $file.Length
        $relative = [IO.Path]::GetRelativePath($PSScriptRoot, $file.FullName).Replace('\', '/')
        $bin.Files.Add("res://$relative")
    }
    $index = 0
    foreach ($bin in $bins) { $index++; @{ Name = "integration-$index"; Select = ($bin.Files -join ',') } }
}
$parts = if ($unit) { @(@{ Name='unit'; Dir='res://tests/unit' }) }
    elseif ($integration) { @(Get-IntegrationShards) }
    elseif ($filter -or $Serial) { @(@{ Name='all'; Dir='res://tests/unit,res://tests/integration' }) }
    else { @(@{ Name='unit'; Dir='res://tests/unit' }) + @(Get-IntegrationShards) }
$logLevel = if ($verbose) { 3 } elseif ($full) { 2 } else { 1 }

function Start-TestProcess {
    param([string[]]$ProcessArguments, [string]$PartDirectory, [string]$ResultPath)
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new($godot)
    $startInfo.WorkingDirectory = $PSScriptRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $ProcessArguments) { $startInfo.ArgumentList.Add($argument) }
    # Child-only isolation: Godot's user:// and logs never touch the player's data.
    $startInfo.Environment['APPDATA'] = $PartDirectory
    $startInfo.Environment['XDG_DATA_HOME'] = $PartDirectory
    $startInfo.Environment['TURRET_TEST_RESULTS'] = $ResultPath
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $null = $process.Start()
    return [pscustomobject]@{
        Process = $process
        StdoutTask = $process.StandardOutput.ReadToEndAsync()
        StderrTask = $process.StandardError.ReadToEndAsync()
        Deadline = [DateTime]::UtcNow.AddSeconds($timeout)
    }
}
function Wait-TestProcess {
    param($Handle, [string]$OutputPath, [string]$ErrorPath)
    $process = $Handle.Process
    $remaining = [Math]::Max(0, ($Handle.Deadline - [DateTime]::UtcNow).TotalMilliseconds)
    $timedOut = -not $process.WaitForExit([int]$remaining)
    if ($timedOut) { $process.Kill($true) }
    $process.WaitForExit()
    $stdout = $Handle.StdoutTask.GetAwaiter().GetResult()
    $stderr = $Handle.StderrTask.GetAwaiter().GetResult()
    [IO.File]::WriteAllText($OutputPath, $stdout)
    [IO.File]::WriteAllText($ErrorPath, $stderr)
    $exitCode = $process.ExitCode
    $process.Dispose()
    return [pscustomobject]@{ Stdout=$stdout; Stderr=$stderr; ExitCode=$exitCode; TimedOut=$timedOut }
}
function Invoke-TestProcess {
    param([string[]]$ProcessArguments, [string]$OutputPath, [string]$ErrorPath)
    $handle = Start-TestProcess $ProcessArguments $runDirectory (Join-Path $runDirectory 'results.json')
    return Wait-TestProcess $handle $OutputPath $ErrorPath
}
if ($Import) {
    $importArgs = @('--headless', '--editor', '--import', '--quit', '--path', $PSScriptRoot, '--log-file', (Join-Path $runDirectory 'import-engine.log'))
    $importResult = Invoke-TestProcess $importArgs (Join-Path $runDirectory 'import-stdout.log') (Join-Path $runDirectory 'import-stderr.log')
    if ($importResult.TimedOut -or $importResult.ExitCode -ne 0 -or ($importResult.Stdout + $importResult.Stderr) -match '(?m)^(SCRIPT ERROR:|ERROR:)') {
        Write-Host $importResult.Stderr
        throw "Godot import failed. See $runDirectory"
    }
}

$handles = foreach ($part in $parts) {
    $partDirectory = if ($parts.Count -gt 1) { Join-Path $runDirectory $part.Name } else { $runDirectory }
    $null = New-Item -ItemType Directory -Path $partDirectory -Force
    $arguments = @('--headless', '--path', $PSScriptRoot, '--log-file', (Join-Path $partDirectory 'engine.log'), '-s', 'addons/gut/gut_cmdln.gd', '-ginclude_subdirs', $(if ($part.Select) { "-gtest=$($part.Select)" } else { "-gdir=$($part.Dir)" }), '-gexit', '-gpost_run_script=res://tests/helpers/export_results.gd', '-gdisable_colors', "-glog=$logLevel")
    if ($filter) { $arguments += "-gselect=$filter" }
    $resultPath = Join-Path $partDirectory 'results.json'
    [pscustomobject]@{ Part=$part; Directory=$partDirectory; ResultPath=$resultPath; Handle=(Start-TestProcess $arguments $partDirectory $resultPath) }
}

. (Join-Path $PSScriptRoot 'tools/test_gate.ps1')
$failures = [Collections.Generic.List[string]]::new()
$totalTests = 0
foreach ($run in $handles) {
    $result = Wait-TestProcess $run.Handle (Join-Path $run.Directory 'stdout.log') (Join-Path $run.Directory 'stderr.log')
    $stdout = $result.Stdout
    $stderr = $result.Stderr
    if ($parts.Count -gt 1) { Write-Host "=== $($run.Part.Name) ===" }
    if ($full -or $verbose) { Write-Host $stdout } else {
        $stdout -split '\r?\n' | Where-Object { $_ -match '^(Totals|Tests |Passing Tests |Scripts |Asserts |Orphans |Time |Risky/Pending )|\[(Failed|Risky|Error)\]' } | ForEach-Object { Write-Host $_ }
    }
    # Always surface stderr; expected validation warnings remain informational.
    if ($stderr) { Write-Host $stderr }
    if ($result.TimedOut) { $failures.Add("$($run.Part.Name): tests exceeded ${timeout}s. See $($run.Directory)"); continue }
    try {
        if (-not (Test-Path $run.ResultPath)) { throw 'GUT did not produce a completed result file.' }
        $results = Get-Content $run.ResultPath -Raw | ConvertFrom-Json
        Assert-CleanTestRun -ExitCode $result.ExitCode -Stdout $stdout -Stderr $stderr -Results $results
        $totalTests += $results.test_scripts.props.tests
    } catch { $failures.Add("$($run.Part.Name): $($_.Exception.Message)") }
}
if ($failures.Count -gt 0) { throw ($failures -join '; ') }
Write-Host "All $totalTests tests passed with no risky tests, unexpected errors, or remaining orphans." -ForegroundColor Green
