class_name TurretActor
extends Node3D

var world: ArenaWorld
var turret_type: String = "normal"
var progression := TurretProgression.new()
## Unique within a run (assigned by `ArenaWorld.add_turret`); stamped on shots for kill attribution.
var turret_id: int = 0
var carried: bool = false:
	set(value):
		carried = value
		cached_stats = {}
		target_clock = 0.0
		if value:
			reset_entrench()
var gun_muzzles: Array[Node3D] = []
var gun_burst_left := 0
var gun_burst_clock := 0.0
var gun_burst_shot: CombatShot3D
var bow_burst_left := 0
var bow_burst_clock := 0.0
var bow_burst_heading := Vector3.FORWARD
var bow_burst_target := Vector3.ZERO
var bow_burst_shot: CombatShot3D
var flame_emitters: Array[Node3D] = []
var bowling_hardware: BowlingEvolutionVisual
var loaded_ball: Node3D
var loaded_arrow: Node3D
var bow_muzzles: Array[Node3D] = []
var bow_loaded_arrows: Array[Node3D] = []
var cooldown: float = 0.0
var aim: Node3D
var model: Node3D
var saber_angles: Array[float] = [0.0]
var blade_tip: Node3D
var gun_stats := TurretStats.new()
var muzzle: Node3D
var rotor: Node3D
var recoil_barrel: Node3D
var barrel_rest := Vector3.ZERO
var muzzle_rest := Vector3.ZERO
var spool: float = 0.0
var aim_rest: Vector3
var target: CombatActor
var target_clock: float = 0.0
var spin_angle: float = 0.0
var bat_authored_reach: float = 1.0
var aim_authored_scale := Vector3.ONE
var rehit_lockouts: Dictionary = {}
## Modifier math is costly and static between purchases, so stats are rebuilt on change or every STATS_REFRESH seconds.
var cached_stats: Dictionary = {}
var stats_age: float = 0.0
## Typed reads of `cached_stats`; rebuilt together with it.
var stats_view := TurretStats.new()
## Seconds spent deployed in combat at the current spot; drives Entrench stacks.
var stay_time: float = 0.0
var entrench_stacks_cached: int = 0
var entrench_ring: MeshInstance3D
var entrench_notice: float = 0.0
## Shop items retune Entrench through modifier stats; resolved lazily and dropped whenever modifiers change.
var entrench_config: Dictionary = {}

const STATS_REFRESH: float = .25
const TESLA_TINT := Color(.35, .9, 1.0)
static var melee_materials: Dictionary = {}

func _ready() -> void:
	Events.modifiers_changed.connect(invalidate_stats)
	_rebuild_model()

