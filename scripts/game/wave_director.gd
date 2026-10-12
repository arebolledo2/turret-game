class_name WaveDirector
extends RefCounted

## Wave lifecycle for one run: announcement, spawn schedule, timer and wave-end resolution.
## `ArenaWorld` owns the actors and exposes this state through forwarding properties.
const ANNOUNCEMENT_TIME: float = .8
const FIRST_SPAWN_DELAY: float = .2
var world: ArenaWorld
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
const GROUP_INTERVAL := 3.5
const SPAWN_WARNING := .9
const SPAWN_CLEARANCE := .9
var pending_spawns: Array[Dictionary] = []
var spawn_credit := 0.0
var arrival_time_left := 0.0

func clear_spawn_warnings() -> void:
	for pending in pending_spawns:
		if is_instance_valid(pending.marker): pending.marker.queue_free()
	pending_spawns.clear()

func spawn_blocked(at: Vector3) -> bool:
	if WorldGeometry.planar(world.player.position - at).length() < SPAWN_CLEARANCE + world.player.hurtbox_radius():
		return true
	return world.core != null and WorldGeometry.planar(world.core.position - at).length() < SPAWN_CLEARANCE + world.core.radius

func warn_spawn(type_id: String, at: Vector3, boss: bool = false) -> void:
	if spawn_blocked(at): return
	var marker := GroundDial.create(world.actor_root, SPAWN_CLEARANCE, Color("f4a775"), true)
	marker.position = at + Vector3(0, .05, 0)
	GroundDial.update(marker, 0.0, false, 4)
	pending_spawns.append({"type": type_id, "at": at, "left": SPAWN_WARNING, "marker": marker, "boss": boss})

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
				type_id = EnemyEcology.fallback(GameStateService.current_wave)
			var assault := not EnemyEcology.TYPES.has(type_id)
			var elite := assault and GameStateService.current_wave >= 6 and _take_credit("elite_chance")
			var seeker := assault and GameStateService.current_wave >= 6 and world.core != null and _take_credit("seeker_share")
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
		var type_id := spawn_plan[spawned_this_wave] if spawned_this_wave < spawn_plan.size() else EnemyEcology.fallback(GameStateService.current_wave)
		warn_spawn(type_id, encounter_position(type_id))
		spawned_this_wave += 1
		remaining_spawns -= 1

func tick(delta: float) -> void:
	if GameStateMachine.current_state in [GameStateMachine.GameState.WAVE_END, GameStateMachine.GameState.PREPARATION]:
		return
	GameStateService.time_survived += delta
	if GameStateMachine.current_state == GameStateMachine.GameState.WAVE_ANNOUNCEMENT:
		announcement_left -= delta
		if announcement_left <= 0.0:
			GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
		return
	if not world.is_combat():
		return
	if not boss_spawned and EnemyEcology.BOSSES.has(GameStateService.current_wave):
		boss_spawned = true
		var boss_id: String = EnemyEcology.BOSSES[GameStateService.current_wave]
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
	GameStateService.current_wave += 1
	# Flags requested during the previous wave land here, before this wave's systems start.
	FeatureFlagService.apply_pending()
	world.telemetry.begin_wave(GameStateService.current_wave)
	world.build_zones.begin_wave()
	announcement_left = ANNOUNCEMENT_TIME
	clear_spawn_warnings()
	spawn_credit = 0.0
	spawned_this_wave = 0
	boss_spawned = false
	elite_credit = 0.0
	seeker_credit = 0.0
	time_left = GameStateService.get_wave_duration(GameStateService.current_wave)
	remaining_spawns = GameStateService.get_wave_enemy_count(GameStateService.current_wave, float(world.difficulty_config["enemy_count_mult"]), ItemTrackingService.get_enemy_count_multiplier())
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
		var rate := maxf(DifficultyService.wave_rule(world.difficulty_config, "spawn_rate_mult", GameStateService.current_wave), .1)
		remaining_spawns = maxi(1, roundi(remaining_spawns * rate))
	var budget := maxi(1, roundi(remaining_spawns * EnemyEcology.budget_multiplier(GameStateService.current_wave)))
	spawn_plan = EnemyEcology.schedule(GameStateService.current_wave, budget)
	remaining_spawns = spawn_plan.size()
	spawn_interval = spawn_window / maxf(float(remaining_spawns), 1.0)
	arrival_time_left = spawn_window
	spawn_clock = FIRST_SPAWN_DELAY
	world.message = EnemyVariants.notice_for_wave(GameStateService.current_wave)
	world.preparation.begin()
	return true

