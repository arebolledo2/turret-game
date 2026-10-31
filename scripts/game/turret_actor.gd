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
		stats_valid = false
		target_clock = 0.0
		if value:
			reset_entrench()
var crossfire_muzzles: Array[Node3D] = []
var gun_muzzles: Array[Node3D] = []
var bow_burst := ShotBurst.new(.09)
var flame_emitters: Array[Node3D] = []
var bowling_hardware: BowlingEvolutionVisual
var loaded_ball: Node3D
var loaded_arrow: Node3D
var bow_muzzles: Array[Node3D] = []
var bow_loaded_arrows: Array[Node3D] = []
var cooldown: float = 0.0
## Per-branch attack behaviour (null for forms that the actor handles itself).
var form: TurretForm
var aim: Node3D
var model: Node3D
var muzzle: Node3D
var rotor: Node3D
var recoil_barrel: Node3D
var barrel_rest := Vector3.ZERO
var muzzle_rest := Vector3.ZERO
var aim_rest: Vector3
var target: CombatActor
var target_clock: float = 0.0
## Modifier math is costly and static between purchases, so the resolved stats are rebuilt after `invalidate_stats()`
## or every STATS_REFRESH seconds. `stats_view` is the only cached form; the name-addressed dictionary lives inside it.
var stats_view := TurretStats.new()
var stats_valid: bool = false
var stats_age: float = 0.0
## Entrench stacks, the terrain underfoot and the range ring are owned by small helpers; the forwarding
## properties below keep the common reads short.
var entrench: TurretEntrench
var terrain: TurretTerrain
var range_overlay: TurretRangeRing

const STATS_REFRESH: float = .25
## Seconds between target searches.
const RETARGET_INTERVAL: float = .2
## Where a carried turret rides relative to the player, and how fast the aim arm settles back to rest.
const CARRY_OFFSET := Vector3(0, 1.15, .25)
const AIM_SETTLE_RATE: float = 16.0
const BARREL_SETTLE_RATE: float = 10.0
## Fraction of the cooldown (counted from the end) at which the loaded ball and arrows reappear.
const LOADED_BALL_FRACTION: float = .3
const LOADED_ARROW_FRACTION: float = .35
static var _no_gun_stats := TurretStats.new()
const TESLA_TINT := Color(.35, .9, 1.0)

func _init() -> void:
	entrench = TurretEntrench.new(self)
	terrain = TurretTerrain.new(self)
	range_overlay = TurretRangeRing.new(self)

## Seconds spent deployed in combat at the current spot; drives Entrench stacks.
var stay_time: float:
	get: return entrench.stay_time
	set(value): entrench.stay_time = value
var entrench_stacks_cached: int:
	get: return entrench.stacks
	set(value): entrench.stacks = value
var entrench_ring: MeshInstance3D:
	get: return entrench.ring
var zone_range_bonus: float:
	get: return terrain.range_bonus
var zone_badge: MeshInstance3D:
	get: return terrain.badge
var range_ring: MeshInstance3D:
	get: return range_overlay.ring
var range_ring_metres: float:
	get: return range_overlay.metres
var bow_burst_left: int:
	get: return bow_burst.left
var gun_burst_left: int:
	get: return form.burst.left if form is GunbladeForm else 0
## The gunblade's barrel stats (defaults for every other form).
var gun_stats: TurretStats:
	get: return form.gun_stats if form is GunbladeForm else _no_gun_stats
var spool: float:
	get: return form.spool if form is MachineGunForm else 0.0

func _ready() -> void:
	Events.modifiers_changed.connect(invalidate_stats)
	_rebuild_model()

func _exit_tree() -> void:
	# A Decoy leaving the arena (run reset, removal) takes its taunt and hooks with it.
	if form:
		form.removed()

func _rebuild_model() -> void:
	if is_instance_valid(model):
		remove_child(model)
		model.queue_free()
	var fire_mode := TurretRegistry.get_fire_mode(turret_type)
	if not form or form.form_id != progression.evolution_form:
		if form:
			form.removed()
		form = TurretForm.create(self, progression.evolution_form)
	var asset_key := _model_key(progression.evolution_form)
	var use_clockwork := ClockworkModels.available(asset_key)
	if use_clockwork:
		model = ClockworkModels.instantiate(asset_key)
	else:
		model = SweepForm.placeholder_model() if fire_mode == TurretRegistry.FIRE_SWEEP else load(TurretRegistry.get_model_path(turret_type)).instantiate()
	if turret_type == "tesla" and not use_clockwork:
		EnemyVariants.tint_model(model, "turret_tesla", TESLA_TINT, .5)
	add_child(model)
	_build_form_visual()
	aim = model.find_child("Aim", true, false) as Node3D
	muzzle = model.find_child("Muzzle", true, false) as Node3D
	rotor = model.find_child("Rotor", true, false) as Node3D
	recoil_barrel = model.find_child("Barrel", true, false) as Node3D
	if recoil_barrel:
		barrel_rest = recoil_barrel.position
	muzzle_rest = muzzle.position
	bow_burst.cancel()
	if form:
		form.rebuilt()
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