func _rebuild_model() -> void:
	if is_instance_valid(model):
		remove_child(model)
		model.queue_free()
	var fire_mode := TurretRegistry.get_fire_mode(turret_type)
	var asset_key := TurretEvolution.model_key(turret_type, progression.evolution_branch, progression.evolution_stage)
	var use_clockwork := ClockworkModels.available(asset_key)
	if use_clockwork:
		model = ClockworkModels.instantiate(asset_key)
	else:
		model = _build_melee_model() if fire_mode == TurretRegistry.FIRE_SWEEP else load(TurretRegistry.get_model_path(turret_type)).instantiate()
	if turret_type == "tesla" and not use_clockwork:
		EnemyVariants.tint_model(model, "turret_tesla", TESLA_TINT, .5)
	add_child(model)
	BowEvolutionVisual.build(model, progression.evolution_branch, progression.evolution_stage)
	flame_emitters = FlameEvolutionVisual.build(model, progression.evolution_branch, progression.evolution_stage)
	bowling_hardware = BowlingEvolutionVisual.build(model, progression.evolution_branch, progression.evolution_stage)
	gun_muzzles = GunbladeEvolutionVisual.build(model, progression.evolution_branch, progression.evolution_stage)
	aim = model.find_child("Aim", true, false) as Node3D
	blade_tip = model.find_child("BladeTip", true, false) as Node3D
	muzzle = model.find_child("Muzzle", true, false) as Node3D
	rotor = model.find_child("Rotor", true, false) as Node3D
	recoil_barrel = model.find_child("Barrel", true, false) as Node3D
	if recoil_barrel:
		barrel_rest = recoil_barrel.position
	muzzle_rest = muzzle.position
	spool = 0.0
	bow_burst_left = 0
	gun_burst_left = 0
	loaded_ball = model.find_child("LoadedBall", true, false) as Node3D
	loaded_arrow = model.find_child("LoadedArrow", true, false) as Node3D
	bow_muzzles.clear()
	bow_loaded_arrows.clear()
	if turret_type == "bow":
		bow_muzzles.append(muzzle)
		bow_loaded_arrows.append(loaded_arrow)
		for i in range(1, 5):
			var extra_muzzle := model.find_child("Muzzle%d" % i, true, false) as Node3D
			if extra_muzzle:
				bow_muzzles.append(extra_muzzle)
				bow_loaded_arrows.append(model.find_child("LoadedArrow%d" % i, true, false) as Node3D)

	aim_rest = aim.position
	aim_authored_scale = aim.scale
	if fire_mode == TurretRegistry.FIRE_SWEEP:
		bat_authored_reach = maxf(.001, WorldGeometry.planar((blade_tip if blade_tip else muzzle).global_position - aim.global_position).length())
	_build_saber_arms()

## Placeholder procedural model: a base post with a pivoting arm; `Aim` is the spin pivot, `Muzzle` the bat tip.
func _build_melee_model() -> Node3D:
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
func _spin_bat(delta: float, stats: TurretStats, reach: float) -> void:
	# Keep the visible bat tip on the gameplay sweep radius after range upgrades.
	var reach_scale := reach / bat_authored_reach
	aim.scale = aim_authored_scale * Vector3(reach_scale, 1.0, reach_scale)
	var sweep := deg_to_rad(stats.rotation_rate) * delta
	var previous := spin_angle
	spin_angle = wrapf(spin_angle + sweep, -PI, PI)
	aim.rotation.y = spin_angle
	for key in rehit_lockouts.keys():
		rehit_lockouts[key] = float(rehit_lockouts[key]) - delta
		if float(rehit_lockouts[key]) <= 0.0:
			rehit_lockouts.erase(key)
	for enemy in world.crowd.query_radius(position, reach, true):
		if rehit_lockouts.has(enemy.get_instance_id()):
			continue
		var offset := WorldGeometry.planar(enemy.position - position)
		var touched := false
		for angle in saber_angles:
			if sweep_overlaps_body(offset, reach, previous + angle, sweep, enemy.hurtbox_radius()):
				touched = true
				break
		if not touched:
			continue
		var damage := stats.damage
		if TurretStatsService.roll_turret_crit():
			damage = TurretStatsService.calculate_turret_crit_damage(damage)
		var push := offset.normalized() * stats.knockback_metres
		rehit_lockouts[enemy.get_instance_id()] = stats.rehit_delay
		var bat_hit := CombatHit3D.new(damage, position, push, GameEnums.DamageType.PHYSICAL)
		bat_hit.attack_families = TurretRegistry.get_attack_families(turret_type)
		bat_hit.source_id = turret_id
		bat_hit.slow_intensity = stats.slow_intensity
		bat_hit.slow_duration = stats.slow_duration
		world.combat.apply_hit(enemy, bat_hit)

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

## Terrain under this turret, refreshed with the cached stats: high ground range and power node Entrench speed.
var zone_range_bonus: float = 0.0
var zone_entrench_bonus: float = 0.0

var zone_badge: MeshInstance3D
var zone_badge_type: String = ""

