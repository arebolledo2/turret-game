class_name CombatEffects3D
extends Node3D

## Bounded, reusable cosmetic effects. Lifetime advances only with simulation.
const MAX_PULSES: int = 32
const MAX_SPARKS: int = 24
const MAX_ARCS: int = 16
const ARC_LIFETIME: float = .26
## The bolt's shape is re-rolled this often while it lives, which is what makes it crackle instead of sit still.
const ARC_REROLL_INTERVAL: float = .05
## Each chain jump lights this much later than the one before it, so the chain visibly travels.
const ARC_HOP_DELAY: float = .045
## Midpoint-displacement passes for the main bolt (2^n + 1 points) and for its forks.
const BOLT_PASSES: int = 5
const FORK_PASSES: int = 3
const BOLT_JAG: float = .26
const BOLT_HALF_WIDTH: float = .15
const MAX_ARC_LIGHTS: int = 4
const ARC_LIGHT_LIFETIME: float = .14
const ARC_LIGHT_ENERGY: float = 3.0
const SHOCK_MARK_SECONDS: float = .8
const MAX_SHOCK_VISUALS: int = 32
const MAX_BURSTS: int = 16
const BURST_PARTICLES: int = 14
const BURST_LIFETIME: float = .5
## Per-kind spark bursts: colour, launch speed range and gravity. Colours are overbright so they bloom.
const BURSTS: Dictionary = {
	"ion": {"color": Color(.45, 1.0, 1.0), "speed": Vector2(1.6, 3.6), "gravity": -7.0},
	"plasma": {"color": Color(.78, .4, 1.0), "speed": Vector2(1.4, 3.2), "gravity": -4.0},
	"shock": {"color": Color(.4, .85, 1.0), "speed": Vector2(2.0, 4.2), "gravity": -3.0},
	"fire": {"color": Color(1.0, .55, .15), "speed": Vector2(1.2, 2.8), "gravity": 1.5},
	"hurt": {"color": Color(1.0, .3, .22), "speed": Vector2(1.8, 3.8), "gravity": -6.0},
	"scrap": {"color": Color(1.0, .75, .25), "speed": Vector2(1.4, 3.0), "gravity": -9.0},
}
var bursts: Array[GPUParticles3D] = []
var next_burst: int = 0
var burst_mesh: QuadMesh
var burst_materials: Dictionary = {}
var arcs: Array[MeshInstance3D] = []
var arc_lifetimes: Array[float] = []
## Per-arc endpoints (from, to), seconds until the arc lights, and seconds until its shape is next re-rolled.
var arc_ends: Array[PackedVector3Array] = []
var arc_delays: Array[float] = []
var arc_rerolls: Array[float] = []
var arc_lights: Array[OmniLight3D] = []
var arc_light_ages: Array[float] = []
var next_arc_light: int = 0
## Decorative noise only: its own stream, so bolt shapes never consume the combat random stream.
var bolt_rng := RandomNumberGenerator.new()
var arc_shader := preload("res://assets/shaders/lightning_bolt.gdshader")
## Enemy -> visual_time at which its brief electric-hit mark expires; the Shocked overlay also shows while an electric slow lasts.
var shock_marks: Dictionary = {}
var shock_visuals: Dictionary = {}
var shock_pool: Array[MeshInstance3D] = []
var shock_shader := preload("res://assets/shaders/shocked_actor.gdshader")
var sparks: Array[MeshInstance3D] = []
var spark_lifetimes: Array[float] = []
var spark_mesh: SphereMesh
var hit_material := WorldGeometry.material(Color("ffd78a"), true)
var hull_material := WorldGeometry.material(Color("ff675a"), true)
var pulses: Array[MeshInstance3D] = []
var ages: Array[float] = []
var radii: Array[float] = []
var flame_material := WorldGeometry.material(Color(2.5, .65, .08), true)
var damage_numbers := DamageNumbers3D.new()
var visual_time := 0.0
var world: ArenaWorld
var plasma_material := WorldGeometry.material(Color("b56cff"), true)
var shock_material := WorldGeometry.material(Color("55dcff"), true)

