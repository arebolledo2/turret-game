class_name WaveDirector
extends RefCounted

## Wave lifecycle for one run: announcement, spawn schedule, timer and wave-end resolution.
## `ArenaWorld` owns the actors and exposes this state through forwarding properties.
const ANNOUNCEMENT_TIME: float = .8
const FIRST_SPAWN_DELAY: float = .2
const GROUP_INTERVAL := 3.5
const SPAWN_WARNING := .9
const SPAWN_CLEARANCE := .9
const CONVOY_CORE_SPAWN_GAP := 4.0
const CONVOY_PATH_HALF_WIDTH := 2.0
const SURVIVE_SPAWN_EDGE_MARGIN := 1.0
var world: ArenaWorld
## The run's mutable state (wave number, time survived); services only apply rules to it.
var state: RunSessionState:
	get: return world.session.state
var spawned_this_wave: int = 0
var remaining_spawns: int = 0
var spawn_clock: float = 0.0
var spawn_interval: float = 1.0
var time_left: float = 0.0
var announcement_left: float = 0.0
## Fractional accumulators: an elite (or core seeker) spawns each time the running share crosses 1, so the mix is
## even and deterministic (no gameplay RNG is consumed).
var elite_credit: float = 0.0
var seeker_credit: float = 0.0
var spawn_plan: Array[String] = []
var boss_spawned: bool = false
var pending_spawns: Array[PendingSpawn] = []
var spawn_credit := 0.0
var arrival_time_left := 0.0

func clear_spawn_warnings() -> void:
	for pending in pending_spawns:
		if is_instance_valid(pending.marker): pending.marker.queue_free()
	pending_spawns.clear()

## Protect the whole active waypoint-to-waypoint leg, including the part already travelled.
func convoy_spawn_blocked(at: Vector3) -> bool:
	if not world.convoy_mode or not is_instance_valid(world.core): return false
	at = WorldGeometry.planar(at)
	if at.distance_to(WorldGeometry.planar(world.core.position)) < world.core.radius + CONVOY_CORE_SPAWN_GAP:
		return true
	var mover := world.convoy_mover
	if not mover or not mover.route or mover.finished: return false
	var index := mover.target_index
	if index < 1 or index >= mover.route.doors.size(): return false
	var from := WorldGeometry.planar(mover.route.doors[index - 1])
	var to := WorldGeometry.planar(mover.route.doors[index])
	var closest := Geometry3D.get_closest_point_to_segment(at, from, to)
	return at.distance_to(closest) < CONVOY_PATH_HALF_WIDTH

func spawn_blocked(at: Vector3) -> bool:
	if convoy_spawn_blocked(at): return true
	if WorldGeometry.planar(world.player.position - at).length() < SPAWN_CLEARANCE + world.player.hurtbox_radius():
		return true
	return world.core != null and WorldGeometry.planar(world.core.position - at).length() < SPAWN_CLEARANCE + world.core.radius

func warn_spawn(type_id: String, at: Vector3, boss: bool = false) -> void:
	if spawn_blocked(at): return
	var marker := GroundDial.create(world.actor_root, SPAWN_CLEARANCE, Color("f4a775"), true)
	marker.position = at + Vector3(0, .05, 0)
	GroundDial.update(marker, 0.0, false, 4)
	pending_spawns.append(PendingSpawn.new(type_id, at, SPAWN_WARNING, marker, boss))

func advance_spawn_warnings(delta: float) -> void:
	for index in range(pending_spawns.size() - 1, -1, -1):
		var pending := pending_spawns[index]
		pending.left -= delta
		var blocked := spawn_blocked(pending.at)
		if blocked or pending.left <= 0.0:
			if is_instance_valid(pending.marker): pending.marker.queue_free()
			pending_spawns.remove_at(index)
			if blocked: continue # Cancel, without relocating or banking a replacement.
			var type_id: String = pending.type
			if not pending.boss and active_count(type_id) >= int(EnemyEcology.CAPS.get(type_id, 10000)):
				type_id = EnemyEcology.fallback(state.current_wave, world.escort_mode())
			var assault := not EnemyEcology.TYPES.has(type_id)
			var elite := assault and state.current_wave >= 6 and _take_credit("elite_chance")
			var seeker := assault and state.current_wave >= 6 and world.core != null and _take_credit("seeker_share")
			spawn_enemy(pending.at, type_id, elite, seeker)
		else:
			GroundDial.update(pending.marker, 1.0 - float(pending.left) / SPAWN_WARNING, false, 4)