func _refresh_zone_bonuses() -> void:
	if world.terrain and not carried:
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
	entrench_notice = maxf(0.0, entrench_notice - delta)
	if FeatureFlagService.is_enabled(FeatureFlagService.ENTRENCH):
		stay_time += delta
	elif stay_time > 0.0:
		stay_time = 0.0
	var stacks := entrench_stacks()
	if stacks != entrench_stacks_cached:
		if stacks > entrench_stacks_cached:
			entrench_notice = .65
		entrench_stacks_cached = stacks
		cached_stats = {}
	_update_entrench_ring()

func _update_entrench_ring() -> void:
	if not entrench_ring:
		entrench_ring = GroundDial.create(self, .72, Color("e9b969"), true)
		entrench_ring.position.y = .03
	var mode := SettingsService.ground_markers
	var inspecting := is_instance_valid(world) and is_instance_valid(world.player) and position.distance_to(world.player.position) < TurretPlacement.PICKUP_RANGE
	var contextual := inspecting or entrench_notice > 0.0
	entrench_ring.visible = entrench_stacks_cached > 0 and not carried and (mode == SettingsService.GroundMarkers.ALL or (mode == SettingsService.GroundMarkers.CONTEXTUAL and contextual))
	var fill := (float(entrench_stacks_cached) + (entrench_progress() if entrench_stacks_cached < entrench_max() else 0.0)) / float(maxi(entrench_max(), 1))
	GroundDial.update(entrench_ring, fill, false, entrench_max())

## Situational item bonuses, resolved with the cached stats: Last Stand (low hull) and Storm Conductor (linked electric turrets).
func _apply_item_conditions(stats: Dictionary) -> void:
	var last_stand := ModifierService.apply_modifiers_to_stat(0.0, "last_stand_fire_rate")
	if last_stand > 0.0 and is_instance_valid(world.player) and world.player.health < world.player.max_health * GameConstants.LAST_STAND_HULL_FRACTION:
		for key: String in ["fire_rate", "rotation_rate"]:
			if stats.has(key):
				stats[key] = float(stats[key]) * (1.0 + last_stand)
	var link := ModifierService.apply_modifiers_to_stat(0.0, "storm_link_damage")
	if link > 0.0 and "instant" in TurretRegistry.get_attack_families(turret_type) and _has_instant_neighbour():
		stats["damage"] = float(stats.get("damage", 0.0)) * (1.0 + link)

func _has_instant_neighbour() -> bool:
	for other in world.turrets:
		if other != self and not other.carried and "instant" in TurretRegistry.get_attack_families(other.turret_type):
			if WorldGeometry.planar(other.position - position).length() <= GameConstants.STORM_LINK_RANGE:
				return true
	return false

## Typed view of the current stats (refreshing them when stale).
func _current_view(delta: float) -> TurretStats:
	_current_stats(delta)
	return stats_view

func _current_stats(delta: float) -> Dictionary:
	stats_age += delta
	if cached_stats.is_empty() or stats_age >= STATS_REFRESH:
		_refresh_zone_bonuses()
		cached_stats = resolve_attack_stats()
		if progression.evolution_branch == "gunblade":
			gun_stats = TurretStats.new(resolve_attack_stats(true))
		stats_age = 0.0
		stats_view = TurretStats.new(cached_stats)
	return cached_stats

## Fresh, side-effect-free resolution also supports shop previews without polluting combat caches.
func resolve_attack_stats(secondary: bool = false, branch: String = "", stage: int = -1) -> Dictionary:
	if stage < 0:
		branch = progression.evolution_branch
		stage = progression.evolution_stage
	var base := TurretEvolution.base_stats(turret_type, branch, stage)
	if secondary:
		base = TurretRegistry.get_base_stats("normal")
		base.damage = [7.0, 8.0, 9.0][clampi(stage - 1, 0, 2)]
		base.fire_rate = [2.0, 2.2, 2.4][clampi(stage - 1, 0, 2)]
		base.range = 300.0
		base.pierce = 1 if stage >= 3 else 0
	var stats := ModifierService.get_turret_stats(turret_type, world.difficulty_config, base, "normal" if secondary else "")
	if world.session.state.turret_progression_enabled:
		progression.apply_stats(stats)
	_apply_item_conditions(stats)
	var terrain_range := world.terrain.range_bonus_at(position) if world.terrain and not carried else 0.0
	stats["range"] = float(stats.get("range", TurretStats.DEFAULT_RANGE)) * (1.0 + terrain_range)
	var bonus := maxf(0.0, ModifierService.apply_modifiers_to_stat(1.0, "entrench_bonus")) * float(entrench_stacks_cached)
	if bonus > 0.0:
		stats["damage"] *= 1.0 + GameConstants.ENTRENCH_DAMAGE_PER_STACK * bonus
		stats["fire_rate"] = float(stats.get("fire_rate", 1.0)) * (1.0 + GameConstants.ENTRENCH_FIRE_RATE_PER_STACK * bonus)
	return stats