func _ready() -> void:
	bolt_rng.seed = 20260711
	add_child(damage_numbers)

func show_hit(actor: Node3D, hit: CombatHit3D, _amount: float) -> void:
	var enemy := (actor as CombatActor).is_enemy
	if enemy and hit.damage_type == GameEnums.DamageType.ELECTRIC:
		shock_marks[actor] = visual_time + SHOCK_MARK_SECONDS
	damage_numbers.show_damage(actor, _amount, not enemy, hit.critical, hit.damage_type == GameEnums.DamageType.FIRE)
	show_burst(actor.position + Vector3(0, .5, 0), _burst_kind(hit.damage_type) if enemy else "hurt")
	_show_spark(actor.position + Vector3(0, .45, 0), hit_material if enemy else hull_material,
		.10 if enemy else .18, .10 if enemy else .16)

func _burst_kind(damage_type: int) -> String:
	match damage_type:
		GameEnums.DamageType.PLASMA:
			return "plasma"
		GameEnums.DamageType.ELECTRIC:
			return "shock"
		GameEnums.DamageType.FIRE:
			return "fire"
	return "ion"

## One-shot GPU spark burst from a fixed pool; the oldest burst is recycled when the pool is full.
func show_burst(at: Vector3, kind: String) -> void:
	var index := next_burst
	if bursts.size() < MAX_BURSTS:
		index = bursts.size()
		bursts.append(_make_burst())
	else:
		next_burst = (next_burst + 1) % MAX_BURSTS
	var burst := bursts[index]
	burst.process_material = _burst_material(kind)
	burst.position = at
	burst.restart()

func _make_burst() -> GPUParticles3D:
	if not burst_mesh:
		burst_mesh = QuadMesh.new()
		burst_mesh.size = Vector2(.13, .13)
		var glow := Gradient.new()
		glow.set_color(0, Color.WHITE)
		glow.set_color(1, Color(0, 0, 0, 0))
		var texture := GradientTexture2D.new()
		texture.gradient = glow
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(.5, .5)
		texture.fill_to = Vector2(.5, 0.0)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		material.vertex_color_use_as_albedo = true
		material.albedo_texture = texture
		material.albedo_color = Color(1.8, 1.8, 1.8)
		burst_mesh.material = material
	var particles := GPUParticles3D.new()
	particles.amount = BURST_PARTICLES
	particles.lifetime = BURST_LIFETIME
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = false
	particles.local_coords = false
	particles.draw_pass_1 = burst_mesh
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	return particles

func _burst_material(kind: String) -> ParticleProcessMaterial:
	if burst_materials.has(kind):
		return burst_materials[kind]
	var preset: Dictionary = BURSTS[kind]
	var colour: Color = preset["color"]
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = .06
	material.direction = Vector3.UP
	material.spread = 180.0
	var speed: Vector2 = preset["speed"]
	material.initial_velocity_min = speed.x
	material.initial_velocity_max = speed.y
	material.gravity = Vector3(0, float(preset["gravity"]), 0)
	material.damping_min = 3.0
	material.damping_max = 6.0
	var ramp := Gradient.new()
	ramp.set_color(0, colour.lerp(Color.WHITE, .55))
	ramp.add_point(.15, colour)
	ramp.set_color(ramp.get_point_count() - 1, Color(colour.r, colour.g, colour.b, 0.0))
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	material.color_ramp = ramp_texture
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, .1))
	var shrink_texture := CurveTexture.new()
	shrink_texture.curve = shrink
	material.scale_curve = shrink_texture
	material.scale_min = .6
	material.scale_max = 1.2
	burst_materials[kind] = material
	return material

func show_muzzle(at: Vector3, damage_type: int) -> void:
	_show_spark(at, plasma_material if damage_type == GameEnums.DamageType.PLASMA else hit_material, .09, .065)

