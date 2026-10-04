class_name WaveDirector
extends RefCounted

## Wave lifecycle for one run: announcement, spawn schedule, timer and wave-end resolution.
## `ArenaWorld` owns the actors and exposes this state through forwarding properties.
const ANNOUNCEMENT_TIME: float = 2.0
const FIRST_SPAWN_DELAY: float = .2
var world: ArenaWorld
var spawned_this_wave: int = 0
var remaining_spawns: int = 0
var spawn_clock: float = 0.0
var spawn_interval: float = 1.0
var time_left: float = 0.0
var announcement_left: float = 0.0

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
	time_left = maxf(0.0, time_left - delta)
	spawn_clock -= delta
	if remaining_spawns > 0 and spawn_clock <= 0.0:
		var type_id := EnemyVariants.pick_type(GameStateService.current_wave, spawned_this_wave)
		spawn_enemy(spawn_position(), type_id)
		spawned_this_wave += 1
		remaining_spawns -= 1
		spawn_clock += spawn_interval
	if time_left <= 0.0:
		finish_wave()

func begin_next_wave() -> bool:
	if GameStateMachine.current_state not in [GameStateMachine.GameState.IDLE, GameStateMachine.GameState.SHOP]:
		return false
	if not GameStateMachine.transition_to(GameStateMachine.GameState.WAVE_ANNOUNCEMENT):
		return false
	GameStateService.current_wave += 1
	world.audio.play_cue("wave", world.player.position)
	announcement_left = ANNOUNCEMENT_TIME
	spawned_this_wave = 0
	time_left = GameStateService.get_wave_duration(GameStateService.current_wave)
	remaining_spawns = GameStateService.get_wave_enemy_count(GameStateService.current_wave, float(world.difficulty_config["enemy_count_mult"]), 1.0)
	spawn_interval = time_left / maxf(float(remaining_spawns), 1.0)
	spawn_clock = FIRST_SPAWN_DELAY
	world.message = EnemyVariants.notice_for_wave(GameStateService.current_wave)
	return true

func finish_wave() -> bool:
	if not world.is_combat():
		return false
	GameStateMachine.transition_to(GameStateMachine.GameState.WAVE_END)
	for enemy in world.enemies:
		enemy.dead = true
		enemy.clear_transients()
		enemy.queue_free()
	world.enemies.clear()
	world.crowd.rebuild(world.enemies)
	world.effects.reset()
	world.player.clear_transients()
	for projectile in world.projectiles:
		projectile.release()
	for pickup: ScrapPickup in world.pickup_root.get_children():
		pickup.collect()
	world.placement.drop_carried()
	var reward := EconomyService.get_wave_scrap_base(GameStateService.current_wave)
	world.collect_scrap(reward)
	world.audio.reset()
	world.message = "Wave secured · +%d scrap bonus" % reward
	if GameStateService.current_wave >= world.wave_limit:
		world.audio.play_cue("victory", world.player.position)
		GameStateMachine.transition_to(GameStateMachine.GameState.VICTORY)
		GameStateService.is_game_active = false
	else:
		GameStateMachine.transition_to(GameStateMachine.GameState.SHOP)
		world.shop.open()
		world.audio.play_cue("wave", world.player.position)
	return true

func spawn_enemy(at: Vector3, type_id: String = "basic") -> CombatActor:
	var enemy := CombatActor.new()
	enemy.world = world
	enemy.is_enemy = true
	enemy.enemy_type = type_id
	var base := EnemyRegistry.get_stats_for_wave(type_id, maxi(GameStateService.current_wave, 1), world.difficulty_config)
	enemy.max_health = float(base["health"])
	enemy.health = enemy.max_health
	enemy.speed = float(base["speed"]) * WorldGeometry.METRES_PER_PIXEL
	enemy.contact_damage = float(base["contact_damage"])
	enemy.mass = float(base["mass"])
	enemy.scrap_value = int(base["scrap_value"])
	enemy.body_scale = EnemyVariants.body_scale(type_id)
	enemy.explosion_radius = float(base.get("explosion_radius", 0.0)) * WorldGeometry.METRES_PER_PIXEL
	enemy.explosion_damage = float(base.get("explosion_damage", 0.0))
	enemy.position = at
	world.actor_root.add_child(enemy)
	world.enemies.append(enemy)
	return enemy

## Enemies appear on a ring just outside the default-zoom view around the player, clamped to the arena, so they
## reach the fight quickly on the large map. A spot clamped back into view is retried a few times.
func spawn_position() -> Vector3:
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
