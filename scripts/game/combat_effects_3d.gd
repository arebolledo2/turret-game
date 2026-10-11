class_name CombatEffects3D
extends Node3D

## Bounded, reusable cosmetic effects. Lifetime advances only with simulation.
const MAX_PULSES: int = 32
const MAX_SPARKS: int = 24
const MAX_ARCS: int = 16
const ARC_LIFETIME: float = .12
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
var arc_mesh: BoxMesh
var sparks: Array[MeshInstance3D] = []
var spark_lifetimes: Array[float] = []
var spark_mesh: SphereMesh
var hit_material := WorldGeometry.material(Color("ffd78a"), true)
var hull_material := WorldGeometry.material(Color("ff675a"), true)
var pulses: Array[MeshInstance3D] = []
var ages: Array[float] = []
var radii: Array[float] = []
var flame_material := WorldGeometry.material(Color(2.5, .65, .08), true)
var world: ArenaWorld
var plasma_material := WorldGeometry.material(Color("b56cff"), true)
var shock_material := WorldGeometry.material(Color("55dcff"), true)

func show_hit(actor: Node3D, hit: CombatHit3D, _amount: float) -> void:
	var enemy := (actor as CombatActor).is_enemy
	show_burst(actor.position + Vector3(0, .5, 0), _burst_kind(hit.damage_type) if enemy else "hurt")
	_show_spark(actor.position + Vector3(0, .45, 0), hit_material if enemy else hull_material,
		.13 if enemy else .36, .12 if enemy else .25)

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

func show_arc(from: Vector3, to: Vector3) -> void:
	var index := arc_lifetimes.find(0.0)
	if index < 0:
		if arcs.size() >= MAX_ARCS:
			return
		if not arc_mesh:
			arc_mesh = BoxMesh.new()
			arc_mesh.size = Vector3(.07, .07, 1.0)
		var arc := MeshInstance3D.new()
		arc.mesh = arc_mesh
		arc.material_override = shock_material
		arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(arc)
		arcs.append(arc)
		arc_lifetimes.append(0.0)
		index = arcs.size() - 1
	var length := from.distance_to(to)
	if length < .01:
		return
	var arc := arcs[index]
	arc.position = (from + to) * .5
	arc.scale = Vector3(1, 1, length)
	arc.basis = Basis.looking_at(to - from, Vector3.UP if absf((to - from).normalized().y) < .99 else Vector3.RIGHT).scaled(Vector3(1, 1, length))
	arc.visible = true
	arc_lifetimes[index] = ARC_LIFETIME

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
		pulses.append(GroundDial.create(self, 1.0, color))
		ages.append(-1.0)
		radii.append(0.0)
	ages[index] = 0.0
	GroundDial.recolor(pulses[index], color)
	radii[index] = radius
	pulses[index].position = WorldGeometry.planar(at) + Vector3(0, .045, 0)
	GroundDial.resize(pulses[index], .12)
	pulses[index].visible = true
	if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION):
		GroundDial.resize(pulses[index], radius)

func _physics_process(delta: float) -> void:
	if not world.is_combat():
		return
	for index in range(sparks.size()):
		spark_lifetimes[index] = maxf(0.0, spark_lifetimes[index] - delta)
		sparks[index].visible = spark_lifetimes[index] > 0.0
	for index in range(arcs.size()):
		arc_lifetimes[index] = maxf(0.0, arc_lifetimes[index] - delta)
		arcs[index].visible = arc_lifetimes[index] > 0.0
	for index in range(pulses.size()):
		if ages[index] < 0:
			continue
		ages[index] += delta
		if ages[index] >= .3:
			ages[index] = -1.0
			pulses[index].visible = false
		else:
			var radius := lerpf(.12, radii[index], ages[index] / .3)
			if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION):
				radius = radii[index]
			GroundDial.resize(pulses[index], radius)

func reset() -> void:
	for burst in bursts:
		burst.emitting = false
	for index in range(sparks.size()):
		spark_lifetimes[index] = 0.0
		sparks[index].visible = false
	for index in range(arcs.size()):
		arc_lifetimes[index] = 0.0
		arcs[index].visible = false
	for index in range(pulses.size()):
		ages[index] = -1.0
		pulses[index].visible = false

## Short expanding flame lobes show the exact forward cone, with bounded pooled sparks.
func show_flame(origin: Vector3, heading: Vector3, reach: float, half_angle: float) -> void:
	for step in range(1, 5):
		var distance := reach * float(step) / 4.0
		var at := origin + heading * distance
		at.y = lerpf(origin.y, .45, float(step) / 4.0)
		_show_spark(at, flame_material, maxf(.08, tan(half_angle) * distance), .23)
