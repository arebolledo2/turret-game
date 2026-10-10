class_name ClockworkModels
extends RefCounted

## Separate from the generated legacy manifest. --legacy-assets supports visual/performance A/B runs.
const KEYS: Array[String] = ["ion", "plasma", "tesla", "shock", "melee", "basic", "fast", "tank", "charger", "exploder", "hero", "dropbox", "core"]
static var scenes: Dictionary = {}

static func available(key: String) -> bool:
	return not "--legacy-assets" in OS.get_cmdline_user_args() and ResourceLoader.exists(model_path(key))

static func model_path(key: String) -> String:
	return "res://assets/models/clockwork/cp_%s.glb" % key

static func instantiate(key: String) -> Node3D:
	if not scenes.has(key):
		scenes[key] = load(model_path(key)) as PackedScene
	return (scenes[key] as PackedScene).instantiate() as Node3D
