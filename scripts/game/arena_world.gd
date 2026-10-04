class_name ArenaWorld
extends Node3D

signal menu_requested()

## Native 3D arena. Combat events remain local; progression uses run-owned services.
@export var auto_start: bool = true
@export var show_hud: bool = true
@export var wave_limit: int = 6
var shop := ArenaShop.new()
var waves := WaveDirector.new()
var placement := TurretPlacement.new()
var stage: ArenaStage
var session: RunSession
var combat: Combat3D = Combat3D.new()
var crowd: CrowdGrid3D = CrowdGrid3D.new()
var effects: CombatEffects3D
var audio: GameAudio
var difficulty_config: Dictionary
var player: CombatActor
var camera: Camera3D
var camera_rig: CameraRig
var hud: CanvasLayer
var enemies: Array[CombatActor] = []
var turrets: Array[TurretActor] = []
var projectiles: Array[Projectile3D] = []
var pickup_root: Node3D
var actor_root: Node3D
var paused: bool = false
var message: String = ""

# Wave and carry state live in the helpers; these keep the long-standing ArenaWorld surface for the HUD, tools and tests.
var time_left: float:
	get: return waves.time_left
	set(value): waves.time_left = value
var announcement_left: float:
	get: return waves.announcement_left
	set(value): waves.announcement_left = value
var spawn_clock: float:
	get: return waves.spawn_clock
	set(value): waves.spawn_clock = value
var spawn_interval: float:
	get: return waves.spawn_interval
	set(value): waves.spawn_interval = value
var remaining_spawns: int:
	get: return waves.remaining_spawns
	set(value): waves.remaining_spawns = value
var spawned_this_wave: int:
	get: return waves.spawned_this_wave
	set(value): waves.spawned_this_wave = value
var carried_turret: TurretActor:
	get: return placement.carried
	set(value): placement.carried = value

func _ready() -> void:
	# The supported six-wave mode uses the Easy preset.
	difficulty_config = DifficultyService.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY].duplicate()
	session = RunSession.new()
	shop.world = self
	waves.world = self
	placement.world = self
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
	audio = GameAudio.new()
	audio.world = self
	add_child(audio)
	combat.hit_applied.connect(audio.on_hit)
	combat.hit_applied.connect(effects.show_hit)
	combat.explosion.connect(audio.on_explosion)
	combat.shock_pulse.connect(audio.on_shock)
	combat.explosion.connect(effects.show_explosion)
	combat.shock_pulse.connect(effects.show_shock)
	combat.chain_arc.connect(audio.on_arc)
	combat.chain_arc.connect(effects.show_arc)
	combat.actor_defeated.connect(_on_actor_defeated)
	stage = ArenaStage.new()
	stage.name = "Stage"
	add_child(stage)
	stage.build(self)
	camera = stage.camera
	camera_rig = stage.camera_rig
	if show_hud:
		hud = preload("res://scripts/game/game_hud.gd").new()
		hud.world = self
		add_child(hud)
	if auto_start:
		start_run()

func start_run() -> void:
	_clear_actors()
	session.begin_run()
	GameStateMachine.force_transition(GameStateMachine.GameState.IDLE)
	GameStateService.is_game_active = true
	GameStateService.current_wave = 0
	paused = false
	message = ""
	player = CombatActor.new()
	player.world = self
	player.max_health = PlayerStatsService.get_player_max_health(float(difficulty_config["player_health_mult"]))
	player.health = player.max_health
	player.position = Vector3(0, 0, 1)
	actor_root.add_child(player)
	var listener := AudioListener3D.new()
	player.add_child(listener)
	listener.make_current()
	add_turret(Vector3(0, 0, -1))
	camera_rig.snap()
	begin_next_wave()

func _clear_actors() -> void:
	audio.reset()
	placement.carried = null
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
	waves.tick(delta)

func begin_next_wave() -> bool:
	return waves.begin_next_wave()

func finish_wave() -> bool:
	return waves.finish_wave()

func spawn_enemy(at: Vector3, type_id: String = "basic") -> CombatActor:
	return waves.spawn_enemy(at, type_id)

func _spawn_position() -> Vector3:
	return waves.spawn_position()

func nearest_enemy(origin: Vector3, range_metres: float) -> CombatActor:
	return combat.select_target(origin, range_metres, enemies)