var range_ring: MeshInstance3D
var range_ring_metres: float = 0.0

## Resolved attack range, shown by the global toggle or when approaching a deployed turret.
func _update_range_ring() -> void:
	var inspecting := not carried and is_instance_valid(world.player) and position.distance_to(world.player.position) < TurretPlacement.PICKUP_RANGE
	var contextual := inspecting and SettingsService.ground_markers != SettingsService.GroundMarkers.OFF
	if not (world.show_ranges or contextual) or not FeatureFlagService.is_enabled(FeatureFlagService.RANGE_OVERLAY):
		if range_ring:
			range_ring.visible = false
		return
	var view := _current_view(0.0)
	var metres := view.range_metres * (view.area_size if TurretRegistry.get_fire_mode(turret_type) in [TurretRegistry.FIRE_PULSE, TurretRegistry.FIRE_FLAME] else 1.0)
	if metres <= 0.0:
		return
	if not range_ring:
		range_ring = GroundDial.create(self, metres, Color(.4, .95, .9, .65))
	if not is_equal_approx(metres, range_ring_metres):
		range_ring_metres = metres
		GroundDial.resize(range_ring, metres)
	range_ring.global_position = Vector3(global_position.x, .04, global_position.z)
	range_ring.visible = true

func _physics_process(delta: float) -> void:
	if not world.is_combat():
		bow_burst_left = 0
		gun_burst_left = 0
		return
	if carried:
		position = world.player.position + Vector3(0, 1.15, .25)
	else:
		_tick_entrench(delta)
	_update_range_ring()
	cooldown = maxf(0.0, cooldown - delta)
	aim.position = aim.position.lerp(aim_rest, minf(delta * 16.0, 1.0))
	var stats := _current_view(delta)
	if loaded_ball:
		loaded_ball.visible = cooldown <= stats.cooldown_seconds * .3
	if loaded_arrow:
		for arrow in bow_loaded_arrows:
			arrow.visible = cooldown <= stats.cooldown_seconds * .35 and bow_burst_left == 0
	if bow_burst_left > 0:
		_tick_bow_burst(delta, stats)
		return
	var range_metres := stats.range_metres * (stats.area_size if TurretRegistry.get_fire_mode(turret_type) in [TurretRegistry.FIRE_PULSE, TurretRegistry.FIRE_FLAME] else 1.0)
	var fire_mode := TurretRegistry.get_fire_mode(turret_type)
	if fire_mode == TurretRegistry.FIRE_SWEEP:
		_spin_bat(delta, stats, range_metres)
		if progression.evolution_branch == "gunblade":
			_tick_gunblade_burst(delta)
			_fire_gunblade()
		return
	if fire_mode == TurretRegistry.FIRE_PULSE:
		if cooldown <= 0.0 and world.nearest_enemy(position, range_metres):
			_fire_pulse(stats, range_metres)
		return
	target_clock -= delta
	# Cluster scans run five times per second, not for every turret every frame.
	if target_clock <= 0.0:
		var radius := stats.aoe_radius_metres if TurretRegistry.targets_clusters(turret_type) else 0.0
		target = world.combat.select_target(position, range_metres, world.enemies, radius, world.crowd)
		target_clock = .2
	_tick_mechanisms(delta, is_instance_valid(target) and not target.dead and target.overlaps_attack_range(position, range_metres))
	if not is_instance_valid(target) or target.dead or not target.overlaps_attack_range(position, range_metres):
		return
	var heading := WorldGeometry.planar(target.position - position)
	aim.rotation.y = atan2(-heading.x, -heading.z)
	if cooldown > 0.0:
		return
	if fire_mode == TurretRegistry.FIRE_FLAME:
		_fire_flame(stats, range_metres, heading.normalized())
	elif fire_mode == TurretRegistry.FIRE_CHAIN:
		_fire_chain(stats)
	else:
		_fire_projectile(stats)
		if not FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION):
			aim.position += heading.normalized() * -.045