func queue_spawn_group() -> void:
	spawn_credit += GROUP_INTERVAL / maxf(spawn_interval, .001)
	var count := mini(remaining_spawns, maxi(0, floori(spawn_credit)))
	if arrival_time_left <= GROUP_INTERVAL + SPAWN_WARNING:
		count = remaining_spawns
	elif count < 2 and remaining_spawns > 1:
		return # Accumulate a small group instead of exhausting sparse escort waves early.
	spawn_credit -= count
	for index in count:
		var type_id := spawn_plan[spawned_this_wave] if spawned_this_wave < spawn_plan.size() else EnemyEcology.fallback(state.current_wave, world.escort_mode())
		warn_spawn(type_id, encounter_position(type_id))
		spawned_this_wave += 1
		remaining_spawns -= 1

func tick(delta: float) -> void:
	if GameStateMachine.current_state in [GameStateMachine.GameState.WAVE_END, GameStateMachine.GameState.PREPARATION]:
		return
	state.time_survived += delta
	if GameStateMachine.current_state == GameStateMachine.GameState.WAVE_ANNOUNCEMENT:
		announcement_left -= delta
		if announcement_left <= 0.0:
			GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
		return
	if not world.is_combat():
		return
	if not boss_spawned and EnemyEcology.BOSSES.has(state.current_wave):
		boss_spawned = true
		var boss_id: String = EnemyEcology.BOSSES[state.current_wave]
		warn_spawn(boss_id, encounter_position(boss_id), true)
	world.crowd.rebuild(world.enemies)
	world.crowd.resolve_overlaps(_fixed_obstacles())
	time_left = maxf(0.0, time_left - delta)
	advance_spawn_warnings(delta)
	arrival_time_left = maxf(0.0, arrival_time_left - delta)
	spawn_clock -= delta
	if remaining_spawns > 0 and spawn_clock <= 0.0 and arrival_time_left > SPAWN_WARNING:
		queue_spawn_group()
		spawn_clock += GROUP_INTERVAL
	world.drops.tick(delta)
	world.build_zones.tick(delta)
	# Convoy rounds end on arrival at the final door; the timer is only a safety net.
	if time_left <= 0.0 or (world.convoy_mover != null and world.convoy_mover.finished):
		finish_wave.call_deferred() # Let actors and projectiles resolve this final physics tick first.

## Circles enemies may not occupy. The hero is excluded: enemies must reach it for contact damage.
func _fixed_obstacles() -> Array:
	var obstacles: Array = []
	for turret in world.turrets:
		if is_instance_valid(turret):
			obstacles.append({"position": turret.position, "radius": GameConstants.TURRET_BODY_RADIUS})
	if world.core:
		obstacles.append({"position": world.core.position, "radius": world.core.radius})
	return obstacles

func begin_next_wave() -> bool:
	if GameStateMachine.current_state not in [GameStateMachine.GameState.IDLE, GameStateMachine.GameState.SHOP]:
		return false
	if not GameStateMachine.transition_to(GameStateMachine.GameState.PREPARATION):
		return false
	state.current_wave += 1
	# Flags requested during the previous wave land here, before this wave's systems start.
	FeatureFlagService.apply_pending()
	world.heal_between_waves()
	world.telemetry.begin_wave(state.current_wave)
	world.build_zones.begin_wave()
	if world.stage:
		world.stage.set_floor_wave(state.current_wave, EnemyEcology.BOSSES.has(state.current_wave))
	announcement_left = ANNOUNCEMENT_TIME
	clear_spawn_warnings()
	spawn_credit = 0.0
	spawned_this_wave = 0
	boss_spawned = false
	elite_credit = 0.0
	seeker_credit = 0.0
	time_left = GameStateService.get_wave_duration(state.current_wave)
	remaining_spawns = GameStateService.get_wave_enemy_count(state.current_wave, float(world.difficulty_config["enemy_count_mult"]), ItemTrackingService.get_enemy_count_multiplier())
	var spawn_window := time_left
	if world.convoy_mode:
		# The round lasts as long as the route takes, so a faster core gets proportionally fewer enemies.
		world.start_convoy_round()
		var route_time := world.convoy_route.duration(PlayerStatsService.get_core_move_speed())
		remaining_spawns = maxi(1, roundi(remaining_spawns * maxf(route_time / time_left, .01)))
		spawn_window = route_time
		time_left = route_time * GameConstants.CONVOY_SAFETY_FACTOR
	if world.core:
		# Higher pressure means more arrivals across the whole round, not an early cutoff.
		var rate := maxf(DifficultyService.wave_rule(world.difficulty_config, "spawn_rate_mult", state.current_wave), .1)
		remaining_spawns = maxi(1, roundi(remaining_spawns * rate))
	var budget := maxi(1, roundi(remaining_spawns * EnemyEcology.budget_multiplier(state.current_wave, world.escort_mode())))
	spawn_plan = EnemyEcology.schedule(state.current_wave, budget, world.escort_mode())
	remaining_spawns = spawn_plan.size()
	spawn_interval = spawn_window / maxf(float(remaining_spawns), 1.0)
	arrival_time_left = spawn_window
	spawn_clock = FIRST_SPAWN_DELAY
	world.message = EnemyVariants.notice_for_wave(state.current_wave)
	world.spawn_zones.generate(state.current_wave)
	world.preparation.begin()
	return true