func fire(origin: Vector3, target: CombatActor, damage: float, speed: float) -> Projectile3D:
	var spec := CombatShot3D.new()
	spec.damage = damage
	spec.speed = speed
	return fire_shot(origin, target, spec)

func fire_shot(origin: Vector3, target: CombatActor, spec: CombatShot3D) -> Projectile3D:
	var shot: Projectile3D = null
	for projectile in projectiles:
		if not projectile.active:
			shot = projectile
			break
	if not shot:
		shot = Projectile3D.new()
		shot.world = self
		actor_root.add_child(shot)
		projectiles.append(shot)
	shot.acquire_shot(origin, target.position - origin, spec)
	audio.play_cue("plasma" if spec.damage_type == GameEnums.DamageType.PLASMA else "ion", origin)
	effects.show_muzzle(origin, spec.damage_type)
	return shot

func add_turret(at: Vector3, type_id: String = "normal") -> TurretActor:
	var turret := TurretActor.new()
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
	if is_combat():
		audio.play_cue("pickup", player.position)

func _on_enemy_died(enemy: CombatActor) -> void:
	GameStateService.total_kills += 1
	var pickup := ScrapPickup.new()
	pickup.world = self
	pickup.amount = enemy.scrap_value
	pickup.position = enemy.position
	pickup_root.add_child(pickup)
	enemies.erase(enemy)
	DeathDissolve.spawn(actor_root, enemy)
	enemy.queue_free()
	if enemy.explosion_radius > 0.0:
		_detonate(enemy)

## Boom bot blast: hurts the player and every other enemy in range (chains are allowed and finite).
func _detonate(source: CombatActor) -> void:
	var at := source.position
	var radius_squared := source.explosion_radius * source.explosion_radius
	var victims: Array[CombatActor] = []
	for other in enemies:
		if is_instance_valid(other) and not other.dead and WorldGeometry.planar(other.position - at).length_squared() <= radius_squared:
			victims.append(other)
	combat.explosion.emit(WorldGeometry.planar(at), source.explosion_radius)
	for victim in victims:
		combat.apply_hit(victim, CombatHit3D.new(source.explosion_damage, at))
	if WorldGeometry.planar(player.position - at).length_squared() <= radius_squared:
		combat.apply_hit(player, CombatHit3D.new(source.explosion_damage, at))

func _on_actor_defeated(actor: Node3D, _at: Vector3) -> void:
	var victim := actor as CombatActor
	if victim.is_enemy:
		_on_enemy_died(victim)
	else:
		_on_player_died(victim)

func _on_player_died(_actor: CombatActor) -> void:
	audio.reset()
	audio.play_cue("defeat", player.position)
	GameStateService.is_game_active = false
	GameStateMachine.transition_to(GameStateMachine.GameState.GAME_OVER)
	effects.reset()
	for enemy in enemies:
		enemy.clear_transients()
	for projectile in projectiles:
		projectile.release()

func turret_price(type_id: String = "normal") -> int:
	return EconomyService.calculate_turret_price(TurretRegistry.get_base_price(type_id), GameStateService.current_wave)

func repair() -> bool:
	if not shop.is_open() or player.health >= player.max_health or not EconomyService.deduct_scrap(GameConstants.REPAIR_COST):
		return false
	player.health = minf(player.max_health, player.health + GameConstants.REPAIR_HEAL_AMOUNT)
	audio.play_cue("purchase", player.position)
	message = "Hull repaired."
	return true

func find_placement() -> Vector3:
	return placement.find_placement()

func valid_placement(at: Vector3, excluding: TurretActor = null) -> bool:
	return placement.valid_placement(at, excluding)

func interact() -> bool:
	return placement.interact()

func toggle_pause() -> void:
	if GameStateService.is_game_active:
		paused = not paused

func request_menu() -> void:
	if not paused and GameStateService.is_game_active:
		return
	if menu_requested.has_connections():
		menu_requested.emit()
	else:
		get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE: toggle_pause()
			KEY_E: interact()
			KEY_R:
				if not GameStateService.is_game_active:
					start_run()
	if event is InputEventMouseButton and event.pressed and camera_rig:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_rig.zoom_steps(1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_rig.zoom_steps(-1.0)
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START:
			toggle_pause()
		elif event.button_index == JOY_BUTTON_A:
			interact()
