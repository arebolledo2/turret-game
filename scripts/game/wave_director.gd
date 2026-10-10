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

func tick(delta: float) -> void:
	GameStateService.time_survived += delta
	if GameStateMachine.current_state == GameStateMachine.GameState.WAVE_ANNOUNCEMENT:
		announcement_left -= delta
		if announcement_left <= 0.0:
			GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
		return
	if not world.is_combat():
		return
	world.crowd.rebuild(world.enemies)
	world.crowd.resolve_overlaps(_fixed_obstacles())
	time_left = maxf(0.0, time_left - delta)
	spawn_clock -= delta
	if remaining_spawns > 0 and spawn_clock <= 0.0:
		var type_id := EnemyVariants.pick_type(GameStateService.current_wave, spawned_this_wave)
		var elite := _take_credit("elite_chance")
		var seeker := world.core != null and _take_credit("seeker_share")
		spawn_enemy(spawn_position(), type_id, elite, seeker)
		spawned_this_wave += 1
		remaining_spawns -= 1
		spawn_clock += spawn_interval
	world.drops.tick(delta)
	world.build_zones.tick(delta)
	# Convoy rounds end on arrival at the final door; the timer is only a safety net.
	if time_left <= 0.0 or (world.convoy_mover != null and world.convoy_mover.finished):
		finish_wave()

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
	if not GameStateMachine.transition_to(GameStateMachine.GameState.WAVE_ANNOUNCEMENT):
		return false
	GameStateService.current_wave += 1
	# Flags requested during the previous wave land here, before this wave's systems start.
	FeatureFlagService.apply_pending()
	world.telemetry.begin_wave(GameStateService.current_wave)
	world.build_zones.begin_wave()
	world.audio.play_cue("wave", world.player.position)
	announcement_left = ANNOUNCEMENT_TIME
	spawned_this_wave = 0
	elite_credit = 0.0
	seeker_credit = 0.0
	time_left = GameStateService.get_wave_duration(GameStateService.current_wave)
	remaining_spawns = GameStateService.get_wave_enemy_count(GameStateService.current_wave, float(world.difficulty_config["enemy_count_mult"]), ItemTrackingService.get_enemy_count_multiplier())
	var spawn_window := time_left
	if world.convoy_mode:
		# The round lasts as long as the route takes, so a faster core gets proportionally fewer enemies.
		world.start_convoy_round()
		var route_time := world.convoy_route.duration(PlayerStatsService.get_core_move_speed())
		remaining_spawns = maxi(1, roundi(remaining_spawns * clampf(route_time / time_left, .4, 2.0)))
		spawn_window = route_time
		time_left = route_time * GameConstants.CONVOY_SAFETY_FACTOR
	spawn_interval = spawn_window / maxf(float(remaining_spawns), 1.0)
	if world.core:
		spawn_interval /= maxf(DifficultyService.rule(world.difficulty_config, "spawn_rate_mult"), .1)
	spawn_clock = FIRST_SPAWN_DELAY
	world.message = EnemyVariants.notice_for_wave(GameStateService.current_wave)
	return true

func finish_wave() -> bool:
	if not world.is_combat():
		return false
	GameStateMachine.transition_to(GameStateMachine.GameState.WAVE_END)
	world.clear_field(true)
	var reward := EconomyService.get_wave_scrap_base(GameStateService.current_wave)
	world.collect_scrap(reward)
	world.message = "Wave secured · +%d scrap bonus" % reward
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
	return true

func _take_credit(rule_key: String) -> bool:
	var share := DifficultyService.rule(world.difficulty_config, rule_key)
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
	enemy.ignores_hero = seeker
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
