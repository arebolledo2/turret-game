extends Node

var preferences_path: String = "user://game_preferences.cfg"
const WINDOW_SIZE_PRESETS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const MIN_WINDOW_SIZE: Vector2i = Vector2i(640, 360)

var fullscreen: bool = false
## Zero means "keep the project default"; otherwise the preset chosen in settings.
var window_size: Vector2i = Vector2i.ZERO
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
		var saved_width: Variant = config.get_value("display", "window_width", 0)
		var saved_height: Variant = config.get_value("display", "window_height", 0)
		if saved_width is int and saved_height is int and saved_width >= MIN_WINDOW_SIZE.x and saved_height >= MIN_WINDOW_SIZE.y \
				and saved_width <= 7680 and saved_height <= 4320:
			window_size = Vector2i(saved_width, saved_height)
		if saved_vsync is bool:
			vsync = saved_vsync
		if saved_motion is bool:
			FeatureFlagService.set_enabled(FeatureFlagService.REDUCED_MOTION, saved_motion)
		var saved_volume: Variant = config.get_value("audio", "sfx_volume", .7)
		if (saved_volume is float or saved_volume is int) and is_finite(float(saved_volume)):
			sfx_volume = clampf(float(saved_volume), 0.0, 1.0)
		load_dev_flags(config)
	apply_audio_preferences()
	apply_display_preferences()

func save_preferences() -> Error:
	var config := ConfigFile.new()
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "vsync", vsync)
	config.set_value("display", "window_width", window_size.x)
	config.set_value("display", "window_height", window_size.y)
	config.set_value("accessibility", "reduced_motion", FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION))
	config.set_value("audio", "sfx_volume", sfx_volume)
	save_dev_flags(config)
	return config.save(preferences_path)

## Developer and experiment flags persist only in dev builds, so a release build can never load an experiment.
func save_dev_flags(config: ConfigFile) -> void:
	if not FeatureFlagService.is_dev_build():
		return
	for flag_id in FeatureFlagService.get_flag_ids():
		if FeatureFlagService.get_definition(flag_id)["scope"] != FeatureFlagService.SCOPE_USER:
			config.set_value("dev_flags", flag_id, FeatureFlagService.is_enabled(flag_id))

func load_dev_flags(config: ConfigFile) -> void:
	if not FeatureFlagService.is_dev_build() or not config.has_section("dev_flags"):
		return
	for flag_id in FeatureFlagService.get_flag_ids():
		if FeatureFlagService.get_definition(flag_id)["scope"] == FeatureFlagService.SCOPE_USER:
			continue
		var saved: Variant = config.get_value("dev_flags", flag_id, null)
		if saved is bool:
			FeatureFlagService.set_enabled(flag_id, saved)

func apply_display_preferences() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if not fullscreen and window_size != Vector2i.ZERO:
		var usable := DisplayServer.screen_get_usable_rect()
		var fitted := fit_window_size(window_size, usable.size)
		DisplayServer.window_set_size(fitted)
		DisplayServer.window_set_position(usable.position + (usable.size - fitted) / 2)
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

## Shrinks a requested window so its title bar and borders stay on the usable screen area.
static func fit_window_size(requested: Vector2i, usable: Vector2i) -> Vector2i:
	# Reserve room for window decorations around the client area.
	var limit := Vector2i(maxi(usable.x, MIN_WINDOW_SIZE.x), maxi(usable.y - 40, MIN_WINDOW_SIZE.y))
	return Vector2i(clampi(requested.x, MIN_WINDOW_SIZE.x, limit.x), clampi(requested.y, MIN_WINDOW_SIZE.y, limit.y))

func set_window_size(size: Vector2i, persist: bool = true) -> void:
	window_size = size
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

func reset_state() -> void:
	# Explicit test/debug reset. RunSession keeps app preferences across runs.
	FeatureFlagService.reset_state()
