extends Node

# Autoload singleton for global events (signal bus)
# Add to Project Settings > Autoload as "Events"
# World combat notifications live on the run-owned Combat3D, not here.

signal modifiers_changed() # Emitted when items are purchased/modifiers added
signal feature_flag_changed(flag_id: String, enabled: bool)

# Research Events (TechTreeService)
signal research_points_changed(total: int)
signal tech_unlocked(tech_id: String)
signal tech_unlock_failed(tech_id: String, reason: String)

# Game Mode Events (GameModeService)
signal game_mode_changed(group: String, mode_id: int)

# Asset configuration events
signal asset_preset_changed(preset_name: String)
signal asset_config_changed(entity_kind: int, asset_id: String)
