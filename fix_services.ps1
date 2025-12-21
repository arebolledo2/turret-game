# Fix TurretStatsService
$content = Get-Content "scripts/autoload/turret_stats_service.gd" -Raw
$content = $content -replace 'var modifier_service: ModifierService\s+func _ready\(\) -> void:\s+# Get reference to ModifierService\s+modifier_service = get_node\("/root/ModifierService"\)', 'var _modifier_service: ModifierService = null

func _get_modifier_service() -> ModifierService:
	if _modifier_service == null:
		_modifier_service = get_node("/root/ModifierService")
	return _modifier_service'
$content = $content -replace 'modifier_service\.', '_get_modifier_service().'
Set-Content "scripts/autoload/turret_stats_service.gd" -Value $content

# Fix ItemTrackingService
$content = Get-Content "scripts/autoload/item_tracking_service.gd" -Raw
$content = $content -replace 'var modifier_service: ModifierService\s+func _ready\(\) -> void:\s+# Get reference to ModifierService\s+modifier_service = get_node\("/root/ModifierService"\)', 'var _modifier_service: ModifierService = null

func _get_modifier_service() -> ModifierService:
	if _modifier_service == null:
		_modifier_service = get_node("/root/ModifierService")
	return _modifier_service'
$content = $content -replace 'modifier_service\.', '_get_modifier_service().'
Set-Content "scripts/autoload/item_tracking_service.gd" -Value $content

Write-Host "Fixed services!"