func finish_wave() -> bool:
	if not world.is_combat():
		return false
	if not GameStateMachine.transition_to(GameStateMachine.GameState.WAVE_END):
		return false
	# Snapshot carried positions and uncollected pickups before cleanup moves/removes them.
	var settled := world.salvage.settle(GameStateService.current_wave)
	var show_rewards := settled and world.present_wave_rewards and world.show_hud and int(world.salvage.last_settlement.get("xp_awarded", 0)) > 0
	world.clear_field(true, not show_rewards)
	var reward := EconomyService.get_wave_scrap_base(GameStateService.current_wave)
	world.collect_scrap(reward)
	world.message = "Wave secured · +%d scrap bonus" % reward
	if show_rewards:
		world.reward_presentation.begin(world.salvage.last_settlement)
	else:
		complete_wave()
	return true

func complete_wave() -> void:
	if GameStateMachine.current_state != GameStateMachine.GameState.WAVE_END or not GameStateService.is_game_active:
		return
	if not world.drops.pending_items.is_empty():
		if world.show_hud:
			world.chest_rewards.show_next()
		return
	world.placement.drop_carried()
	if GameStateService.current_wave >= world.wave_limit:
		world.audio.play_cue("victory", world.player.position)
		GameStateMachine.transition_to(GameStateMachine.GameState.VICTORY)
		GameStateService.is_game_active = false
	else:
		GameStateMachine.transition_to(GameStateMachine.GameState.SHOP)
		if world.convoy_mode:
			world.plan_convoy_route(GameStateService.current_wave + 1) # previewed during the shop
		world.shop.open()
		world.audio.play_cue("wave", world.player.position)

func _take_credit(rule_key: String) -> bool:
	if rule_key == "elite_chance" and GameStateService.current_wave < int(DifficultyService.rule(world.difficulty_config, "elite_start_wave")):
		return false
	var share := DifficultyService.wave_rule(world.difficulty_config, rule_key, GameStateService.current_wave)
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
func spawn_enemy(at: Vector3, type_id: String = "basic", elite: bool = false, seeker: bool = false) -> CombatActor:
	var enemy := CombatActor.new()
	enemy.world = world
	enemy.is_enemy = true
	enemy.enemy_type = type_id
	var base := EnemyStats.for_wave(type_id, maxi(GameStateService.current_wave, 1), world.difficulty_config)
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

## Enemies appear on a ring just outside the default-zoom view around the player, clamped to the arena, so they
## reach the fight quickly on the large map. A spot clamped back into view is retried a few times.
func spawn_position() -> Vector3:
	if world.core:
		return _core_spawn_position()
	var centre := WorldGeometry.planar(world.player.position) if is_instance_valid(world.player) else Vector3.ZERO
	var ring := world.camera_rig.visible_half_extents(GameConstants.CAMERA_DEFAULT_ZOOM) + Vector2.ONE * GameConstants.ENEMY_SPAWN_VIEW_MARGIN
	var result := Vector3.ZERO
	for attempt in 8:
		var edge := GameRandom.gameplay.randi_range(0, 3)
		var x := GameRandom.gameplay.randf_range(-ring.x, ring.x)
		var z := GameRandom.gameplay.randf_range(-ring.y, ring.y)
		match edge:
			0: x = -ring.x
			1: x = ring.x
			2: z = -ring.y
			3: z = ring.y
		result = WorldGeometry.clamp_position(centre + Vector3(x, 0, z))
		if WorldGeometry.planar(result - centre).length() >= GameConstants.ENEMY_SPAWN_MIN_DISTANCE:
			break
	return result

func active_count(type_id: String) -> int:
	var count := 0
	for actor in world.enemies:
		if is_instance_valid(actor) and not actor.dead and actor.enemy_type == type_id:
			count += 1
	return count

## Each arrival independently samples a direction; timing is grouped, positions are not.
## Lazy beetles must appear within reach: they intentionally will not march in from the map edge.
func encounter_position(type_id: String) -> Vector3:
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