## A shot of this turret's damage type, stamped for kill attribution, with its crit already rolled.
func _new_shot(stats: TurretStats) -> CombatShot3D:
	var shot := CombatShot3D.from_stats(stats.values, TurretRegistry.get_damage_type(turret_type))
	if turret_type == "bow":
		shot.visual_key = "arrow"
		if progression.evolution_branch == "greatbow":
			shot.visual_scale = 1.0 + .3 * progression.evolution_stage
			shot.radius *= shot.visual_scale
	elif turret_type == "bowling":
		shot.visual_key = "bowling_ball"
		shot.radius = .24
		shot.lifetime = 4.0
		if progression.evolution_branch == "heavy_roller":
			shot.visual_scale = 1.0 + .25 * progression.evolution_stage
			shot.radius *= shot.visual_scale
		elif progression.evolution_branch == "bank_shot":
			shot.ricochets = [2, 4, 6][progression.evolution_stage - 1]
			shot.lifetime = 6.0
	if progression.evolution_branch == "siege":
		shot.radius = [.22, .28, .34][progression.evolution_stage - 1]
	shot.source_id = turret_id
	shot.attack_families = TurretRegistry.get_attack_families(turret_type)
	if TurretStatsService.roll_turret_crit():
		shot.damage = TurretStatsService.calculate_turret_crit_damage(shot.damage)
	return shot

func _reset_cooldown(stats: TurretStats) -> void:
	cooldown = stats.cooldown_seconds / (1.0 + spool if progression.evolution_branch == "machine_gun" and progression.evolution_stage >= 2 else 1.0)

func _fire_pulse(stats: TurretStats, range_metres: float) -> void:
	var pulse := _new_shot(stats)
	pulse.splash_radius = range_metres
	world.combat.impact(null, position, Vector3.ZERO, pulse, world.enemies)
	_reset_cooldown(stats)

func _fire_chain(stats: TurretStats) -> void:
	world.combat.chain(muzzle.global_position, target, _new_shot(stats), stats.chain_count,
		stats.chain_range_metres, stats.chain_decay, world.enemies)
	_reset_cooldown(stats)

func _fire_projectile(stats: TurretStats) -> void:
	var heading := WorldGeometry.planar(target.position - muzzle.global_position).normalized()
	if progression.evolution_branch == "repeater_bow":
		bow_burst_left = [2, 3, 5][progression.evolution_stage - 1]
		bow_burst_heading = WorldGeometry.planar(target.position - position).normalized()
		bow_burst_target = target.position
		bow_burst_shot = _new_shot(stats)
		bow_burst_clock = 0.0
		_tick_bow_burst(0.0, stats)
	elif progression.evolution_branch == "scatter" and progression.evolution_stage >= 2:
		for marker: String in ["Muzzle", "Muzzle_1", "Muzzle_2", "Muzzle_3"]:
			var exit := model.find_child(marker, true, false) as Node3D
			if exit:
				var angles: Array = [-30.0, 0.0, 30.0] if progression.evolution_stage >= 3 else [0.0]
				for angle: float in angles:
					world.fire_direction(exit.global_position, (-exit.global_basis.z).rotated(Vector3.UP, deg_to_rad(angle)), _new_shot(stats))
	elif progression.evolution_branch == "scatter":
		for angle: float in [-12.0, 0.0, 12.0]:
			world.fire_direction(muzzle.global_position, heading.rotated(Vector3.UP, deg_to_rad(angle)), _new_shot(stats))
	else:
		world.fire_shot(muzzle.global_position, target, _new_shot(stats))
	if loaded_ball:
		loaded_ball.visible = false
		if bowling_hardware:
			bowling_hardware.kick()
	if recoil_barrel and not FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION):
		recoil_barrel.position.z += .16
	_reset_cooldown(stats)

