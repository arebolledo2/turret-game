# Exercise the release gate with deliberately bad runner results.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'test_gate.ps1')
function New-Result {
    return @{ test_scripts = @{ props = @{ tests=1; passing=1; failures=0; pending=0; risky=0; errors=0; orphans=0 } } }
}
Assert-CleanTestRun -ExitCode 0 -Results (New-Result)
$cases = @('failures', 'pending', 'risky', 'errors', 'orphans', 'empty', 'missing', 'stderr', 'exit')
foreach ($case in $cases) {
    $result = New-Result
    $code = 0
    $stderr = ''
    switch ($case) {
        'empty' { $result.test_scripts.props.tests = 0; $result.test_scripts.props.passing = 0 }
        'missing' { $result.test_scripts.props.Remove('tests') }
        'stderr' { $stderr = "SCRIPT ERROR: startup failed" }
        'exit' { $code = 1 }
        default { $result.test_scripts.props[$case] = 1 }
    }
    $rejected = $false
    try { Assert-CleanTestRun -ExitCode $code -Stderr $stderr -Results $result } catch { $rejected = $true }
    if (-not $rejected) { throw "Gate accepted invalid case: $case" }
}
Write-Host 'Test gate: clean run accepted; all 9 invalid cases rejected.'

$result = New-Result
$result.expected_engine_errors = @('expected parse error')
Assert-CleanTestRun -ExitCode 0 -Stderr 'ERROR: expected parse error' -Results $result
$rejected = $false
try { Assert-CleanTestRun -ExitCode 0 -Stderr "ERROR: expected parse error`nERROR: expected parse error" -Results $result } catch { $rejected = $true }
if (-not $rejected) { throw 'Gate allowed an extra unasserted occurrence.' }
