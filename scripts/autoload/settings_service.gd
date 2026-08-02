extends Node

## Settings Service
## Manages runtime preferences and debug flags

## Backward-compatible settings facade. New systems should query
## FeatureFlagService directly; existing callers can keep using these names.
var show_damage_numbers: bool:
	get:
		return FeatureFlagService.is_enabled(FeatureFlagService.SHOW_DAMAGE_NUMBERS, true)
	set(value):
		FeatureFlagService.set_enabled(FeatureFlagService.SHOW_DAMAGE_NUMBERS, value)

var player_auto_attack_enabled: bool:
	get:
		return FeatureFlagService.is_enabled(FeatureFlagService.PLAYER_AUTO_ATTACK, true)
	set(value):
		FeatureFlagService.set_enabled(FeatureFlagService.PLAYER_AUTO_ATTACK, value)

var show_turret_ranges: bool:
	get:
		return FeatureFlagService.is_enabled(FeatureFlagService.SHOW_TURRET_RANGES, false)
	set(value):
		FeatureFlagService.set_enabled(FeatureFlagService.SHOW_TURRET_RANGES, value)

var isometric_debug_enabled: bool:
	get:
		return FeatureFlagService.is_enabled(FeatureFlagService.ISOMETRIC_DEBUG, false)
	set(value):
		FeatureFlagService.set_enabled(FeatureFlagService.ISOMETRIC_DEBUG, value)

var debug_hitbox_flags: Dictionary = {
	GameEnums.HitboxType.PHYSICS: false,
	GameEnums.HitboxType.PLAYER_HURTBOX: false,
	GameEnums.HitboxType.ENEMY_HURTBOX: false,
	GameEnums.HitboxType.PLAYER_ATTACK: false
}

func reset_state() -> void:
	# Resets all settings flags to defaults. GameManager intentionally uses
	# reset_debug_state() between runs so user-selected settings persist.
	FeatureFlagService.reset_state()
	reset_debug_state()


func reset_debug_state() -> void:
	debug_hitbox_flags[GameEnums.HitboxType.PHYSICS] = false
	debug_hitbox_flags[GameEnums.HitboxType.PLAYER_HURTBOX] = false
	debug_hitbox_flags[GameEnums.HitboxType.ENEMY_HURTBOX] = false
	debug_hitbox_flags[GameEnums.HitboxType.PLAYER_ATTACK] = false
