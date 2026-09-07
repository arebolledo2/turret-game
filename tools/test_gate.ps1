function Assert-CleanTestRun {
    param([int]$ExitCode, [string]$Stdout, [string]$Stderr, [object]$Results)
    if ($ExitCode -ne 0) { throw "Godot exited with $ExitCode." }
    $unexpected = [Collections.Generic.List[string]]::new()
    foreach ($line in (($Stderr + "`n" + $Stdout) -split '\r?\n')) {
        if ($line -match '^(SCRIPT ERROR:|ERROR:)\s*(.*)$') { $unexpected.Add($Matches[2]) }
        if ($line -match 'ObjectDB instances leaked|resources still in use') { throw 'Resource leak at engine shutdown.' }
    }
    foreach ($expected in $Results.expected_engine_errors) {
        # Remove exactly one matching occurrence, never blanket-ignore a category.
        $null = $unexpected.Remove($expected)
    }
    if ($unexpected.Count -gt 0) { throw "Unexpected engine errors: $($unexpected -join '; ')" }
    $totals = $Results.test_scripts.props
    foreach ($field in @('tests', 'passing', 'failures', 'pending', 'risky', 'errors', 'orphans')) {
        if ($null -eq $totals.$field) { throw "Missing result field: $field" }
    }
    if ($totals.tests -le 0 -or $totals.passing -ne $totals.tests -or $totals.failures -ne 0 -or $totals.pending -ne 0 -or $totals.risky -ne 0 -or $totals.errors -ne 0 -or $totals.orphans -ne 0) {
        throw 'Incomplete or unclean test run.'
    }
}
