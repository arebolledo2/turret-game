class_name CombatEffects3D
extends Node3D

## Bounded, reusable cosmetic effects. Lifetime advances only with simulation.
const MAX_PULSES: int = 32
const MAX_SPARKS: int = 24
const PULSE_LIFETIME: float = .3
## Friendly Quake colour (rings, telegraphs, fissures): green-teal, distinct from the hostile orange and red telegraphs.
const QUAKE_TINT := Color("6df0b0")
## Friendly Decoy colour (pulse rings, hooks): amber, like its bumpers.
const DECOY_TINT := Color("ffb02e")
## Friendly Scrap Press colour (Academy's ring): brass gold.
const SCRAP_PRESS_TINT := Color("f2c14e")
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
var sparks: Array[MeshInstance3D] = []
var spark_lifetimes: Array[float] = []
var spark_mesh: SphereMesh
var hit_material := WorldGeometry.material(Color("ffd78a"), true)
var hull_material := WorldGeometry.material(Color("ff675a"), true)
var pulses: Array[MeshInstance3D] = []
var ages: Array[float] = []
var radii: Array[float] = []
## Seconds each pulse slot lives (PULSE_LIFETIME unless a travelling wave asks for longer).
var durations: Array[float] = []
var flame_material := WorldGeometry.material(Color(2.5, .65, .08), true)
var damage_numbers := DamageNumbers3D.new()
var visual_time := 0.0
var world: ArenaWorld
## Burning and shocked overlays on enemies.
var status := StatusVisuals3D.new(self)
## Tracers and chain-lightning arcs.
var bolts := BoltEffects3D.new(self)
var plasma_material := WorldGeometry.material(Color("b56cff"), true)
var shock_material := WorldGeometry.material(Color("55dcff"), true)

func _ready() -> void:
	add_child(damage_numbers)

func show_hit(actor: Node3D, hit: CombatHit3D, _amount: float) -> void:
	var enemy := (actor as CombatActor).is_enemy
	if enemy and hit.damage_type == GameEnums.DamageType.ELECTRIC:
		status.mark_shocked(actor)
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

## A straight, brief bright line from `from` to `to` for hit-scan shots.
func show_tracer(from: Vector3, to: Vector3) -> void:
	bolts.show_tracer(from, to)

## Queues one lightning bolt; `hop` is the chain jump number (0 = first strike).
func show_arc(from: Vector3, to: Vector3, hop: int = 0) -> void:
	bolts.show_arc(from, to, hop)

func show_hostile_impact(at: Vector3, radius: float) -> void:
	_show_pulse(at, radius, Color("ff8a53"))
	show_burst(at + Vector3(0, .2, 0), "hurt")

func show_explosion(at: Vector3, radius: float) -> void:
	_show_pulse(at, radius, Color("b56cff"))

func show_shock(at: Vector3, radius: float) -> void:
	_show_pulse(at, radius, Color("55dcff"))

## A ring that runs from `at` out to `radius` at `speed` metres per second (the Quake's shockwave). Pooled with the other
## pulses, so it is silently dropped when all `MAX_PULSES` are busy.
func show_wave(at: Vector3, radius: float, speed: float, color: Color = QUAKE_TINT) -> void:
	_show_pulse(at, radius, color, radius / maxf(speed, .1))

func _show_pulse(at: Vector3, radius: float, color: Color, duration: float = PULSE_LIFETIME) -> void:
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
		durations.append(PULSE_LIFETIME)
	ages[index] = 0.0
	durations[index] = maxf(duration, .05)
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
	bolts.update(delta)
	for index in range(pulses.size()):
		if ages[index] < 0:
			continue
		ages[index] += delta
		if ages[index] >= durations[index]:
			ages[index] = -1.0
			pulses[index].visible = false
		else:
			var progress := ages[index] / durations[index]
			(pulses[index].material_override as ShaderMaterial).set_shader_parameter("age", progress)
	status.update()

func reset(preserve_damage: bool = false) -> void:
	status.reset()
	bolts.reset()
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
		(ribbon.material_override as ShaderMaterial).set_shader_parameter("motion_speed", GameConstants.REDUCED_MOTION_SPEED if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION) else 1.0)
		ribbon.position = (origin + end) * .5
		ribbon.rotation.y = atan2(-flat.x, -flat.z)
		ribbon.scale = Vector3(clampf(reach * .35, .4, 1.8), 1.0, flat.length())
		ribbon.visible = true
		flame_ages[index] = .24
