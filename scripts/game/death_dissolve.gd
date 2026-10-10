class_name DeathDissolve
extends Node3D

## Plays an enemy's model out as a noise dissolve after it dies. The actor frees immediately (gameplay never waits
## on this); its Visual node is handed over here and every surface is swapped for a dissolve copy of its material.
const SHADER: Shader = preload("res://assets/shaders/dissolve.gdshader")
const DURATION: float = 0.45
const MAX_CORPSES: int = 40 # a mass wipe skips the effect rather than piling up per-frame material updates

static var active_count: int = 0

var materials: Array[ShaderMaterial] = []
var age: float = 0.0

static func spawn(parent: Node3D, actor: CombatActor) -> DeathDissolve:
	if active_count >= MAX_CORPSES or not is_instance_valid(actor.visual):
		return null
	var corpse := DeathDissolve.new()
	parent.add_child(corpse)
	corpse.global_transform = actor.global_transform
	actor.visual.reparent(corpse) # keeps the global transform, so the model stays exactly where it died
	corpse._convert(actor.visual, maxf(actor.body_scale, .1))
	corpse.reset_physics_interpolation()
	return corpse

func _enter_tree() -> void:
	active_count += 1

func _exit_tree() -> void:
	active_count -= 1

func _convert(model: Node, body_scale: float) -> void:
	var by_source: Dictionary = {} # surfaces sharing a source material share one dissolve copy
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.material_overlay = null # drop any hit-flash still attached
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface) as BaseMaterial3D
			if not source:
				continue
			if not by_source.has(source):
				by_source[source] = _dissolve_copy(source, body_scale)
			mesh.set_surface_override_material(surface, by_source[source])

func _dissolve_copy(source: BaseMaterial3D, body_scale: float) -> ShaderMaterial:
	var copy := ShaderMaterial.new()
	copy.shader = SHADER
	copy.set_shader_parameter("albedo_color", source.albedo_color)
	if source.albedo_texture:
		copy.set_shader_parameter("albedo_tex", source.albedo_texture)
	copy.set_shader_parameter("use_vertex_color", source.vertex_color_use_as_albedo)
	copy.set_shader_parameter("metallic", source.metallic)
	copy.set_shader_parameter("roughness", source.roughness)
	if source.emission_enabled:
		copy.set_shader_parameter("emission_color", source.emission)
		copy.set_shader_parameter("emission_energy", source.emission_energy_multiplier)
	copy.set_shader_parameter("model_height", .9 * body_scale)
	copy.set_shader_parameter("progress", 0.0)
	materials.append(copy)
	return copy

func _process(delta: float) -> void:
	age += delta
	var progress := clampf(age / DURATION, 0.0, 1.0)
	for material in materials:
		material.set_shader_parameter("progress", progress)
	if age >= DURATION:
		queue_free()
