class_name DeathShatter
extends Node3D

## Breaks an enemy's model into flying shards when it dies. Like `DeathDissolve`, the actor frees immediately and its
## Visual node is handed over here. The model's meshes are swapped for the pre-fractured ones in the enemy's `ShatterSet`
## (baked by `tools/bake_shatter.gd`, one file per enemy), and `shatter.gdshader` flings the shards on the GPU.
## Per kill that is a handful of property writes plus one instance-uniform write per mesh per frame: no extra nodes,
## physics bodies, tweens or material allocations. An enemy with no baked set (or past the cap) falls back to the dissolve.
const SHADER: Shader = preload("res://assets/shaders/shatter.gdshader")
const DURATION: float = 1.3 # keep in step with `life` in shatter.gdshader
const MAX_ACTIVE: int = 16 # a mass wipe falls back to the dissolve rather than stacking full-model draws
const MAX_SHARED_MATERIALS: int = 48
const MAX_KICK_SPEED: float = 5.0
const CULL_MARGIN: float = 4.0 # shards land well outside the unbroken model's bounds

static var active_count: int = 0
static var _sets: Dictionary = {} # enemy type -> ShatterSet, or null when none was baked
static var _materials: Dictionary = {} # source material -> the shared shatter copy
static var _rng := RandomNumberGenerator.new() # cosmetic only: never the gameplay stream
static var _warmed: bool = false

var age: float = 0.0
var origin: Vector3 = Vector3.ZERO
var meshes: Array[MeshInstance3D] = []

## Loads every baked set up front (a run start is the cheap moment), so the first kill of a type never stalls a frame
## on disk reads and mesh upload (about 35 ms for the beetle).
static func warm_up() -> void:
	if _warmed:
		return
	_warmed = true
	for key in ClockworkModels.KEYS:
		shatter_set(key)

## The baked shards for an enemy type, or null if it has none.
static func shatter_set(key: String) -> ShatterSet:
	if not _sets.has(key):
		var path := ShatterSet.path_for(key)
		var loaded := load(path) as ShatterSet if ResourceLoader.exists(path) and ClockworkModels.available(key) else null
		if loaded:
			_bind_materials(key, loaded)
		_sets[key] = loaded
	return _sets[key]

## Gives every baked surface its shared shatter material once, copied from the model's own materials, so a kill only has
## to swap meshes. Per-surface override writes cost far more than the swap, so they are kept for tinted variants.
static func _bind_materials(key: String, shards: ShatterSet) -> void:
	var model := ClockworkModels.instantiate(key)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		var baked := shards.meshes.get(str(model.get_path_to(instance))) as ArrayMesh
		if baked and baked.get_surface_count() == instance.mesh.get_surface_count():
			for surface in baked.get_surface_count():
				baked.surface_set_material(surface, _shared_material(instance.get_active_material(surface) as BaseMaterial3D))
	model.free()

## Takes over the actor's Visual and shatters it. Returns null (and leaves the Visual untouched) when the enemy has no
## baked shards, reduced motion is on or too many shatters are already running, so the caller can use the dissolve.
static func spawn(parent: Node3D, actor: CombatActor) -> DeathShatter:
	if active_count >= MAX_ACTIVE or not is_instance_valid(actor.visual) or actor.visual.get_child_count() == 0:
		return null
	if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION):
		return null
	var shards := shatter_set(actor.enemy_type)
	var model := actor.visual.get_child(0) as Node3D
	if not shards or not model:
		return null
	var targets := _matching_meshes(model, shards)
	if targets.is_empty():
		return null
	var corpse := DeathShatter.new()
	parent.add_child(corpse)
	corpse.global_transform = actor.global_transform
	actor.visual.reparent(corpse) # keeps the global transform, so the model stays exactly where it died
	corpse.origin = corpse.global_position
	corpse._convert(model, shards, targets, actor.velocity.limit_length(MAX_KICK_SPEED))
	corpse.reset_physics_interpolation()
	return corpse

static func _matching_meshes(model: Node3D, shards: ShatterSet) -> Array[MeshInstance3D]:
	var matches: Array[MeshInstance3D] = []
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var baked := shards.meshes.get(str(model.get_path_to(mesh))) as ArrayMesh
		if baked and mesh.mesh and baked.get_surface_count() == mesh.mesh.get_surface_count():
			matches.append(mesh)
	return matches

func _enter_tree() -> void:
	active_count += 1

func _exit_tree() -> void:
	active_count -= 1

func _convert(model: Node3D, shards: ShatterSet, targets: Array[MeshInstance3D], kick: Vector3) -> void:
	var kick_seed := Vector4(kick.x, kick.y, kick.z, _rng.randf())
	for mesh in targets:
		var sources: Array[Material] = []
		var overridden := false
		for surface in mesh.mesh.get_surface_count():
			sources.append(mesh.get_active_material(surface)) # read before the mesh is swapped out
			overridden = overridden or mesh.get_surface_override_material(surface) != null
		mesh.material_overlay = null # drop any hit-flash still attached
		mesh.mesh = shards.meshes[str(model.get_path_to(mesh))] # already carries the shared shatter materials
		if overridden: # elite tint and the like: carry the variant's look over instead
			for surface in sources.size():
				mesh.set_surface_override_material(surface, _shared_material(sources[surface] as BaseMaterial3D))
		mesh.extra_cull_margin = CULL_MARGIN
		mesh.set_instance_shader_parameter("kick_seed", kick_seed)
		mesh.set_instance_shader_parameter("origin_age", Vector4(origin.x, origin.y, origin.z, 0.0))
		meshes.append(mesh)

## One ShaderMaterial per source material, shared by every corpse (the shader keeps per-corpse state in instance uniforms).
static func _shared_material(source: BaseMaterial3D) -> ShaderMaterial:
	if _materials.has(source):
		return _materials[source]
	if _materials.size() >= MAX_SHARED_MATERIALS:
		_materials.clear() # tinted variants can mint new sources; live corpses keep their copies alive
	var copy := ShaderMaterial.new()
	copy.shader = SHADER
	copy.set_shader_parameter("life", DURATION)
	if source:
		copy.set_shader_parameter("albedo_color", source.albedo_color)
		if source.albedo_texture:
			copy.set_shader_parameter("albedo_tex", source.albedo_texture)
		copy.set_shader_parameter("metallic", source.metallic)
		copy.set_shader_parameter("roughness", source.roughness)
		if source.emission_enabled:
			copy.set_shader_parameter("emission_color", source.emission)
			copy.set_shader_parameter("emission_energy", source.emission_energy_multiplier)
	_materials[source] = copy
	return copy

func _process(delta: float) -> void:
	age += delta
	var state := Vector4(origin.x, origin.y, origin.z, age)
	for mesh in meshes:
		mesh.set_instance_shader_parameter("origin_age", state)
	if age >= DURATION:
		queue_free()
