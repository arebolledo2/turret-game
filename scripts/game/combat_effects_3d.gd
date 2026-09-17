class_name CombatEffects3D
extends Node3D

## Bounded, reusable cosmetic effects. Lifetime advances only with simulation.
const MAX_PULSES: int = 32
const MAX_SPARKS: int = 24
var sparks: Array[MeshInstance3D] = []
var spark_lifetimes: Array[float] = []
var spark_mesh: SphereMesh
var hit_material := WorldGeometry.material(Color("ffd78a"), true)
var hull_material := WorldGeometry.material(Color("ff675a"), true)
var pulses: Array[MeshInstance3D] = []
var ages: Array[float] = []
var radii: Array[float] = []
var world: Node
var plasma_material := WorldGeometry.material(Color("b56cff"), true)
var shock_material := WorldGeometry.material(Color("55dcff"), true)

func show_hit(actor: Node3D, _hit: CombatHit3D, _amount: float) -> void:
	var enemy := (actor as CombatActor).is_enemy
	_show_spark(actor.position + Vector3(0, .45, 0), hit_material if enemy else hull_material,
		.13 if enemy else .36, .12 if enemy else .25)

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

func show_explosion(at: Vector3, radius: float) -> void:
	_show_pulse(at, radius, plasma_material)

func show_shock(at: Vector3, radius: float) -> void:
	_show_pulse(at, radius, shock_material)

func _show_pulse(at: Vector3, radius: float, material: Material) -> void:
	var index := ages.find(-1.0)
	if index < 0:
		if pulses.size() >= MAX_PULSES:
			return
		index = pulses.size()
		pulses.append(WorldGeometry.ring(self, 1.0, Color("b56cff")))
		ages.append(-1.0)
		radii.append(0.0)
	ages[index] = 0.0
	pulses[index].material_override = material
	radii[index] = radius
	pulses[index].position = WorldGeometry.planar(at) + Vector3(0, .045, 0)
	pulses[index].scale = Vector3(.12, .12, .12)
	pulses[index].visible = true
	if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION):
		pulses[index].scale = Vector3(radius, .1, radius)

func _physics_process(delta: float) -> void:
	if not world.is_combat():
		return
	for index in range(sparks.size()):
		spark_lifetimes[index] = maxf(0.0, spark_lifetimes[index] - delta)
		sparks[index].visible = spark_lifetimes[index] > 0.0
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
			pulses[index].scale = Vector3(radius, .1, radius)

func reset() -> void:
	for index in range(sparks.size()):
		spark_lifetimes[index] = 0.0
		sparks[index].visible = false
	for index in range(pulses.size()):
		ages[index] = -1.0
		pulses[index].visible = false
