class_name TurretActor
extends Node3D

var world: ArenaWorld
var turret_type: String = "normal"
## Unique within a run (assigned by `ArenaWorld.add_turret`); stamped on shots for kill attribution.
var turret_id: int = 0
var carried: bool = false:
	set(value):
		carried = value
		if value:
			reset_entrench()
var cooldown: float = 0.0
var aim: Node3D
var muzzle: Node3D
var aim_rest: Vector3
var target: CombatActor
var target_clock: float = 0.0
var spin_angle: float = 0.0
var rehit_lockouts: Dictionary = {}
## Modifier math is costly and static between purchases, so stats are rebuilt on change or every STATS_REFRESH seconds.
var cached_stats: Dictionary = {}
var stats_age: float = 0.0
## Seconds spent deployed in combat at the current spot; drives Entrench stacks.
var stay_time: float = 0.0
var entrench_stacks_cached: int = 0
var entrench_ring: MeshInstance3D
## Shop items retune Entrench through modifier stats; resolved lazily and dropped whenever modifiers change.
var entrench_config: Dictionary = {}

const STATS_REFRESH: float = .25
const MELEE_HIT_PADDING: float = .3
const MELEE_REHIT_DELAY: float = .5
const TESLA_TINT := Color(.35, .9, 1.0)
static var melee_materials: Dictionary = {}

func _ready() -> void:
	Events.modifiers_changed.connect(invalidate_stats)
	var model: Node3D
	if turret_type == "plasma":
		model = preload("res://assets/models/game/plasma_turret.glb").instantiate()
	elif turret_type == "shock":
		model = preload("res://assets/models/game/shock_turret.glb").instantiate()
	elif turret_type == "melee":
		model = _build_melee_model()
	elif turret_type == "tesla":
		model = preload("res://assets/models/game/ion_turret.glb").instantiate()
		EnemyVariants.tint_model(model, "turret_tesla", TESLA_TINT, .5)
	else:
		model = preload("res://assets/models/game/ion_turret.glb").instantiate()
	add_child(model)
	aim = model.find_child("Aim", true, false) as Node3D
	muzzle = model.find_child("Muzzle", true, false) as Node3D
	aim_rest = aim.position

## Placeholder procedural model: a base post with a pivoting arm; `Aim` is the spin pivot, `Muzzle` the bat tip.
func _build_melee_model() -> Node3D:
	if melee_materials.is_empty():
		melee_materials["base"] = WorldGeometry.material(Color("6b6f78"))
		melee_materials["bat"] = WorldGeometry.material(Color("c9ced6"))
		melee_materials["head"] = WorldGeometry.material(Color("ff8d3a"), true)
	var reach := float(TurretRegistry.TYPES["melee"]["base_stats"]["range"]) * WorldGeometry.METRES_PER_PIXEL
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
func _spin_bat(delta: float, stats: Dictionary, reach: float) -> void:
	var sweep := deg_to_rad(float(stats.get("rotation_rate", 360.0))) * delta
	var previous := spin_angle
	spin_angle = wrapf(spin_angle + sweep, -PI, PI)
	aim.rotation.y = spin_angle
	for key in rehit_lockouts.keys():
		rehit_lockouts[key] = float(rehit_lockouts[key]) - delta
		if float(rehit_lockouts[key]) <= 0.0:
			rehit_lockouts.erase(key)
	for enemy in world.crowd.query_radius(position, reach + MELEE_HIT_PADDING):
		if rehit_lockouts.has(enemy.get_instance_id()):
			continue
		var offset := WorldGeometry.planar(enemy.position - position)
		var distance := maxf(offset.length(), MELEE_HIT_PADDING)
		# The bat tip points along (-sin a, 0, -cos a); widen the arc by the enemy's angular radius.
		var padding := asin(clampf(MELEE_HIT_PADDING / distance, 0.0, 1.0))
		var bearing := atan2(-offset.x, -offset.z)
		if wrapf(bearing - previous + padding, 0.0, TAU) > sweep + 2.0 * padding:
			continue
		var damage := float(stats["damage"])
		if TurretStatsService.roll_turret_crit():
			damage = TurretStatsService.calculate_turret_crit_damage(damage)
		var push := offset.normalized() * float(stats.get("knockback_force", 0.0)) * WorldGeometry.METRES_PER_PIXEL
		rehit_lockouts[enemy.get_instance_id()] = maxf(.05, float(stats.get("rehit_delay", MELEE_REHIT_DELAY)))
		var bat_hit := CombatHit3D.new(damage, position, push, GameEnums.DamageType.PHYSICAL)
		bat_hit.source_id = turret_id
		bat_hit.slow_intensity = clampf(float(stats.get("slow_intensity", 0.0)), 0.0, .9)
		bat_hit.slow_duration = maxf(float(stats.get("slow_duration", 0.0)), 0.0)
		world.combat.apply_hit(enemy, bat_hit)

