class_name SliceWorld
extends Node3D

## 3D migration proving ground. World events remain local, so no Node3D crosses the
## legacy Node2D event bus. Progression uses the existing run-owned services.
@export var auto_start: bool = true
@export var show_hud: bool = true
@export var wave_limit: int = 3
var session: RunSession
var combat: Combat3D = Combat3D.new()
var crowd: CrowdGrid3D = CrowdGrid3D.new()
var effects: CombatEffects3D
var difficulty_config: Dictionary
var spawned_this_wave: int = 0
var player: SliceActor
var camera: Camera3D
var hud: CanvasLayer
var enemies: Array[SliceActor] = []
var turrets: Array[SliceTurret] = []
var projectiles: Array[SliceProjectile] = []
var pickup_root: Node3D
var actor_root: Node3D
var carried_turret: SliceTurret
var carry_origin: Vector3
var paused: bool = false
var time_left: float = 0.0
var announcement_left: float = 0.0
var spawn_clock: float = 0.0
var spawn_interval: float = 1.0
var remaining_spawns: int = 0
var upgrade_count: int = 0
var message: String = ""

func _ready() -> void:
	# This slice has a fixed Easy preset; do not mutate the user's 2D difficulty.
	difficulty_config = DifficultyService.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY].duplicate()
	session = RunSession.new()
	add_child(session)
	actor_root = Node3D.new()
	actor_root.name = "Actors"
	add_child(actor_root)
	pickup_root = Node3D.new()
	pickup_root.name = "Scrap"
	add_child(pickup_root)
	effects = CombatEffects3D.new()
	effects.world = self
	add_child(effects)
	combat.explosion.connect(effects.show_explosion)
	combat.shock_pulse.connect(effects.show_shock)
	combat.actor_defeated.connect(_on_actor_defeated)
	_build_stage()
	if show_hud:
		hud = preload("res://scripts/three_d/slice_hud.gd").new()
		hud.world = self
		add_child(hud)
	if auto_start:
		start_run()

func start_run() -> void:
	_clear_actors()
	session.begin_run()
	GameStateMachine.force_transition(GameStateMachine.GameState.DIFFICULTY_SELECT)
	GameStateService.is_game_active = true
	GameStateService.current_wave = 0
	paused = false
	upgrade_count = 0
	message = ""
	player = SliceActor.new()
	player.world = self
	player.max_health = PlayerStatsService.get_player_max_health(float(difficulty_config["player_health_mult"]))
	player.health = player.max_health
	player.position = Vector3(0, 0, 1)
	actor_root.add_child(player)
	add_turret(Vector3(0, 0, -1))
	begin_next_wave()

func _clear_actors() -> void:
	carried_turret = null
	enemies.clear()
	turrets.clear()
	projectiles.clear()
	crowd.rebuild(enemies)
	effects.reset()
	for container: Node3D in [actor_root, pickup_root]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()

func is_combat() -> bool:
	return not paused and GameStateService.is_game_active and GameStateMachine.is_in_combat()

func _physics_process(delta: float) -> void:
	if paused or not GameStateService.is_game_active:
		return
	GameStateService.time_survived += delta
	if GameStateMachine.current_state == GameStateMachine.GameState.WAVE_ANNOUNCEMENT:
		announcement_left -= delta
		if announcement_left <= 0.0:
			GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
		return
	if not is_combat():
		return
	crowd.rebuild(enemies)
	time_left = maxf(0.0, time_left - delta)
	spawn_clock -= delta
	if remaining_spawns > 0 and spawn_clock <= 0.0:
		var type_id := "charger" if GameStateService.current_wave >= int(EnemyRegistry.TYPES["charger"]["min_wave"]) and spawned_this_wave % 4 == 0 else "basic"
		spawn_enemy(_spawn_position(), type_id)
		spawned_this_wave += 1
		remaining_spawns -= 1
		spawn_clock += spawn_interval
	if time_left <= 0.0:
		finish_wave()

func begin_next_wave() -> bool:
	if GameStateMachine.current_state not in [GameStateMachine.GameState.DIFFICULTY_SELECT, GameStateMachine.GameState.SHOP]:
		return false
	if not GameStateMachine.transition_to(GameStateMachine.GameState.WAVE_ANNOUNCEMENT):
		return false
	GameStateService.current_wave += 1
	announcement_left = 2.0
	spawned_this_wave = 0
	time_left = GameStateService.get_wave_duration(GameStateService.current_wave)
	remaining_spawns = GameStateService.get_wave_enemy_count(GameStateService.current_wave, float(difficulty_config["enemy_count_mult"]), 1.0)
	spawn_interval = time_left / maxf(float(remaining_spawns), 1.0)
	spawn_clock = .2
	message = ""
	if GameStateService.current_wave >= int(EnemyRegistry.TYPES["charger"]["min_wave"]):
		message = "Chargers incoming · dodge the amber lanes · plasma interrupts charges"
	return true