## Adds the hardware the form's row names (`visual`) to the chassis and keeps the nodes the attack code reads.
func _build_form_visual() -> void:
	var visual: Variant = TurretEvolution.visual_script(progression.evolution_form)
	var handles: TurretVisualHandles = visual.build(model, progression.evolution_form) if visual != null else null
	flame_emitters.assign(handles.flame_emitters if handles else [])
	bowling_hardware = handles.bowling_hardware if handles else null
	gun_muzzles.assign(handles.gun_muzzles if handles else [])
	crossfire_muzzles.assign(handles.crossfire_muzzles if handles else [])

func invalidate_stats() -> void:
	stats_valid = false
	entrench.invalidate()

func entrench_max() -> int:
	return entrench.max_stacks()

func entrench_damage_bonus() -> float:
	return entrench.damage_bonus()

func entrench_fire_rate_bonus() -> float:
	return entrench.fire_rate_bonus()

func entrench_stacks() -> int:
	return entrench.earned_stacks()

func reset_entrench() -> void:
	entrench.reset()

func entrench_progress() -> float:
	return entrench.progress()

func _stack_seconds() -> float:
	return entrench.stack_seconds()

func _tick_entrench(delta: float) -> void:
	entrench.tick(delta)

func _update_entrench_ring() -> void:
	entrench.update_ring()

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
	stats_age += delta
	if not stats_valid or stats_age >= STATS_REFRESH:
		terrain.refresh()
		stats_view = resolve_attack_view()
		stats_valid = true
		if form:
			form.refresh_stats()
		stats_age = 0.0
	return stats_view

## Typed `resolve_attack_stats`, for readers that do not need the modifier dictionary.
func resolve_attack_view(secondary: bool = false, form_id: String = "") -> TurretStats:
	return TurretStats.new(resolve_attack_stats(secondary, form_id))

## Fresh, side-effect-free resolution also supports shop previews without polluting combat caches.
## `form_id` previews a form the turret has not taken; empty resolves the current one.
func resolve_attack_stats(secondary: bool = false, form_id: String = "") -> Dictionary:
	if form_id.is_empty():
		form_id = progression.evolution_form
	var base := TurretEvolution.base_stats(turret_type, form_id)
	if secondary:
		base = TurretEvolution.gunblade_barrel_stats(form_id)
	var stats := ModifierService.get_turret_stats(turret_type, world.difficulty_config, base, "normal" if secondary else "")
	if world.session.state.turret_progression_enabled:
		progression.apply_stats(stats)
	_apply_item_conditions(stats)
	world.item_effects.modify_stats(stats, turret_id, not secondary and "kinetic" in TurretRegistry.get_attack_families(turret_type))
	var terrain_range := world.terrain.range_bonus_at(position) if world.terrain and not carried else 0.0
	stats["range"] = float(stats.get("range", TurretStats.DEFAULT_RANGE)) * (1.0 + terrain_range)
	var bonus := maxf(0.0, ModifierService.apply_modifiers_to_stat(1.0, "entrench_bonus")) * float(entrench_stacks_cached)
	if bonus > 0.0:
		stats["damage"] *= 1.0 + GameConstants.ENTRENCH_DAMAGE_PER_STACK * bonus
		stats["fire_rate"] = float(stats.get("fire_rate", 1.0)) * (1.0 + GameConstants.ENTRENCH_FIRE_RATE_PER_STACK * bonus)
	var proximity_stats := resolve_attack_stats() if secondary else stats
	world.item_effects.apply_proximity(stats, self, effective_range(TurretStats.new(proximity_stats)))
	return stats

## Range after the area multiplier that pulse and flame attacks apply.
func effective_range(view: TurretStats) -> float:
	var area := view.area_size if TurretRegistry.get_fire_mode(turret_type) in [TurretRegistry.FIRE_PULSE, TurretRegistry.FIRE_FLAME] else 1.0
	return view.range_metres * area