func _show_spark(at: Vector3, material: Material, radius: float, lifetime: float) -> void:
	var index := spark_lifetimes.find(0.0)
	if index < 0:
		if sparks.size() >= MAX_SPARKS:
			return
		if not spark_mesh:
			spark_mesh = SphereMesh.new()
			spark_mesh.radius = 1.0
			spark_mesh.height = 2.0
			spark_mesh.radial_segments = 8
			spark_mesh.rings = 4
		index = sparks.size()
		var spark := MeshInstance3D.new()
		spark.mesh = spark_mesh
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(spark)
		sparks.append(spark)
		spark_lifetimes.append(0.0)
	var spark := sparks[index]
	spark.material_override = material
	spark.position = at
	spark.scale = Vector3.ONE * radius
	spark.visible = true
	spark_lifetimes[index] = lifetime

## Queues one lightning bolt. `hop` is the chain jump number (0 = first strike); later hops light a beat after the one
## before so the chain visibly travels. The bolt's shape is decorative and never touches the combat random stream.
func show_arc(from: Vector3, to: Vector3, hop: int = 0) -> void:
	if from.distance_squared_to(to) < .0001:
		return
	var index := arc_lifetimes.find(0.0)
	if index < 0:
		if arcs.size() >= MAX_ARCS:
			return
		var arc := MeshInstance3D.new()
		arc.mesh = ImmediateMesh.new()
		var material := ShaderMaterial.new()
		material.shader = arc_shader
		arc.material_override = material
		arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arc.visible = false
		add_child(arc)
		arcs.append(arc)
		arc_lifetimes.append(0.0)
		arc_ends.append(PackedVector3Array())
		arc_delays.append(0.0)
		arc_rerolls.append(0.0)
		index = arcs.size() - 1
	arc_ends[index] = PackedVector3Array([from, to])
	arc_delays[index] = maxi(hop, 0) * ARC_HOP_DELAY
	arc_lifetimes[index] = ARC_LIFETIME
	arcs[index].visible = false
	if arc_delays[index] <= 0.0:
		_start_arc(index)

## Lights a queued arc: first frame of its shape, the impact burst, and the short light flash at the strike point.
func _start_arc(index: int) -> void:
	var material := arcs[index].material_override as ShaderMaterial
	material.set_shader_parameter("age", 0.0)
	material.set_shader_parameter("reduced_motion", FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION))
	arc_rerolls[index] = ARC_REROLL_INTERVAL
	_build_bolt(index)
	arcs[index].visible = true
	var to := arc_ends[index][1]
	show_burst(to, "shock")
	_show_spark(to, shock_material, .18, .08)
	_flash_light(to + Vector3(0, .6, 0))

func _update_arcs(delta: float) -> void:
	var reduced := FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION)
	for index in range(arcs.size()):
		if arc_lifetimes[index] <= 0.0:
			arcs[index].visible = false
			continue
		if arc_delays[index] > 0.0:
			arc_delays[index] -= delta
			if arc_delays[index] <= 0.0:
				arc_delays[index] = 0.0
				_start_arc(index)
			continue
		arc_lifetimes[index] = maxf(0.0, arc_lifetimes[index] - delta)
		arcs[index].visible = arc_lifetimes[index] > 0.0
		if not arcs[index].visible:
			continue
		(arcs[index].material_override as ShaderMaterial).set_shader_parameter("age", 1.0 - arc_lifetimes[index] / ARC_LIFETIME)
		arc_rerolls[index] -= delta
		if arc_rerolls[index] <= 0.0 and not reduced:
			arc_rerolls[index] = ARC_REROLL_INTERVAL
			_build_bolt(index)

## Rebuilds the arc's mesh: one jagged main bolt plus a few fading forks, as camera-facing ribbons.
func _build_bolt(index: int) -> void:
	var mesh := arcs[index].mesh as ImmediateMesh
	mesh.clear_surfaces()
	var from := arc_ends[index][0]
	var to := arc_ends[index][1]
	var length := from.distance_to(to)
	var heading := (to - from) / length
	var spine := _bolt_points(from, to, BOLT_PASSES)
	_add_ribbon(mesh, spine, BOLT_HALF_WIDTH, 1.0, false)
	for fork in range(bolt_rng.randi_range(2, 3)):
		var start := spine[bolt_rng.randi_range(int(spine.size() * .2), int(spine.size() * .8))]
		var turn := deg_to_rad(bolt_rng.randf_range(18.0, 42.0)) * (1.0 if bolt_rng.randf() < .5 else -1.0)
		var tip := start + heading.rotated(Vector3.UP, turn) * length * bolt_rng.randf_range(.16, .3)
		_add_ribbon(mesh, _bolt_points(start, tip, FORK_PASSES), BOLT_HALF_WIDTH * .55, .7, true)