func display_name() -> String:
	var evolved := TurretEvolution.form_name(turret_type, progression.evolution_branch, progression.evolution_stage)
	return evolved if not evolved.is_empty() else TurretRegistry.get_short_name(turret_type)

## Partial roster builds expose only forms with both an authored model and a working attack.
func available_evolutions() -> Array[String]:
	var result: Array[String] = []
	if not world.session.state.turret_progression_enabled:
		return result
	for branch in progression.evolution_options(turret_type):
		var next_stage := progression.evolution_stage + 1
		var implemented := branch in ["repeater_bow", "greatbow", "wide_flame", "focused_jet", "heavy_roller", "bank_shot", "gunblade", "machine_gun", "scatter", "saber", "siege"]
		if implemented and ClockworkModels.available(TurretEvolution.model_key(turret_type, branch, next_stage)):
			result.append(branch)
	return result

func evolve(branch: String) -> bool:
	if not branch in available_evolutions() or not world.shop.is_open():
		return false
	if not progression.evolve(turret_type, branch):
		return false
	invalidate_stats()
	_rebuild_model()
	target = null
	target_clock = 0.0
	rehit_lockouts.clear()
	reset_physics_interpolation()
	return true

func _tick_mechanisms(delta: float, tracking: bool) -> void:
	if bowling_hardware:
		bowling_hardware.advance(delta, FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION))
	if progression.evolution_branch == "machine_gun" and progression.evolution_stage >= 2:
		var ceiling := 1.5 if progression.evolution_stage >= 3 else 1.0
		spool = move_toward(spool, ceiling if tracking else 0.0, delta * (ceiling if tracking else 2.0))
		if rotor and not FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION):
			rotor.rotate_object_local(Vector3.FORWARD, delta * spool * 18.0)
			muzzle.position = rotor.position + rotor.basis * (muzzle_rest - rotor.position)
	if recoil_barrel:
		recoil_barrel.position = recoil_barrel.position.lerp(barrel_rest, minf(1.0, delta * 10.0))

func _fire_flame(stats: TurretStats, reach: float, heading: Vector3) -> void:
	var half_angle := deg_to_rad(float(stats.values.get("cone_degrees", 36.0))) * .5
	for enemy in world.crowd.query_radius(position, reach, true):
		var offset := WorldGeometry.planar(enemy.position - position)
		if not cone_overlaps_body(offset, heading, reach, half_angle, enemy.hurtbox_radius()):
			continue
		var hit := CombatHit3D.new(stats.damage, position, Vector3.ZERO, GameEnums.DamageType.FIRE)
		hit.source_id = turret_id
		hit.attack_families.assign(["aoe"])
		hit.burn_dps = stats.damage * float(stats.values.get("burn_ratio", 1.6))
		hit.burn_duration = float(stats.values.get("burn_duration", 2.0))
		world.combat.apply_hit(enemy, hit)
	world.effects.show_flame(muzzle.global_position, heading, reach, half_angle / (2.0 if not flame_emitters.is_empty() else 1.0), position)
	for emitter in flame_emitters:
		var direction := WorldGeometry.planar(-emitter.global_basis.z).normalized()
		world.effects.show_flame(emitter.global_position, direction, reach, deg_to_rad(8.0), position)
	_reset_cooldown(stats)

