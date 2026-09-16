class_name TurretActor
extends Node3D

var world: Node
var turret_type: String = "normal"
var carried: bool = false
var cooldown: float = 0.0
var aim: Node3D
var muzzle: Node3D
var aim_rest: Vector3
var target: CombatActor
var target_clock: float = 0.0

func _ready() -> void:
	var model: Node3D
	if turret_type == "plasma":
		model = preload("res://assets/models/game/plasma_turret.glb").instantiate()
	elif turret_type == "shock":
		model = preload("res://assets/models/game/shock_turret.glb").instantiate()
	else:
		model = preload("res://assets/models/game/ion_turret.glb").instantiate()
	add_child(model)
	aim = model.find_child("Aim", true, false) as Node3D
	muzzle = model.find_child("Muzzle", true, false) as Node3D
	aim_rest = aim.position

func _physics_process(delta: float) -> void:
	if not world.is_combat():
		return
	if carried:
		position = world.player.position + Vector3(0, 1.15, .25)
		return
	cooldown = maxf(0.0, cooldown - delta)
	aim.position = aim.position.lerp(aim_rest, minf(delta * 16.0, 1.0))
	var stats: Dictionary = TurretStatsService.get_turret_stats(turret_type, float(world.difficulty_config["turret_damage_mult"]))
	var range_metres := float(stats.get("range", 240.0)) * WorldGeometry.METRES_PER_PIXEL
	if turret_type == "shock":
		if cooldown <= 0.0 and world.nearest_enemy(position, range_metres):
			var pulse := CombatShot3D.from_stats(stats, GameEnums.DamageType.ELECTRIC)
			pulse.splash_radius = range_metres
			if TurretStatsService.roll_turret_crit():
				pulse.damage = TurretStatsService.calculate_turret_crit_damage(pulse.damage)
			world.combat.impact(null, position, Vector3.ZERO, pulse, world.enemies)
			cooldown = 1.0 / maxf(float(stats["fire_rate"]), .01)
		return
	target_clock -= delta
	# Cluster scans run five times per second, not for every turret every frame.
	if target_clock <= 0.0:
		var radius := float(stats.get("aoe_radius", 0.0)) * WorldGeometry.METRES_PER_PIXEL if turret_type == "plasma" else 0.0
		target = world.combat.select_target(position, range_metres, world.enemies, radius, world.crowd)
		target_clock = .2
	if not is_instance_valid(target) or target.dead or WorldGeometry.planar(target.position - position).length() > range_metres:
		return
	var heading := WorldGeometry.planar(target.position - position)
	aim.rotation.y = atan2(-heading.x, -heading.z)
	if cooldown <= 0.0:
		var type := GameEnums.DamageType.PLASMA if turret_type == "plasma" else GameEnums.DamageType.PHYSICAL
		var shot := CombatShot3D.from_stats(stats, type)
		if TurretStatsService.roll_turret_crit():
			shot.damage = TurretStatsService.calculate_turret_crit_damage(shot.damage)
		world.fire_shot(muzzle.global_position, target, shot)
		cooldown = 1.0 / maxf(float(stats.get("fire_rate", 1.2)), .01)
		if not FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION):
			aim.position += heading.normalized() * -.045