## Midpoint displacement: split every segment, push its midpoint sideways by a fraction of the segment length, repeat.
## Endpoints stay pinned, and the offsets shrink with the segments, which gives the fractal lightning silhouette.
func _bolt_points(from: Vector3, to: Vector3, passes: int) -> PackedVector3Array:
	var points := PackedVector3Array([from, to])
	for _pass in range(passes):
		var refined := PackedVector3Array()
		for i in range(points.size() - 1):
			var a := points[i]
			var b := points[i + 1]
			var along := b - a
			var side := along.cross(Vector3.UP)
			side = side.normalized() if side.length_squared() > .000001 else Vector3.RIGHT
			var push := along.length() * BOLT_JAG
			refined.append(a)
			refined.append((a + b) * .5 + side * bolt_rng.randf_range(-1.0, 1.0) * push + Vector3.UP * bolt_rng.randf_range(-1.0, 1.0) * push * .3)
		refined.append(points[points.size() - 1])
		points = refined
	return points

## Camera-facing triangle strip along `points`. Strength is the shader's per-vertex brightness; forks fade and thin out.
func _add_ribbon(mesh: ImmediateMesh, points: PackedVector3Array, half_width: float, strength: float, taper: bool) -> void:
	var view := Vector3.UP
	if world and world.camera:
		view = world.camera.global_transform.basis.z
	var last := points.size() - 1
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(points.size()):
		var side := (points[mini(i + 1, last)] - points[maxi(i - 1, 0)]).cross(view)
		side = side.normalized() if side.length_squared() > .000001 else Vector3.RIGHT
		var t := float(i) / float(last)
		var width := half_width * (1.0 - t * .85) if taper else half_width
		mesh.surface_set_color(Color(strength * (1.0 - t) if taper else strength, 0.0, 0.0))
		mesh.surface_set_uv(Vector2(0.0, t))
		mesh.surface_add_vertex(points[i] - side * width)
		mesh.surface_set_uv(Vector2(1.0, t))
		mesh.surface_add_vertex(points[i] + side * width)
	mesh.surface_end()

## Short pooled omni flash at a strike so the floor and nearby enemies light up with the bolt.
func _flash_light(at: Vector3) -> void:
	var index := next_arc_light
	if arc_lights.size() < MAX_ARC_LIGHTS:
		index = arc_lights.size()
		var light := OmniLight3D.new()
		light.light_color = Color(.55, .8, 1.0)
		light.omni_range = 4.5
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		arc_lights.append(light)
		arc_light_ages.append(-1.0)
	else:
		next_arc_light = (next_arc_light + 1) % MAX_ARC_LIGHTS
	arc_lights[index].position = at
	arc_lights[index].light_energy = ARC_LIGHT_ENERGY
	arc_lights[index].visible = true
	arc_light_ages[index] = 0.0

func _update_arc_lights(delta: float) -> void:
	var reduced := FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION)
	for index in range(arc_lights.size()):
		if arc_light_ages[index] < 0.0:
			continue
		arc_light_ages[index] += delta
		if arc_light_ages[index] >= ARC_LIGHT_LIFETIME:
			arc_light_ages[index] = -1.0
			arc_lights[index].visible = false
			continue
		var remaining := 1.0 - arc_light_ages[index] / ARC_LIGHT_LIFETIME
		arc_lights[index].light_energy = ARC_LIGHT_ENERGY * (.35 if reduced else 1.0) * remaining * remaining

func show_explosion(at: Vector3, radius: float) -> void:
	_show_pulse(at, radius, Color("b56cff"))

func show_shock(at: Vector3, radius: float) -> void:
	_show_pulse(at, radius, Color("55dcff"))

