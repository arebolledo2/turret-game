extends Node

var preferences_path: String = "user://game_preferences.cfg"
var fullscreen: bool = false
var vsync: bool = true
var sfx_volume: float = .7

func _ready() -> void:
	load_preferences()

func load_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(preferences_path) == OK:
		var saved_fullscreen: Variant = config.get_value("display", "fullscreen", false)
		var saved_vsync: Variant = config.get_value("display", "vsync", true)
		var saved_motion: Variant = config.get_value("accessibility", "reduced_motion", false)
		if saved_fullscreen is bool:
			fullscreen = saved_fullscreen
		if saved_vsync is bool:
			vsync = saved_vsync
		if saved_motion is bool:
			FeatureFlagService.set_enabled(FeatureFlagService.REDUCED_MOTION, saved_motion)
		var saved_volume: Variant = config.get_value("audio", "sfx_volume", .7)
		if (saved_volume is float or saved_volume is int) and is_finite(float(saved_volume)):
			sfx_volume = clampf(float(saved_volume), 0.0, 1.0)
	apply_audio_preferences()
	apply_display_preferences()

func save_preferences() -> Error:
	var config := ConfigFile.new()
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "vsync", vsync)
	config.set_value("accessibility", "reduced_motion", FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION))
	config.set_value("audio", "sfx_volume", sfx_volume)
	return config.save(preferences_path)

func apply_display_preferences() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

func apply_audio_preferences() -> void:
	var bus := AudioServer.get_bus_index("SFX")
	if bus < 0:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, "SFX")
	AudioServer.set_bus_mute(bus, sfx_volume <= 0.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(sfx_volume, .0001)))

func set_sfx_volume(value: float, persist: bool = true) -> void:
	if not is_finite(value):
		return
	sfx_volume = clampf(value, 0.0, 1.0)
	apply_audio_preferences()
	if persist:
		save_preferences()

func set_fullscreen(enabled: bool, persist: bool = true) -> void:
	fullscreen = enabled
	apply_display_preferences()
	if persist:
		save_preferences()

func set_vsync(enabled: bool, persist: bool = true) -> void:
	vsync = enabled
	apply_display_preferences()
	if persist:
		save_preferences()

func set_reduced_motion(enabled: bool, persist: bool = true) -> void:
	FeatureFlagService.set_enabled(FeatureFlagService.REDUCED_MOTION, enabled)
	if persist:
		save_preferences()

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
	# Explicit test/debug reset. RunSession keeps app preferences across runs.
	FeatureFlagService.reset_state()
	reset_debug_state()


func reset_debug_state() -> void:
	debug_hitbox_flags[GameEnums.HitboxType.PHYSICS] = false
	debug_hitbox_flags[GameEnums.HitboxType.PLAYER_HURTBOX] = false
	debug_hitbox_flags[GameEnums.HitboxType.ENEMY_HURTBOX] = false
	debug_hitbox_flags[GameEnums.HitboxType.PLAYER_ATTACK] = false