func finish_wave() -> bool:
	if not world.is_combat():
		return false
	if not GameStateMachine.transition_to(GameStateMachine.GameState.WAVE_END):
		return false
	world.heal_between_waves()
	# Snapshot carried positions and uncollected pickups before cleanup moves/removes them.
	var settled := world.salvage.settle(state.current_wave)
	var show_rewards := settled and world.present_wave_rewards and world.show_hud and int(world.salvage.last_settlement.get("xp_awarded", 0)) > 0
	world.clear_field(true, not show_rewards)
	var reward := EconomyService.get_wave_scrap_base(state.current_wave)
	world.collect_scrap(reward)
	world.message = "Wave secured · +%d scrap bonus" % reward
	if show_rewards:
		world.reward_presentation.begin(world.salvage.last_settlement)
	else:
		complete_wave()
	return true

func complete_wave() -> void:
	if GameStateMachine.current_state != GameStateMachine.GameState.WAVE_END or not state.is_game_active:
		return
	if not world.drops.pending_items.is_empty():
		if world.show_hud:
			world.chest_rewards.show_next()
		return
	world.placement.drop_carried()
	if state.current_wave >= world.wave_limit:
		world.audio.play_cue("victory", world.player.position)
		GameStateMachine.transition_to(GameStateMachine.GameState.VICTORY)
		state.is_game_active = false
	else:
		GameStateMachine.transition_to(GameStateMachine.GameState.SHOP)
		if world.convoy_mode:
			world.plan_convoy_route(state.current_wave + 1) # previewed during the shop
		world.shop.open()
		world.audio.play_cue("wave", world.player.position)

func _take_credit(rule_key: String) -> bool:
	if rule_key == "elite_chance" and state.current_wave < int(DifficultyService.rule(world.difficulty_config, "elite_start_wave")):
		return false
	var share := DifficultyService.wave_rule(world.difficulty_config, rule_key, state.current_wave)
	if rule_key == "seeker_share" and world.escort_mode() and state.current_wave >= 6:
		share = maxf(share, .5)
	if share <= 0.0:
		return false
	var credit := (elite_credit if rule_key == "elite_chance" else seeker_credit) + share
	var taken := credit >= 1.0
	if taken:
		credit -= 1.0
	if rule_key == "elite_chance":
		elite_credit = credit
	else:
		seeker_credit = credit
	return taken

## `elite` toughens the enemy; `seeker` (core mode) makes it ignore the hero and head for the core.
func spawn_enemy(at: Vector3, type_id: String = "basic", elite: bool = false, seeker: bool = false) -> EnemyActor:
	var enemy := EnemyActor.new()
	enemy.world = world
	enemy.enemy_type = type_id
	var base := EnemyStats.for_wave(type_id, maxi(state.current_wave, 1), world.difficulty_config)
	enemy.max_health = base.health
	enemy.health = enemy.max_health
	enemy.speed = base.speed_metres
	enemy.contact_damage = base.contact_damage
	enemy.mass = base.mass
	enemy.scrap_value = base.scrap_value
	enemy.body_scale = EnemyVariants.body_scale(type_id)
	enemy.explosion_radius = base.explosion_radius_metres
	enemy.explosion_damage = base.explosion_damage
	if elite:
		enemy.elite = true
		enemy.max_health *= DifficultyService.rule(world.difficulty_config, "elite_health_mult")
		enemy.health = enemy.max_health
		enemy.speed *= DifficultyService.rule(world.difficulty_config, "elite_speed_mult")
		enemy.scrap_value *= 2
		enemy.body_scale *= 1.15
	enemy.ignores_hero = seeker and not EnemyEcology.TYPES.has(type_id)
	enemy.position = at
	world.actor_root.add_child(enemy)
	enemy.reset_physics_interpolation()
	world.enemies.append(enemy)
	return enemy

