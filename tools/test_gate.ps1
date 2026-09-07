function Assert-CleanTestRun {
    param([int]$ExitCode, [string]$Stdout, [string]$Stderr, [object]$Results)
    if ($ExitCode -ne 0) { throw "Godot exited with $ExitCode." }
    if (($Stderr + "`n" + $Stdout) -match '(?m)^(SCRIPT ERROR:|ERROR:)|ObjectDB instances leaked|resources still in use') { throw 'Unexpected engine error or resource leak.' }
    $totals = $Results.test_scripts.props
    foreach ($field in @('tests', 'passing', 'failures', 'pending', 'risky', 'errors', 'orphans')) {
        if ($null -eq $totals.$field) { throw "Missing result field: $field" }
    }
    if ($totals.tests -le 0 -or $totals.passing -ne $totals.tests -or $totals.failures -ne 0 -or $totals.pending -ne 0 -or $totals.risky -ne 0 -or $totals.errors -ne 0 -or $totals.orphans -ne 0) {
        throw 'Incomplete or unclean test run.'
    }
}