func _update_range_ring() -> void:
	range_overlay.update()

func _physics_process(delta: float) -> void:
	if not world.is_combat():
		if form: form.clear()
		bow_burst.cancel()
		return
	if carried:
		position = world.player.position + CARRY_OFFSET
	else:
		_tick_entrench(delta)
	_update_range_ring()
	cooldown = maxf(0.0, cooldown - delta)
	if form:
		form.tick(delta)
	aim.position = aim.position.lerp(aim_rest, minf(delta * AIM_SETTLE_RATE, 1.0))
	var stats := _current_view(delta)
	if loaded_ball:
		loaded_ball.visible = cooldown <= stats.cooldown_seconds * LOADED_BALL_FRACTION
	if loaded_arrow:
		for arrow in bow_loaded_arrows:
			arrow.visible = cooldown <= stats.cooldown_seconds * LOADED_ARROW_FRACTION and bow_burst.left == 0
	if bow_burst.left > 0:
		_tick_bow_burst(delta, stats)
		return
	var range_metres := effective_range(stats)
	var fire_mode := TurretRegistry.get_fire_mode(turret_type)
	if fire_mode == TurretRegistry.FIRE_NONE or fire_mode == TurretRegistry.FIRE_DEPLOY or fire_mode == TurretRegistry.FIRE_BEAM:
		# A utility, deploying or beam turret: its form's `tick` (already run above) is all it does.
		return
	if fire_mode == TurretRegistry.FIRE_SWEEP:
		form.spin(delta, stats, range_metres)
		form.tick_sweep(delta)
		return
	if fire_mode == TurretRegistry.FIRE_PULSE:
		if cooldown > 0.0:
			return
		var pulse_target := world.nearest_enemy(position, range_metres)
		if not pulse_target:
			return
		if form:
			form.fire_pulse(stats, range_metres, pulse_target)
		else:
			_fire_pulse(stats, range_metres)
		return
	target_clock -= delta
	# Cluster scans run five times per second, not for every turret every frame.
	if target_clock <= 0.0:
		var mode := TurretRegistry.get_targeting(turret_type)
		if TurretTargeting.handles(mode):
			target = TurretTargeting.select(mode, position, range_metres, world.enemies)
		else:
			var radius := stats.aoe_radius_metres if TurretRegistry.targets_clusters(turret_type) else 0.0
			target = world.combat.select_target(position, range_metres, world.enemies, radius, world.crowd)
		target_clock = RETARGET_INTERVAL
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
	elif fire_mode == TurretRegistry.FIRE_INSTANT:
		_fire_instant(stats, range_metres)
		if not FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION):
			aim.position += heading.normalized() * -.06
	else:
		_fire_projectile(stats)
		if not FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION):
			aim.position += heading.normalized() * -.045

## A shot of this turret's damage type, stamped for kill attribution, with its crit already rolled.
func _new_shot(stats: TurretStats) -> CombatShot3D:
	var shot := CombatShot3D.from_stats(stats.values, TurretRegistry.get_damage_type(turret_type))
	TurretEvolution.shape_shot(shot, turret_type, progression.evolution_form)
	shot.source_id = turret_id
	shot.attack_families = TurretRegistry.get_attack_families(turret_type)
	if TurretStatsService.roll_turret_crit():
		shot.critical = true
		shot.damage = TurretStatsService.calculate_turret_crit_damage(shot.damage)
	return shot

func _reset_cooldown(stats: TurretStats) -> void:
	cooldown = stats.cooldown_seconds / (form.cooldown_divisor() if form else 1.0)

func _fire_pulse(stats: TurretStats, range_metres: float) -> void:
	var pulse := _new_shot(stats)
	pulse.splash_radius = range_metres
	world.combat.impact(null, position, Vector3.ZERO, pulse, world.enemies)
	_reset_cooldown(stats)

func _fire_chain(stats: TurretStats) -> void:
	world.combat.chain(muzzle.global_position, target, _new_shot(stats), stats.chain_count,
		stats.chain_range_metres, stats.chain_decay, world.enemies)
	_reset_cooldown(stats)

