class_name ClockworkModels
extends RefCounted

## Separate from the generated legacy manifest. --legacy-assets supports visual/performance A/B runs.
const KEYS: Array[String] = ["broadside_baron", "frostforge_yeti", "skyfall_kestrel", "crucible_crab", "pendulum_regent", "crownwheel_colossus", "ion", "plasma", "tesla", "shock", "melee", "basic", "fast", "tank", "charger", "exploder", "hero", "dropbox", "core", "machine_gun", "scatter", "saber", "gatling", "crossfire", "siege", "bow", "flamethrower", "bowling", "gunblade", "arrow", "bowling_ball", "drowse", "hopper", "kite", "lobber", "tender", "skitter", "brass_ram", "prism_conductor", "grand_marionettist", "lens", "anchor", "puppet", "focused_lance", "resonator", "thunder_pin", "thunder_spear", "resonance_engine", "thunderhead", "storm_network", "sniper", "quake", "decoy"]
static var scenes: Dictionary = {}

static var _availability: Dictionary = {}
static var _legacy_assets: int = -1

static func available(key: String) -> bool:
	if _legacy_assets < 0:
		_legacy_assets = 1 if "--legacy-assets" in OS.get_cmdline_user_args() else 0
	if _legacy_assets == 1:
		return false
	if not _availability.has(key):
		_availability[key] = ResourceLoader.exists(model_path(key))
	return _availability[key]

static func model_path(key: String) -> String:
	return "res://assets/models/clockwork/cp_%s.glb" % key

static func instantiate(key: String) -> Node3D:
	if not scenes.has(key):
		scenes[key] = load(model_path(key)) as PackedScene
	return (scenes[key] as PackedScene).instantiate() as Node3D