func finish_wave() -> bool:
	if not is_combat():
		return false
	GameStateMachine.transition_to(GameStateMachine.GameState.WAVE_END)
	for enemy in enemies:
		enemy.dead = true
		enemy.clear_transients()
		enemy.queue_free()
	enemies.clear()
	crowd.rebuild(enemies)
	effects.reset()
	player.clear_transients()
	for projectile in projectiles:
		projectile.release()
	for pickup: SlicePickup in pickup_root.get_children():
		pickup.collect()
	if is_instance_valid(carried_turret):
		carried_turret.carried = false
		carried_turret.position = carry_origin
		carried_turret = null
	var reward := EconomyService.get_wave_scrap_base(GameStateService.current_wave)
	collect_scrap(reward)
	message = "Wave secured · +%d scrap bonus" % reward
	if GameStateService.current_wave >= wave_limit:
		GameStateMachine.transition_to(GameStateMachine.GameState.VICTORY)
		GameStateService.is_game_active = false
	else:
		GameStateMachine.transition_to(GameStateMachine.GameState.SHOP)
	return true

func spawn_enemy(at: Vector3, type_id: String = "basic") -> SliceActor:
	var enemy := SliceActor.new()
	enemy.world = self
	enemy.is_enemy = true
	enemy.enemy_type = type_id
	var base := EnemyRegistry.get_stats_for_wave(type_id, maxi(GameStateService.current_wave, 1), difficulty_config)
	enemy.max_health = float(base["health"])
	enemy.health = enemy.max_health
	enemy.speed = float(base["speed"]) * SliceGeometry.METRES_PER_PIXEL
	enemy.contact_damage = float(base["contact_damage"])
	enemy.mass = float(base["mass"])
	enemy.scrap_value = int(base["scrap_value"])
	enemy.position = at
	actor_root.add_child(enemy)
	enemies.append(enemy)
	return enemy

func _spawn_position() -> Vector3:
	var edge := GameRandom.gameplay.randi_range(0, 3)
	var x := GameRandom.gameplay.randf_range(-9.1, 9.1)
	var z := GameRandom.gameplay.randf_range(-4.9, 4.9)
	match edge:
		0: x = -9.1
		1: x = 9.1
		2: z = -4.9
		3: z = 4.9
	return Vector3(x, 0, z)

func nearest_enemy(origin: Vector3, range_metres: float) -> SliceActor:
	return combat.select_target(origin, range_metres, enemies)

func fire(origin: Vector3, target: SliceActor, damage: float, speed: float) -> SliceProjectile:
	var spec := CombatShot3D.new()
	spec.damage = damage
	spec.speed = speed
	return fire_shot(origin, target, spec)

func fire_shot(origin: Vector3, target: SliceActor, spec: CombatShot3D) -> SliceProjectile:
	var shot: SliceProjectile = null
	for projectile in projectiles:
		if not projectile.active:
			shot = projectile
			break
	if not shot:
		shot = SliceProjectile.new()
		shot.world = self
		actor_root.add_child(shot)
		projectiles.append(shot)
	shot.acquire_shot(origin, target.position - origin, spec)
	return shot

func add_turret(at: Vector3, type_id: String = "normal") -> SliceTurret:
	var turret := SliceTurret.new()
	turret.world = self
	turret.turret_type = type_id
	turret.position = at
	actor_root.add_child(turret)
	turrets.append(turret)
	TurretStatsService.turret_counts[type_id] = int(TurretStatsService.turret_counts.get(type_id, 0)) + 1
	GameStateService.turrets_spawned = turrets.size()
	return turret

func collect_scrap(amount: int) -> void:
	var added := EconomyService.add_scrap_probabilistic(amount, 1.0)
	GameStateService.total_scrap += added

func _on_enemy_died(enemy: SliceActor) -> void:
	GameStateService.total_kills += 1
	var pickup := SlicePickup.new()
	pickup.world = self
	pickup.amount = enemy.scrap_value
	pickup.position = enemy.position
	pickup_root.add_child(pickup)
	enemies.erase(enemy)
	enemy.queue_free()

func _on_actor_defeated(actor: Node3D, _at: Vector3) -> void:
	var victim := actor as SliceActor
	if victim.is_enemy:
		_on_enemy_died(victim)
	else:
		_on_player_died(victim)

func _on_player_died(_actor: SliceActor) -> void:
	GameStateService.is_game_active = false
	GameStateMachine.transition_to(GameStateMachine.GameState.GAME_OVER)
	effects.reset()
	for enemy in enemies:
		enemy.clear_transients()
	for projectile in projectiles:
		projectile.release()

func turret_price(type_id: String = "normal") -> int:
	return EconomyService.calculate_turret_price(TurretRegistry.get_base_price(type_id), GameStateService.current_wave)

