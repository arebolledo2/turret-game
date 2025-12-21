$content = Get-Content "scripts/autoload/globals.gd" -Raw

$content = $content -replace '_difficulty_service\.', '(_get_difficulty_service()).'
$content = $content -replace '_game_state_service\.', '(_get_game_state_service()).'
$content = $content -replace '_economy_service\.', '(_get_economy_service()).'
$content = $content -replace '_player_stats_service\.', '(_get_player_stats_service()).'
$content = $content -replace '_turret_stats_service\.', '(_get_turret_stats_service()).'
$content = $content -replace '_item_tracking_service\.', '(_get_item_tracking_service()).'
$content = $content -replace '_modifier_service\.', '(_get_modifier_service()).'

Set-Content "scripts/autoload/globals.gd" -Value $content
