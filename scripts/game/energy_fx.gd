class_name EnergyFx
extends RefCounted

## Shared glow materials for projectiles and pickups. One ShaderMaterial per look keeps the pooled actors cheap.
const TRAIL: Shader = preload("res://assets/shaders/energy_trail.gdshader")
const ORB: Shader = preload("res://assets/shaders/energy_orb.gdshader")
const GROUND: Shader = preload("res://assets/shaders/ground_glow.gdshader")
const KINDS: Dictionary = {
	"ion": {"core": Color(.85, 1.0, 1.0), "glow": Color(.1, .85, 1.0)},
	"plasma": {"core": Color(1.0, .88, 1.0), "glow": Color(.62, .22, 1.0)},
}

static var cache: Dictionary = {}

static func trail_material(kind: String) -> ShaderMaterial:
	return _cached("trail_" + kind, TRAIL, KINDS[kind])

static func orb_material(kind: String) -> ShaderMaterial:
	return _cached("orb_" + kind, ORB, KINDS[kind])

static func ground_glow_material() -> ShaderMaterial:
	return _cached("ground", GROUND, {"glow": Color(1.0, .6, .15)})

static func _cached(key: String, shader: Shader, colors: Dictionary) -> ShaderMaterial:
	if not cache.has(key):
		var material := ShaderMaterial.new()
		material.shader = shader
		if colors.has("core"):
			material.set_shader_parameter("core_color", colors["core"])
		material.set_shader_parameter("glow_color", colors["glow"])
		cache[key] = material
	return cache[key]