## Terrain under this turret, refreshed with the cached stats: high ground range and power node Entrench speed.
var zone_range_bonus: float = 0.0
var zone_entrench_bonus: float = 0.0

var zone_badge: MeshInstance3D
var zone_badge_type: String = ""

func _refresh_zone_bonuses() -> void:
	if world.terrain:
		zone_range_bonus = world.terrain.range_bonus_at(position)
		zone_entrench_bonus = world.terrain.entrench_bonus_at(position)
	else:
		zone_range_bonus = 0.0
		zone_entrench_bonus = 0.0
	_update_zone_badge()

## A ring in the zone's colour under a turret that is benefiting from high ground or a power node, so the bonus is
## visible on the turret itself. Only while zones are readable.
func _update_zone_badge() -> void:
	var wanted := ""
	if world.terrain and world.terrain.readable and not carried:
		if zone_range_bonus > 0.0:
			wanted = TerrainZone.HIGH_GROUND
		elif zone_entrench_bonus > 0.0:
			wanted = TerrainZone.POWER_NODE
	if wanted == zone_badge_type:
		return
	zone_badge_type = wanted
	if zone_badge:
		zone_badge.queue_free()
		zone_badge = null
	if wanted != "":
		zone_badge = WorldGeometry.ring(self, .9, TerrainZone.TYPES[wanted]["color"])
		zone_badge.position.y = .025

func _stack_seconds() -> float:
	return float(_entrench()["seconds"]) / (1.0 + zone_entrench_bonus)

func invalidate_stats() -> void:
	cached_stats = {}
	entrench_config = {}

func _entrench() -> Dictionary:
	if entrench_config.is_empty():
		entrench_config = {
			"seconds": maxf(.5, ModifierService.apply_modifiers_to_stat(GameConstants.ENTRENCH_STACK_SECONDS, "entrench_stack_seconds")),
			"max": maxi(0, roundi(ModifierService.apply_modifiers_to_stat(float(GameConstants.ENTRENCH_MAX_STACKS), "entrench_max_stacks"))),
			"bonus": maxf(0.0, ModifierService.apply_modifiers_to_stat(1.0, "entrench_bonus")),
		}
	return entrench_config

func entrench_max() -> int:
	return int(_entrench()["max"])

## Fractional damage / fire rate granted by the current stacks (before shop modifiers, which apply to the base stat).
func entrench_damage_bonus() -> float:
	return GameConstants.ENTRENCH_DAMAGE_PER_STACK * float(entrench_stacks_cached) * float(_entrench()["bonus"])

func entrench_fire_rate_bonus() -> float:
	return GameConstants.ENTRENCH_FIRE_RATE_PER_STACK * float(entrench_stacks_cached) * float(_entrench()["bonus"])

func entrench_stacks() -> int:
	if not FeatureFlagService.is_enabled(FeatureFlagService.ENTRENCH):
		return 0
	return mini(int(stay_time / _stack_seconds()), entrench_max())

func reset_entrench() -> void:
	stay_time = 0.0
	_refresh_zone_bonuses()
	entrench_stacks_cached = 0
	cached_stats = {}
	_update_entrench_ring()

## Fraction (0..1) toward the next stack; 1 when maxed.
func entrench_progress() -> float:
	if entrench_stacks_cached >= entrench_max():
		return 1.0
	var seconds := _stack_seconds()
	return fmod(stay_time, seconds) / seconds

func _tick_entrench(delta: float) -> void:
	if FeatureFlagService.is_enabled(FeatureFlagService.ENTRENCH):
		stay_time += delta
	elif stay_time > 0.0:
		stay_time = 0.0
	var stacks := entrench_stacks()
	if stacks != entrench_stacks_cached:
		entrench_stacks_cached = stacks
		cached_stats = {}
	_update_entrench_ring()

func _update_entrench_ring() -> void:
	if not entrench_ring:
		entrench_ring = WorldGeometry.ring(self, .62, Color("ffd05a"))
		entrench_ring.position.y = .03
	entrench_ring.visible = entrench_stacks_cached > 0 and not carried
	var fill := float(entrench_stacks_cached) / float(maxi(entrench_max(), 1))
	var size := .8 + .25 * fill + .1 * entrench_progress()
	entrench_ring.scale = Vector3(size, 1.0, size)

## Situational item bonuses, resolved with the cached stats: Last Stand (low hull) and Storm Conductor (linked electric turrets).
func _apply_item_conditions(stats: Dictionary) -> void:
	var last_stand := ModifierService.apply_modifiers_to_stat(0.0, "last_stand_fire_rate")
	if last_stand > 0.0 and is_instance_valid(world.player) and world.player.health < world.player.max_health * GameConstants.LAST_STAND_HULL_FRACTION:
		stats["fire_rate"] = float(stats.get("fire_rate", 1.0)) * (1.0 + last_stand)
	var link := ModifierService.apply_modifiers_to_stat(0.0, "storm_link_damage")
	if link > 0.0 and TurretRegistry.get_family(turret_type) == "electric" and _has_electric_neighbour():
		stats["damage"] = float(stats.get("damage", 0.0)) * (1.0 + link)