func purchase(kind: String) -> bool:
	if paused or GameStateMachine.current_state != GameStateMachine.GameState.SHOP:
		return false
	var price: int
	var spawn_at := Vector3.INF
	match kind:
		"turret", "plasma":
			price = turret_price("plasma" if kind == "plasma" else "normal")
			spawn_at = find_placement()
			if spawn_at == Vector3.INF:
				message = "No room for another turret."
				return false
		"damage": price = 10 + upgrade_count * 5
		"repair":
			price = 5
			if player.health >= player.max_health:
				return false
		_: return false
	if not EconomyService.deduct_scrap(price):
		message = "Need %d scrap." % price
		return false
	match kind:
		"turret", "plasma":
			add_turret(spawn_at, "plasma" if kind == "plasma" else "normal")
			EconomyService.turrets_purchased += 1
		"damage":
			upgrade_count += 1
			ModifierService.add_modifier({"id": "slice_damage_%d" % upgrade_count,
				"stat": "damage", "operation": "increase", "value": .2, "filter": {"turret_type": ["normal", "plasma"]}})
		"repair": player.health = minf(player.max_health, player.health + 10.0)
	message = "Upgrade installed."
	return true

func find_placement() -> Vector3:
	for z: float in [-1.0, 1.0, -3.0, 3.0]:
		for x: float in [0.0, -2.0, 2.0, -4.0, 4.0, -6.0, 6.0]:
			var candidate := Vector3(x, 0, z)
			if valid_placement(candidate):
				return candidate
	return Vector3.INF

func valid_placement(at: Vector3, excluding: SliceTurret = null) -> bool:
	if SliceGeometry.clamp_position(at, .55).distance_squared_to(at) > .0001:
		return false
	for turret in turrets:
		if turret != excluding and SliceGeometry.planar(turret.position - at).length() < 1.0:
			return false
	return true

func interact() -> bool:
	if not is_combat():
		return false
	if is_instance_valid(carried_turret):
		var forward := -player.visual.global_basis.z
		var at := SliceGeometry.planar(player.position + forward * .9)
		if not valid_placement(at, carried_turret):
			message = "Move clear of the edge or another turret."
			return false
		carried_turret.position = at
		carried_turret.carried = false
		carried_turret = null
		message = "Turret deployed."
		return true
	var nearest: SliceTurret = null
	var distance := 1.25
	for turret in turrets:
		var candidate_distance := turret.position.distance_to(player.position)
		if candidate_distance < distance:
			distance = candidate_distance
			nearest = turret
	if nearest:
		carried_turret = nearest
		carry_origin = nearest.position
		nearest.carried = true
		message = "Carrying turret · press E / A to place"
		return true
	return false

func toggle_pause() -> void:
	if GameStateService.is_game_active:
		paused = not paused

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE: toggle_pause()
			KEY_E: interact()
			KEY_R:
				if not GameStateService.is_game_active:
					start_run()
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START:
			toggle_pause()
		elif event.button_index == JOY_BUTTON_A:
			interact()

func _build_stage() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("08151e")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("92cbd4")
	settings.ambient_light_energy = .55
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_color = Color("d0eaff")
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	add_child(sun)
	var ground := StaticBody3D.new()
	ground.collision_layer = SliceGeometry.WORLD_LAYER
	ground.collision_mask = 0
	add_child(ground)
	SliceGeometry.box(ground, Vector3(19.8, .35, 11.4), Vector3(0, -.2, 0), SliceGeometry.material(Color("172c37")))
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(19.8, .35, 11.4)
	floor_shape.shape = floor_box
	floor_shape.position.y = -.2
	ground.add_child(floor_shape)
	var grid := SliceGeometry.material(Color("29434c"))
	for x in range(-9, 10):
		SliceGeometry.box(self, Vector3(.012, .005, 10.8), Vector3(x, -.018, 0), grid)
	for z in range(-5, 6):
		SliceGeometry.box(self, Vector3(19.2, .005, .012), Vector3(0, -.018, z), grid)
	var rim := SliceGeometry.material(Color("258e99"), true)
	for z: float in [-5.45, 5.45]:
		SliceGeometry.box(self, Vector3(19.5, .08, .06), Vector3(0, .02, z), rim)
	for x: float in [-9.65, 9.65]:
		SliceGeometry.box(self, Vector3(.06, .08, 10.9), Vector3(x, .02, 0), rim)
	var markings := SliceGeometry.material(Color("c48c48"))
	for x: float in [-9.25, 9.25]:
		for z in range(-4, 5):
			var stripe := SliceGeometry.box(self, Vector3(.16, .015, .4), Vector3(x, 0, z), markings)
			stripe.rotation.y = -.5
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0, 17, 13)
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	_resize_camera()
	get_viewport().size_changed.connect(_resize_camera)

func _resize_camera() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	camera.size = maxf(15.0, 23.0 / aspect)
