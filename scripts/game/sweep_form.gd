class_name SweepForm
extends TurretForm

## Melee: a spinning bat (or held blades) sweeps a sector each tick and hits each enemy once per rehit delay. Every form of
## the line shares this; the Stormblade (`GunbladeForm`) adds a rotating barrel on top.
static var melee_materials: Dictionary = {}
var spin_angle: float = 0.0
var swing_distance: float = 0.0
var swing_targets: Dictionary = {}
var rehit_lockouts: Dictionary = {}
## Blade angles around the pivot: one for most forms, several for the Orbit Saber.
var saber_angles: Array[float] = [0.0]
var blade_tip: Node3D
var bat_authored_reach: float = 1.0
var aim_authored_scale := Vector3.ONE

func rebuilt() -> void:
	blade_tip = actor.model.find_child("BladeTip", true, false) as Node3D
	aim_authored_scale = actor.aim.scale
	var tip := blade_tip if blade_tip else actor.muzzle
	bat_authored_reach = maxf(.001, WorldGeometry.planar(tip.global_position - actor.aim.global_position).length())
	_build_saber_arms()

## Placeholder procedural model: a base post with a pivoting arm; `Aim` is the spin pivot, `Muzzle` the bat tip.
static func placeholder_model() -> Node3D:
	if melee_materials.is_empty():
		melee_materials["base"] = WorldGeometry.material(Color("6b6f78"))
		melee_materials["bat"] = WorldGeometry.material(Color("c9ced6"))
		melee_materials["head"] = WorldGeometry.material(Color("ff8d3a"), true)
	var reach := TurretStats.new(TurretRegistry.get_base_stats("melee")).range_metres
	var root := Node3D.new()
	WorldGeometry.box(root, Vector3(.55, .28, .55), Vector3(0, .14, 0), melee_materials["base"])
	WorldGeometry.box(root, Vector3(.14, .38, .14), Vector3(0, .47, 0), melee_materials["base"])
	var pivot := Node3D.new()
	pivot.name = "Aim"
	pivot.position = Vector3(0, .55, 0)
	root.add_child(pivot)
	WorldGeometry.box(pivot, Vector3(.09, .09, reach), Vector3(0, 0, -reach / 2.0), melee_materials["bat"])
	WorldGeometry.box(pivot, Vector3(.2, .2, .3), Vector3(0, 0, -reach + .12), melee_materials["head"])
	var tip := Node3D.new()
	tip.name = "Muzzle"
	tip.position = Vector3(0, 0, -reach)
	pivot.add_child(tip)
	return root

## Sweeps the bat through the arc covered this tick and hits each enemy once per rehit delay.
func spin(delta: float, stats: TurretStats, reach: float) -> void:
	# Keep the visible bat tip on the gameplay sweep radius after range upgrades.
	var reach_scale := reach / bat_authored_reach
	actor.aim.scale = aim_authored_scale * Vector3(reach_scale, 1.0, reach_scale)
	var sweep := deg_to_rad(stats.rotation_rate) * delta
	swing_distance += sweep
	if swing_distance >= TAU:
		swing_distance = fmod(swing_distance, TAU)
		swing_targets = {}
	var previous := spin_angle
	spin_angle = wrapf(spin_angle + sweep, -PI, PI)
	actor.aim.rotation.y = spin_angle
	for key in rehit_lockouts.keys():
		rehit_lockouts[key] = float(rehit_lockouts[key]) - delta
		if float(rehit_lockouts[key]) <= 0.0:
			rehit_lockouts.erase(key)
	for enemy in actor.world.crowd.query_radius(actor.position, reach, true):
		if rehit_lockouts.has(enemy.get_instance_id()):
			continue
		var offset := WorldGeometry.planar(enemy.position - actor.position)
		var touched := false
		for angle in saber_angles:
			if sweep_overlaps_body(offset, reach, previous + angle, sweep, enemy.hurtbox_radius()):
				touched = true
				break
		if not touched:
			continue
		var damage := stats.damage
		var critical := TurretStatsService.roll_turret_crit()
		if critical:
			damage = TurretStatsService.calculate_turret_crit_damage(damage)
		var push := offset.normalized() * stats.knockback_metres
		rehit_lockouts[enemy.get_instance_id()] = stats.rehit_delay
		var bat_hit := CombatHit3D.new(damage, actor.position, push, GameEnums.DamageType.PHYSICAL)
		bat_hit.attack_targets = swing_targets
		bat_hit.critical = critical
		bat_hit.attack_families = TurretRegistry.get_attack_families(actor.turret_type)
		bat_hit.source_id = actor.turret_id
		bat_hit.slow_intensity = stats.slow_intensity
		bat_hit.slow_duration = stats.slow_duration
		actor.world.combat.apply_hit(enemy, bat_hit)

## Distance to the swept bat sector, including rounded contact at either end of the arc.
static func sweep_overlaps_body(offset: Vector3, reach: float, start: float, sweep: float, radius: float) -> bool:
	var point := WorldGeometry.planar(offset)
	var bearing := atan2(-point.x, -point.z)
	if sweep >= TAU or wrapf(bearing - start, 0.0, TAU) <= sweep:
		return point.length() <= reach + radius
	for angle: float in [start, start + sweep]:
		var direction := Vector3(-sin(angle), 0, -cos(angle))
		var closest := direction * clampf(point.dot(direction), 0.0, reach)
		if point.distance_squared_to(closest) <= radius * radius + .000001:
			return true
	return false

## Additional held blades reuse the authored arm, hand, hilt and prism geometry.
func _build_saber_arms() -> void:
	saber_angles.assign([0.0])
	var count := TurretEvolution.blade_count(form_id)
	if count <= 1:
		return
	var parts: Array[Node3D] = []
	for part_name: String in ["Ceramic_Arm", "Ceramic_Hand", "Sword_Grip", "Sword_Guard", "Prism_Blade"]:
		var part := actor.model.find_child(part_name, true, false) as Node3D
		if part:
			parts.append(part)
	for index in range(1, count):
		var angle := TAU * float(index) / float(count)
		saber_angles.append(angle)
		var arm := Node3D.new()
		arm.name = "SaberArm%d" % index
		actor.aim.add_child(arm)
		arm.rotation.y = angle
		for part in parts:
			arm.add_child(part.duplicate())