## Core mode: a point on the rectangle at CORE_SPAWN_BOX of the arena, so waves arrive from every side of the core.
## A spot too close to the hero is retried a few times.
func _core_spawn_position() -> Vector3:
	var half := WorldGeometry.HALF_ARENA * GameConstants.CORE_SPAWN_BOX
	# In convoy mode the box follows the core so waves always arrive from every side of it.
	var centre := world.core.position if world.convoy_mode else Vector3.ZERO
	var result := Vector3.ZERO
	for attempt in 6:
		var along := GameRandom.gameplay.randf() * (half.x + half.y) * 4.0
		if along < half.x * 2.0:
			result = Vector3(-half.x + along, 0, -half.y)
		elif along < half.x * 2.0 + half.y * 2.0:
			result = Vector3(half.x, 0, -half.y + along - half.x * 2.0)
		elif along < half.x * 4.0 + half.y * 2.0:
			result = Vector3(half.x - (along - half.x * 2.0 - half.y * 2.0), 0, half.y)
		else:
			result = Vector3(-half.x, 0, half.y - (along - half.x * 4.0 - half.y * 2.0))
		if world.convoy_mode:
			result = WorldGeometry.clamp_position(centre + result)
		if not is_instance_valid(world.player) or WorldGeometry.planar(result - world.player.position).length() >= GameConstants.ENEMY_SPAWN_MIN_DISTANCE:
			break
	return result

## Survive mode: a uniformly random point anywhere in the arena, kept ENEMY_SPAWN_MIN_DISTANCE from the hero, so
## arrivals are spread over the whole map instead of crowding the hero's surroundings.
func spawn_position() -> Vector3:
	if world.core:
		return _core_spawn_position()
	var centre := WorldGeometry.planar(world.player.position) if is_instance_valid(world.player) else Vector3.ZERO
	var bounds := WorldGeometry.HALF_ARENA - Vector2.ONE * SURVIVE_SPAWN_EDGE_MARGIN
	var result := Vector3.ZERO
	for attempt in 12:
		result = Vector3(GameRandom.gameplay.randf_range(-bounds.x, bounds.x), 0, GameRandom.gameplay.randf_range(-bounds.y, bounds.y))
		if result.distance_to(centre) >= GameConstants.ENEMY_SPAWN_MIN_DISTANCE:
			break
	return result

func active_count(type_id: String) -> int:
	var count := 0
	for actor in world.enemies:
		if is_instance_valid(actor) and not actor.dead and actor.enemy_type == type_id:
			count += 1
	return count

## Each arrival independently samples a position; timing is grouped, positions are not.
## Survive mode scatters every non-boss arrival over the arena. Core mode keeps lazy beetles within reach of the
## hero: they intentionally will not march in from the map edge.
func encounter_position(type_id: String) -> Vector3:
	var candidate := Vector3.ZERO
	for attempt in 24:
		candidate = _sample_encounter_position(type_id)
		if not spawn_blocked(candidate): return candidate
	# warn_spawn rejects this final candidate if no safe position was found.
	return candidate

func _sample_encounter_position(type_id: String) -> Vector3:
	if world.spawn_zones and not world.spawn_zones.centres.is_empty() and GameRandom.gameplay.randf() < SpawnZones.BIAS:
		return world.spawn_zones.sample()
	if not world.core and not EnemyEcology.is_boss(type_id):
		return spawn_position()
	var centre := world.player.position
	var angle := GameRandom.gameplay.randf() * TAU
	var distance := GameRandom.gameplay.randf_range(5.0, 7.0)
	if type_id == "drowse":
		distance = GameRandom.gameplay.randf_range(3.5, 6.0)
	elif EnemyEcology.is_boss(type_id):
		distance = 6.0
	elif type_id not in ["tender", "kite", "lobber"]:
		return spawn_position()
	var result := Vector3.ZERO
	for attempt in 8:
		result = WorldGeometry.clamp_position(centre + Vector3(cos(angle), 0, sin(angle)) * distance, 1.0)
		if result.distance_to(world.player.position) >= 3.0 and (not world.core or result.distance_to(world.core.position) >= 2.0):
			break
		angle += PI * .5
	return result