func _show_pulse(at: Vector3, radius: float, color: Color) -> void:
	var index := ages.find(-1.0)
	if index < 0:
		if pulses.size() >= MAX_PULSES:
			return
		index = pulses.size()
		var pulse := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(2, 2)
		pulse.mesh = plane
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/shaders/combat_pulse.gdshader")
		pulse.material_override = material
		pulse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(pulse)
		pulses.append(pulse)
		ages.append(-1.0)
		radii.append(0.0)
	ages[index] = 0.0
	(pulses[index].material_override as ShaderMaterial).set_shader_parameter("reduced_motion", false)
	(pulses[index].material_override as ShaderMaterial).set_shader_parameter("tint", color)
	radii[index] = radius
	pulses[index].position = WorldGeometry.planar(at) + Vector3(0, .045, 0)
	pulses[index].scale = Vector3(radius, 1, radius)
	(pulses[index].material_override as ShaderMaterial).set_shader_parameter("age", 0.0)
	pulses[index].visible = true
	if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION):
		(pulses[index].material_override as ShaderMaterial).set_shader_parameter("reduced_motion", true)

func _physics_process(delta: float) -> void:
	if GameStateMachine.current_state == GameStateMachine.GameState.GAME_OVER:
		damage_numbers.advance(delta, FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION))
	if not world.is_combat():
		return
	visual_time += delta
	damage_numbers.advance(delta, FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION))
	for index in range(flame_ribbons.size()):
		flame_ages[index] = maxf(0.0, flame_ages[index] - delta)
		flame_ribbons[index].visible = flame_ages[index] > 0.0
		(flame_ribbons[index].material_override as ShaderMaterial).set_shader_parameter("visual_time", visual_time)
	for index in range(sparks.size()):
		spark_lifetimes[index] = maxf(0.0, spark_lifetimes[index] - delta)
		sparks[index].visible = spark_lifetimes[index] > 0.0
	_update_arcs(delta)
	_update_arc_lights(delta)
	for index in range(pulses.size()):
		if ages[index] < 0:
			continue
		ages[index] += delta
		if ages[index] >= .3:
			ages[index] = -1.0
			pulses[index].visible = false
		else:
			var progress := ages[index] / .3
			(pulses[index].material_override as ShaderMaterial).set_shader_parameter("age", progress)
	_update_burns()
	_update_shocks()

var burn_visuals: Dictionary = {}
func _update_burns() -> void:
	for actor in burn_visuals.keys():
		if not is_instance_valid(actor) or actor.dead or actor.statuses.burn_remaining <= 0.0:
			burn_visuals[actor].queue_free()
			burn_visuals.erase(actor)
	for actor in world.enemies:
		if not is_instance_valid(actor) or actor.dead or actor.statuses.burn_remaining <= 0.0:
			continue
		if not burn_visuals.has(actor) and burn_visuals.size() < 32:
			var flame := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(1.7, 1.9) * actor.body_scale
			flame.mesh = quad
			var material := ShaderMaterial.new()
			material.shader = preload("res://assets/shaders/burning_actor.gdshader")
			material.set_shader_parameter("motion_speed", 0.0 if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION) else 1.0)
			flame.material_override = material
			flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(flame)
			burn_visuals[actor] = flame
		if burn_visuals.has(actor):
			var flame: MeshInstance3D = burn_visuals[actor]
			flame.position = actor.position + Vector3.UP * .7 * actor.body_scale
			(flame.material_override as ShaderMaterial).set_shader_parameter("visual_time", visual_time)
			flame.rotation.y = world.camera.global_rotation.y

func _is_shocked(actor: CombatActor) -> bool:
	return float(shock_marks.get(actor, -1.0)) > visual_time or actor.statuses.effects.has(GameEnums.DamageType.ELECTRIC)