static func cone_overlaps_body(offset: Vector3, heading: Vector3, reach: float, half_angle: float, radius: float) -> bool:
	var bearing := atan2(-heading.x, -heading.z)
	return sweep_overlaps_body(offset, reach, bearing - half_angle, 2.0 * half_angle, radius)

## The rotating barrel only shoots along its visible bore; blade and bullet bonuses stay separate.
func _fire_gunblade() -> void:
	if cooldown > 0.0 or gun_burst_left > 0:
		return
	var heading := WorldGeometry.planar(-muzzle.global_basis.z).normalized()
	for enemy in world.crowd.query_radius(position, gun_stats.range_metres, true):
		if not enemy.overlaps_attack_range(position, gun_stats.range_metres):
			continue
		var offset := WorldGeometry.planar(enemy.position - muzzle.global_position)
		if offset.dot(heading) <= 0.0 or not cone_overlaps_body(offset, heading, gun_stats.range_metres, deg_to_rad(5), enemy.hurtbox_radius()):
			continue
		var shot := CombatShot3D.from_stats(gun_stats.values, GameEnums.DamageType.PHYSICAL)
		shot.attack_families.assign(["projectile"])
		shot.source_id = turret_id
		if TurretStatsService.roll_turret_crit():
			shot.damage = TurretStatsService.calculate_turret_crit_damage(shot.damage)
		world.fire_direction(muzzle.global_position, heading, shot)
		gun_burst_shot = shot
		gun_burst_left = maxi(0, progression.evolution_stage - 1)
		gun_burst_clock = .065
		cooldown = gun_stats.cooldown_seconds
		return

func _tick_bow_burst(delta: float, stats: TurretStats) -> void:
	aim.rotation.y = atan2(-bow_burst_heading.x, -bow_burst_heading.z)
	bow_burst_clock -= delta
	while bow_burst_left > 0 and bow_burst_clock <= 0.0:
		var rail_index := bow_muzzles.size() - bow_burst_left
		var rail := bow_muzzles[clampi(rail_index, 0, bow_muzzles.size() - 1)]
		var flight_heading := WorldGeometry.planar(bow_burst_target - rail.global_position).normalized()
		world.fire_direction(rail.global_position, flight_heading, bow_burst_shot)
		bow_burst_left -= 1
		bow_burst_clock += .09
		cooldown = stats.cooldown_seconds
	for arrow in bow_loaded_arrows:
		arrow.visible = false

## Follow-up shots leave the moving barrel instead of aiming invisibly away from the blade.
func _tick_gunblade_burst(delta: float) -> void:
	if gun_burst_left <= 0:
		return
	gun_burst_clock -= delta
	while gun_burst_left > 0 and gun_burst_clock <= 0.0:
		var exit := gun_muzzles[clampi(gun_muzzles.size() - gun_burst_left, 0, gun_muzzles.size() - 1)]
		var heading := WorldGeometry.planar(-exit.global_basis.z).normalized()
		world.fire_direction(exit.global_position, heading, gun_burst_shot)
		gun_burst_left -= 1
		gun_burst_clock += .065
		cooldown = gun_stats.cooldown_seconds

## Additional held blades reuse the authored arm, hand, hilt and prism geometry.
func _build_saber_arms() -> void:
	saber_angles.assign([0.0])
	if progression.evolution_branch != "saber" or progression.evolution_stage < 2:
		return
	var count := progression.evolution_stage
	var parts: Array[Node3D] = []
	for part_name: String in ["Ceramic_Arm", "Ceramic_Hand", "Sword_Grip", "Sword_Guard", "Prism_Blade"]:
		var part := model.find_child(part_name, true, false) as Node3D
		if part:
			parts.append(part)
	for index in range(1, count):
		var angle := TAU * float(index) / float(count)
		saber_angles.append(angle)
		var arm := Node3D.new()
		arm.name = "SaberArm%d" % index
		aim.add_child(arm)
		arm.rotation.y = angle
		for part in parts:
			arm.add_child(part.duplicate())