func _has_electric_neighbour() -> bool:
	for other in world.turrets:
		if other != self and not other.carried and TurretRegistry.get_family(other.turret_type) == "electric":
			if WorldGeometry.planar(other.position - position).length() <= GameConstants.STORM_LINK_RANGE:
				return true
	return false

func _current_stats(delta: float) -> Dictionary:
	stats_age += delta
	if cached_stats.is_empty() or stats_age >= STATS_REFRESH:
		cached_stats = TurretStatsService.get_turret_stats(turret_type, float(world.difficulty_config["turret_damage_mult"]))
		cached_stats = cached_stats.duplicate()
		_apply_item_conditions(cached_stats)
		_refresh_zone_bonuses()
		if zone_range_bonus > 0.0:
			cached_stats["range"] = float(cached_stats.get("range", 240.0)) * (1.0 + zone_range_bonus)
		if entrench_stacks_cached > 0:
			cached_stats["damage"] = float(cached_stats.get("damage", 0.0)) * (1.0 + entrench_damage_bonus())
			cached_stats["fire_rate"] = float(cached_stats.get("fire_rate", 1.0)) * (1.0 + entrench_fire_rate_bonus())
		stats_age = 0.0
	return cached_stats

var range_ring: MeshInstance3D
var range_ring_metres: float = 0.0
static var range_ring_material: StandardMaterial3D

## Ring on the floor at the turret's current range (item, Entrench-free stats and high ground included) while the
## world's range toggle is on; also while carried, so a placement can be judged.
func _update_range_ring() -> void:
	if not world.show_ranges or not FeatureFlagService.is_enabled(FeatureFlagService.RANGE_OVERLAY):
		if range_ring:
			range_ring.visible = false
		return
	var metres := float(_current_stats(0.0).get("range", 0.0)) * WorldGeometry.METRES_PER_PIXEL
	if metres <= 0.0:
		return
	if not range_ring:
		range_ring = MeshInstance3D.new()
		range_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not range_ring_material:
			range_ring_material = StandardMaterial3D.new()
			range_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			range_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			range_ring_material.albedo_color = Color(.4, .95, .9, .55)
		range_ring.material_override = range_ring_material
		add_child(range_ring)
	if not is_equal_approx(metres, range_ring_metres):
		range_ring_metres = metres
		var mesh := TorusMesh.new()
		mesh.inner_radius = maxf(.01, metres - .035)
		mesh.outer_radius = metres + .035
		mesh.rings = 72
		mesh.ring_segments = 4
		range_ring.mesh = mesh
	range_ring.global_position = Vector3(global_position.x, .04, global_position.z)
	range_ring.visible = true

func _physics_process(delta: float) -> void:
	if not world.is_combat():
		return
	_update_range_ring()
	if carried:
		position = world.player.position + Vector3(0, 1.15, .25)
		return
	_tick_entrench(delta)
	cooldown = maxf(0.0, cooldown - delta)
	aim.position = aim.position.lerp(aim_rest, minf(delta * 16.0, 1.0))
	var stats: Dictionary = _current_stats(delta)
	var range_metres := float(stats.get("range", 240.0)) * WorldGeometry.METRES_PER_PIXEL
	if turret_type == "melee":
		_spin_bat(delta, stats, range_metres)
		return
	if turret_type == "shock":
		if cooldown <= 0.0 and world.nearest_enemy(position, range_metres):
			var pulse := CombatShot3D.from_stats(stats, GameEnums.DamageType.ELECTRIC)
			pulse.splash_radius = range_metres
			pulse.source_id = turret_id
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
	if cooldown <= 0.0 and turret_type == "tesla":
		var bolt := CombatShot3D.from_stats(stats, GameEnums.DamageType.ELECTRIC)
		bolt.source_id = turret_id
		if TurretStatsService.roll_turret_crit():
			bolt.damage = TurretStatsService.calculate_turret_crit_damage(bolt.damage)
		world.combat.chain(muzzle.global_position, target, bolt, int(stats.get("chain_count", 0)),
			float(stats.get("chain_range", 0.0)) * WorldGeometry.METRES_PER_PIXEL, float(stats.get("chain_decay", 1.0)), world.enemies)
		cooldown = 1.0 / maxf(float(stats.get("fire_rate", 1.2)), .01)
	elif cooldown <= 0.0:
		var type := GameEnums.DamageType.PLASMA if turret_type == "plasma" else GameEnums.DamageType.PHYSICAL
		var shot := CombatShot3D.from_stats(stats, type)
		shot.source_id = turret_id
		if TurretStatsService.roll_turret_crit():
			shot.damage = TurretStatsService.calculate_turret_crit_damage(shot.damage)
		world.fire_shot(muzzle.global_position, target, shot)
		cooldown = 1.0 / maxf(float(stats.get("fire_rate", 1.2)), .01)
		if not FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION):
			aim.position += heading.normalized() * -.045