## Hit-scan shot at the turret's pick (re-picked now, because the target cache can be 0.2 s old and a Sniper must hit the
## toughest enemy). `pierce` extra enemies on the line through it are struck too: those behind the target, or every enemy
## on the line to full range when pierce is unlimited (Horizon Piercer).
func _fire_instant(stats: TurretStats, range_metres: float) -> void:
	var struck := TurretTargeting.select(TurretRegistry.get_targeting(turret_type), position, range_metres, world.enemies)
	if not struck:
		return
	target = struck
	var heading := WorldGeometry.planar(struck.position - position).normalized()
	aim.rotation.y = atan2(-heading.x, -heading.z)
	if form:
		form.before_instant(stats, range_metres)
	var unlimited := stats.pierce >= TurretEvolution.SNIPER_UNLIMITED_PIERCE
	var victims: Array[CombatActor] = [struck]
	if stats.pierce > 0:
		victims.append_array(TurretTargeting.on_lane(position, struck, range_metres, TurretEvolution.SNIPER_LANE_HALF_WIDTH,
			world.enemies, unlimited, -1 if unlimited else stats.pierce))
	var reach := 0.0
	for victim in victims:
		reach = maxf(reach, WorldGeometry.planar(victim.position - position).dot(heading))
	var tip := position + heading * (range_metres if unlimited else reach)
	var shot := _new_shot(stats)
	world.effects.show_tracer(muzzle.global_position, Vector3(tip.x, muzzle.global_position.y, tip.z))
	world.effects.show_muzzle(muzzle.global_position, shot.damage_type)
	world.audio.play_cue("ion", muzzle.global_position)
	for victim in victims:
		world.combat.impact(victim, victim.position, heading, shot.copy(), [] as Array[CombatActor])
	_reset_cooldown(stats)

func _fire_projectile(stats: TurretStats) -> void:
	var heading := WorldGeometry.planar(target.position - muzzle.global_position).normalized()
	if not form or not form.fire_projectile(stats, heading):
		world.fire_shot(muzzle.global_position, target, _new_shot(stats))
	if loaded_ball:
		loaded_ball.visible = false
		if bowling_hardware:
			bowling_hardware.kick()
	if recoil_barrel and not FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION):
		recoil_barrel.position.z += .16
	_reset_cooldown(stats)

## The authored chassis for a form, else the base turret's own.
func _model_key(form_id: String) -> String:
	var key := TurretEvolution.model_key(form_id)
	if not key.is_empty():
		return key
	var own := str(TurretRegistry.get_type(turret_type).get("model_key", ""))
	if not own.is_empty():
		return own
	return "ion" if turret_type == "normal" else turret_type

func has_barrel() -> bool:
	return form != null and form.has_barrel()

func display_name() -> String:
	var evolved := TurretEvolution.form_name(progression.evolution_form)
	return evolved if not evolved.is_empty() else TurretRegistry.get_short_name(turret_type)

## Partial roster builds expose only forms with both an authored model and a working attack.
func available_evolutions() -> Array[String]:
	var result: Array[String] = []
	if not world.session.state.turret_progression_enabled:
		return result
	for option in progression.evolution_options(turret_type):
		if TurretEvolution.is_implemented(option) and ClockworkModels.available(_model_key(option)):
			result.append(option)
	return result

func evolve(form_id: String) -> bool:
	if not form_id in available_evolutions() or not world.shop.is_open():
		return false
	if not progression.evolve(turret_type, form_id):
		return false
	invalidate_stats()
	_rebuild_model()
	target = null
	target_clock = 0.0
	reset_physics_interpolation()
	return true

func _tick_mechanisms(delta: float, tracking: bool) -> void:
	if bowling_hardware:
		bowling_hardware.advance(delta, FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION))
	if form:
		form.tick_mechanisms(delta, tracking)
	if recoil_barrel:
		recoil_barrel.position = recoil_barrel.position.lerp(barrel_rest, minf(1.0, delta * BARREL_SETTLE_RATE))

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
	return SweepForm.sweep_overlaps_body(offset, reach, bearing - half_angle, 2.0 * half_angle, radius)

func _tick_bow_burst(delta: float, stats: TurretStats) -> void:
	aim.rotation.y = atan2(-bow_burst.heading.x, -bow_burst.heading.z)
	bow_burst.advance(delta)
	while bow_burst.is_due():
		var rail_index := bow_muzzles.size() - bow_burst.left
		var rail := bow_muzzles[clampi(rail_index, 0, bow_muzzles.size() - 1)]
		var flight_heading := WorldGeometry.planar(bow_burst.aim_point - rail.global_position).normalized()
		world.fire_direction(rail.global_position, flight_heading, bow_burst.shot)
		bow_burst.consume()
		cooldown = stats.cooldown_seconds
	for arrow in bow_loaded_arrows:
		arrow.visible = false
