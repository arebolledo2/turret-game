extends Node

## Settings Service
## Manages runtime preferences and debug flags

var show_damage_numbers: bool = true
var player_auto_attack_enabled: bool = false
var show_turret_ranges: bool = false
var isometric_debug_enabled: bool = false

var debug_hitbox_flags: Dictionary = {
	GameEnums.HitboxType.PHYSICS: false,
	GameEnums.HitboxType.PLAYER_HURTBOX: false,
	GameEnums.HitboxType.ENEMY_HURTBOX: false,
	GameEnums.HitboxType.PLAYER_ATTACK: false
}

func reset_state() -> void:
	# Resets to defaults
	show_damage_numbers = true
	player_auto_attack_enabled = false
	show_turret_ranges = false
	isometric_debug_enabled = false
	
	debug_hitbox_flags[GameEnums.HitboxType.PHYSICS] = false
	debug_hitbox_flags[GameEnums.HitboxType.PLAYER_HURTBOX] = false
	debug_hitbox_flags[GameEnums.HitboxType.ENEMY_HURTBOX] = false
	debug_hitbox_flags[GameEnums.HitboxType.PLAYER_ATTACK] = false
