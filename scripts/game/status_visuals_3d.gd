class_name StatusVisuals3D
extends RefCounted

## Burning flames and crackling electric shells drawn over enemies. `CombatEffects3D` owns one and ticks it; the overlays are
## children of `host`, pooled and capped so a crowd cannot grow them without bound.
const SHOCK_MARK_SECONDS: float = .8
const MAX_SHOCK_VISUALS: int = 32
const MAX_BURN_VISUALS: int = 32
var host: CombatEffects3D
## Enemy -> host.visual_time at which its brief electric-hit mark expires; the Shocked overlay also shows while an electric slow lasts.
var shock_marks: Dictionary = {}
var shock_visuals: Dictionary = {}
var shock_pool: Array[MeshInstance3D] = []
var shock_shader := preload("res://assets/shaders/shocked_actor.gdshader")
var burn_visuals: Dictionary = {}

func _init(owner: CombatEffects3D) -> void:
	host = owner

## An electric hit lights the shell briefly even if it applies no lasting slow.
func mark_shocked(actor: CombatActor) -> void:
	shock_marks[actor] = host.visual_time + SHOCK_MARK_SECONDS

func update() -> void:
	update_burns()
	update_shocks()

func reset() -> void:
	for flame in burn_visuals.values():
		flame.queue_free()
	burn_visuals.clear()
	for actor in shock_visuals.keys():
		_release_shock_visual(actor)
	shock_marks.clear()

func update_burns() -> void:
	for actor in burn_visuals.keys():
		if not is_instance_valid(actor) or actor.dead or actor.statuses.burn_remaining <= 0.0:
			burn_visuals[actor].queue_free()
			burn_visuals.erase(actor)
	for actor in host.world.enemies:
		if not is_instance_valid(actor) or actor.dead or actor.statuses.burn_remaining <= 0.0:
			continue
		if not burn_visuals.has(actor) and burn_visuals.size() < MAX_BURN_VISUALS:
			var flame := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(1.7, 1.9) * actor.body_scale
			flame.mesh = quad
			var material := ShaderMaterial.new()
			material.shader = preload("res://assets/shaders/burning_actor.gdshader")
			material.set_shader_parameter("motion_speed", GameConstants.REDUCED_MOTION_SPEED if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION) else 1.0)
			flame.material_override = material
			flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			host.add_child(flame)
			burn_visuals[actor] = flame
		if burn_visuals.has(actor):
			var flame: MeshInstance3D = burn_visuals[actor]
			flame.position = actor.position + Vector3.UP * .7 * actor.body_scale
			(flame.material_override as ShaderMaterial).set_shader_parameter("visual_time", host.visual_time)
			flame.rotation.y = host.world.camera.global_rotation.y

func _is_shocked(actor: CombatActor) -> bool:
	return float(shock_marks.get(actor, -1.0)) > host.visual_time or actor.statuses.effects.has(GameEnums.DamageType.ELECTRIC)

## Crackling electric shell on enemies that were just hit by electricity or are still slowed by it.
func update_shocks() -> void:
	for actor in shock_marks.keys():
		if not is_instance_valid(actor) or float(shock_marks[actor]) <= host.visual_time:
			shock_marks.erase(actor)
	for actor in shock_visuals.keys():
		if not is_instance_valid(actor) or actor.dead or not _is_shocked(actor):
			_release_shock_visual(actor)
	var motion := GameConstants.REDUCED_MOTION_SPEED if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION) else 1.0
	for actor in host.world.enemies:
		if not is_instance_valid(actor) or actor.dead or not _is_shocked(actor):
			continue
		if not shock_visuals.has(actor):
			if shock_visuals.size() >= MAX_SHOCK_VISUALS:
				continue
			shock_visuals[actor] = _take_shock_visual(actor)
		var overlay: MeshInstance3D = shock_visuals[actor]
		var material := overlay.material_override as ShaderMaterial
		material.set_shader_parameter("visual_time", host.visual_time)
		material.set_shader_parameter("motion_speed", motion)
		# Face the camera and sit just in front of the body so the model does not hide it.
		overlay.global_basis = host.world.camera.global_basis
		overlay.position = actor.position + Vector3.UP * .65 * actor.body_scale + host.world.camera.global_basis.z * .6 * actor.body_scale

func _take_shock_visual(actor: CombatActor) -> MeshInstance3D:
	var overlay: MeshInstance3D
	if shock_pool.is_empty():
		overlay = MeshInstance3D.new()
		overlay.mesh = QuadMesh.new()
		var material := ShaderMaterial.new()
		material.shader = shock_shader
		overlay.material_override = material
		overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		host.add_child(overlay)
	else:
		overlay = shock_pool.pop_back()
	(overlay.mesh as QuadMesh).size = Vector2(1.6, 1.8) * actor.body_scale
	(overlay.material_override as ShaderMaterial).set_shader_parameter("seed", float(actor.get_instance_id() % 97))
	overlay.visible = true
	return overlay

func _release_shock_visual(actor: Variant) -> void:
	var overlay: MeshInstance3D = shock_visuals[actor]
	overlay.visible = false
	shock_pool.append(overlay)
	shock_visuals.erase(actor)