## Crackling electric shell on enemies that were just hit by electricity or are still slowed by it.
func _update_shocks() -> void:
	for actor in shock_marks.keys():
		if not is_instance_valid(actor) or float(shock_marks[actor]) <= visual_time:
			shock_marks.erase(actor)
	for actor in shock_visuals.keys():
		if not is_instance_valid(actor) or actor.dead or not _is_shocked(actor):
			_release_shock_visual(actor)
	var motion := 0.0 if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION) else 1.0
	for actor in world.enemies:
		if not is_instance_valid(actor) or actor.dead or not _is_shocked(actor):
			continue
		if not shock_visuals.has(actor):
			if shock_visuals.size() >= MAX_SHOCK_VISUALS:
				continue
			shock_visuals[actor] = _take_shock_visual(actor)
		var overlay: MeshInstance3D = shock_visuals[actor]
		var material := overlay.material_override as ShaderMaterial
		material.set_shader_parameter("visual_time", visual_time)
		material.set_shader_parameter("motion_speed", motion)
		# Face the camera and sit just in front of the body so the model does not hide it.
		overlay.global_basis = world.camera.global_basis
		overlay.position = actor.position + Vector3.UP * .65 * actor.body_scale + world.camera.global_basis.z * .6 * actor.body_scale

func _take_shock_visual(actor: CombatActor) -> MeshInstance3D:
	var overlay: MeshInstance3D
	if shock_pool.is_empty():
		overlay = MeshInstance3D.new()
		overlay.mesh = QuadMesh.new()
		var material := ShaderMaterial.new()
		material.shader = shock_shader
		overlay.material_override = material
		overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(overlay)
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

func reset(preserve_damage: bool = false) -> void:
	for flame in burn_visuals.values():
		flame.queue_free()
	burn_visuals.clear()
	for actor in shock_visuals.keys():
		_release_shock_visual(actor)
	shock_marks.clear()
	for index in range(arc_lights.size()):
		arc_light_ages[index] = -1.0
		arc_lights[index].visible = false
	if not preserve_damage:
		damage_numbers.reset()
	for index in range(flame_ribbons.size()):
		flame_ages[index] = 0.0
		flame_ribbons[index].visible = false
	for burst in bursts:
		burst.emitting = false
	for index in range(sparks.size()):
		spark_lifetimes[index] = 0.0
		sparks[index].visible = false
	for index in range(arcs.size()):
		arc_lifetimes[index] = 0.0
		arc_delays[index] = 0.0
		arcs[index].visible = false
	for index in range(pulses.size()):
		ages[index] = -1.0
		pulses[index].visible = false

## Sample within the actual turret-centered sector, rather than extending range from the muzzle.
var flame_ribbons: Array[MeshInstance3D] = []
var flame_ages: Array[float] = []
var flame_shader := preload("res://assets/shaders/flame_stream.gdshader")

func show_flame(origin: Vector3, heading: Vector3, reach: float, half_angle: float, attack_origin: Vector3) -> void:
	show_burst(origin + heading * minf(.8, reach * .3), "fire")
	var rays := 5 if half_angle > deg_to_rad(20) else 3
	for ray in range(rays):
		var angle := lerpf(-half_angle, half_angle, float(ray) / float(rays - 1))
		var direction := heading.rotated(Vector3.UP, angle)
		var end := attack_origin + direction * reach
		end.y = .45
		var flat := WorldGeometry.planar(end - origin)
		var index := flame_ages.find(0.0)
		if index < 0:
			if flame_ribbons.size() >= 48:
				return
			index = flame_ribbons.size()
			var ribbon := MeshInstance3D.new()
			var mesh := PlaneMesh.new()
			mesh.size = Vector2.ONE
			ribbon.mesh = mesh
			ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var material := ShaderMaterial.new()
			material.shader = flame_shader
			ribbon.material_override = material
			add_child(ribbon)
			flame_ribbons.append(ribbon)
			flame_ages.append(0.0)
		var ribbon := flame_ribbons[index]
		(ribbon.material_override as ShaderMaterial).set_shader_parameter("motion_speed", 0.0 if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION) else 1.0)
		ribbon.position = (origin + end) * .5
		ribbon.rotation.y = atan2(-flat.x, -flat.z)
		ribbon.scale = Vector3(clampf(reach * .35, .4, 1.8), 1.0, flat.length())
		ribbon.visible = true
		flame_ages[index] = .24
