class_name ArenaWorld
extends Node3D

signal menu_requested()

## Native 3D arena. Combat events remain local; progression uses run-owned services.
@export var auto_start: bool = true
@export var show_hud: bool = true
## Chosen by the start screen or tools before the node enters the tree; defaults when left null.
var run_config: RunConfig
var wave_limit: int = GameConstants.RUN_DEFAULT_WAVE_LIMIT
## Developer state (dev panel). God mode makes the player ignore damage.
var god_mode: bool = false
## True while the dev panel is open; the panel pauses the run and hides the HUD overlay panel.
var dev_menu_open: bool = false
var telemetry: RunTelemetry = RunTelemetry.new()
var dev_panel: DevPanel
var _next_turret_id: int = 1
var shop := ArenaShop.new()
var waves := WaveDirector.new()
var drops := TechDropDirector.new()
var blasts := BlastEffects.new()
var dev := DevCommands.new()
## This run's terrain (null when the `terrain_zones` flag is off). Chosen once per run and fixed for every wave.
var terrain: TerrainZones
var placement := TurretPlacement.new()
var stage: ArenaStage
var session: RunSession
var combat: Combat3D = Combat3D.new()
var crowd: CrowdGrid3D = CrowdGrid3D.new()
var effects: CombatEffects3D
var audio: GameAudio
var difficulty_config: Dictionary
## The thing enemies try to destroy in core mode; null in survive mode.
var core: CoreObjective
## True when this run protects a core (mode chosen and the `mode_protect_core` flag on).
var core_mode: bool = false
## True in convoy mode (a core run whose core drives door to door; needs the `mode_convoy` flag).
var convoy_mode: bool = false
## The current round's route (the next round's while the shop is open) and the mover driving the core along it.
var convoy_route: ConvoyRoute
var convoy_mover: ConvoyMover
var _convoy_seed: int = 0
## Why the run ended in defeat ("" while running or after a victory); shown on the end screen.
var defeat_reason: String = ""
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

# Wave state lives in `waves`; the carried turret is exposed here for the player and HUD.
var carried_turret: TurretActor:
	get: return placement.carried
	set(value): placement.carried = value

func _ready() -> void:
	if not run_config:
		run_config = RunConfig.new()
	run_config.sanitize()
	wave_limit = run_config.wave_limit
	if not run_config.flag_preset.is_empty():
		FeatureFlagService.apply_preset(run_config.flag_preset)
	difficulty_config = run_config.difficulty_config()
	if not FeatureFlagService.is_enabled(FeatureFlagService.DIFFICULTY_RULES):
		difficulty_config = DifficultyService.without_rules(difficulty_config)
	convoy_mode = run_config.mode == RunConfig.MODE_CONVOY and FeatureFlagService.is_enabled(FeatureFlagService.MODE_CONVOY)
	core_mode = convoy_mode or (run_config.mode == RunConfig.MODE_CORE and FeatureFlagService.is_enabled(FeatureFlagService.MODE_PROTECT_CORE))
	session = RunSession.new()
	shop.world = self
	waves.world = self
	drops.world = self
	blasts.world = self
	dev.world = self
	placement.world = self
	add_child(session)
	actor_root = Node3D.new()
	actor_root.name = "Actors"
	add_child(actor_root)
	pickup_root = Node3D.new()
	pickup_root.name = "Scrap"
	add_child(pickup_root)
	if convoy_mode:
		var overlay := RouteOverlay.new()
		overlay.name = "RouteOverlay"
		overlay.world = self
		add_child(overlay)
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
	combat.hit_applied.connect(_record_hit)
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
	if FeatureFlagService.dev_panel_available():
		dev_panel = DevPanel.new()
		dev_panel.world = self
		add_child(dev_panel)
	if auto_start:
		start_run()

func start_run() -> void:
	_clear_actors()
	session.begin_run()
	telemetry.begin_run()
	FeatureFlagService.clear_pending()
	_next_turret_id = 1
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
	var turret_start := Vector3(0, 0, -1)
	defeat_reason = ""
	if core_mode:
		core = CoreObjective.new()
		core.name = "Core"
		actor_root.add_child(core)
		core.reset(core_max_health())
		player.position = Vector3(0, 0, GameConstants.CORE_START_OFFSET)
		turret_start = Vector3(0, 0, -GameConstants.CORE_START_OFFSET)
	if FeatureFlagService.is_enabled(FeatureFlagService.TERRAIN_ZONES):
		var layout := ArenaLayouts.get_layout(run_config.layout_id) if run_config.layout_id != "" else ArenaLayouts.random_layout(GameRandom.gameplay)
		terrain = TerrainZones.new(layout)
		terrain.build_visuals(actor_root)
	if convoy_mode:
		# A dedicated seed keeps every route reproducible without disturbing the shop and spawn rolls.
		_convoy_seed = GameRandom.gameplay.randi()
		plan_convoy_route(1)
	actor_root.add_child(player)
	var listener := AudioListener3D.new()
	player.add_child(listener)
	listener.make_current()
	add_turret(turret_start)
	camera_rig.snap()
	begin_next_wave()

func _clear_actors() -> void:
	audio.reset()
	core = null
	convoy_route = null
	convoy_mover = null
	terrain = null
	drops.reset()
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

## Ends the fight on the field: removes enemies, projectiles, effects and drops, stops audio and drops any carried
## turret. Scrap pickups are banked when `bank_pickups` is set, otherwise discarded.
func clear_field(bank_pickups: bool) -> void:
	for enemy in enemies:
		enemy.dead = true
		enemy.clear_transients()
		enemy.queue_free()
	enemies.clear()
	crowd.rebuild(enemies)
	effects.reset()
	drops.reset()
	player.clear_transients()
	for projectile in projectiles:
		projectile.release()
	for pickup: ScrapPickup in pickup_root.get_children():
		if bank_pickups:
			pickup.collect()
		else:
			pickup.queue_free()
	placement.drop_carried()
	audio.reset()

func is_combat() -> bool:
	return not paused and GameStateService.is_game_active and GameStateMachine.is_in_combat()

func _physics_process(delta: float) -> void:
	if paused or not GameStateService.is_game_active:
		return
	waves.tick(delta)
	if convoy_mover and core and is_combat():
		core.position = convoy_mover.advance(delta, PlayerStatsService.get_core_move_speed())
	placement.update_preview()
	if terrain:
		terrain.update_frame(player.position if is_instance_valid(player) else Vector3.ZERO,
			FeatureFlagService.dev_panel_available() and FeatureFlagService.is_enabled(FeatureFlagService.DEBUG_ZONES))

func begin_next_wave() -> bool:
	return waves.begin_next_wave()

func finish_wave() -> bool:
	return waves.finish_wave()

## Generates the route `wave` will drive, starting from wherever the core is now, so the shop and overlay can preview it.
func plan_convoy_route(wave: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_convoy_seed, wave])
	convoy_route = ConvoyRoute.generate(rng, wave, core.position if core else Vector3.ZERO)

## Hands the planned route to a fresh mover at the start of a round.
func start_convoy_round() -> void:
	if not convoy_route or (convoy_mover and convoy_mover.route == convoy_route):
		plan_convoy_route(GameStateService.current_wave)
	convoy_mover = ConvoyMover.new()
	convoy_mover.start(convoy_route)

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
	turret.turret_id = _next_turret_id
	_next_turret_id += 1
	turret.position = at
	actor_root.add_child(turret)
	turrets.append(turret)
	TurretStatsService.turret_counts[type_id] = int(TurretStatsService.turret_counts.get(type_id, 0)) + 1
	GameStateService.turrets_spawned = turrets.size()
	return turret

func collect_scrap(amount: int) -> void:
	var added := EconomyService.add_scrap_probabilistic(amount, ItemTrackingService.get_scrap_earn_multiplier())
	telemetry.record_scrap_earned(added)
	GameStateService.lifetime_scrap += added
	if is_combat():
		audio.play_cue("pickup", player.position)

## Feeds telemetry only; never changes combat results.
func _record_hit(target: Node3D, hit: CombatHit3D, applied: float) -> void:
	var victim := target as CombatActor
	if not victim:
		return
	if victim.is_enemy and victim.dead:
		blasts.reactor_overload(victim, hit)
	if not victim.is_enemy:
		telemetry.record_hull_lost(applied)
	elif victim.dead and not victim.stationary:
		var label := ""
		for turret in turrets:
			if turret.turret_id == hit.source_id and hit.source_id != 0:
				label = "%d:%s" % [turret.turret_id, turret.turret_type]
				break
		telemetry.record_kill(label)

func _on_enemy_died(enemy: CombatActor) -> void:
	if enemy.stationary:
		enemies.erase(enemy)
		drops.reward(enemy)
		enemy.queue_free()
		return
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
		blasts.detonate(enemy)

func _on_actor_defeated(actor: Node3D, _at: Vector3) -> void:
	var victim := actor as CombatActor
	if victim.is_enemy:
		_on_enemy_died(victim)
	else:
		_on_player_died(victim)

func _on_player_died(_actor: CombatActor) -> void:
	_end_run_in_defeat("HULL LOST" if core_mode else "")

func core_max_health() -> float:
	return GameConstants.PLAYER_BASE_MAX_HEALTH * GameConstants.CORE_HEALTH_MULT * float(difficulty_config.get("core_health_mult", 1.0))

## Enemy contact and blasts land here. Ends the run when the core falls.
func damage_core(amount: float) -> void:
	if not core or core.dead or god_mode or not is_combat():
		return
	if core.take_hit(amount) > 0.0:
		audio.play_cue("hull", core.position)
		if core.dead:
			_end_run_in_defeat("CORE DESTROYED")

func repair_core() -> bool:
	if not core or not shop.is_open() or core.dead or core.health >= core.max_health or not EconomyService.deduct_scrap(GameConstants.REPAIR_COST):
		return false
	telemetry.record_spend("repair_core", GameConstants.REPAIR_COST)
	core.repair(GameConstants.REPAIR_HEAL_AMOUNT)
	audio.play_cue("purchase", player.position)
	message = "Core repaired."
	return true

func _end_run_in_defeat(reason: String) -> void:
	defeat_reason = reason
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
	telemetry.record_spend("repair", GameConstants.REPAIR_COST)
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

## Turret range rings, toggled with the `toggle_range` action (Y / Tab). Stays on between waves until toggled again.
var show_ranges: bool = false

func toggle_ranges() -> void:
	if not FeatureFlagService.is_enabled(FeatureFlagService.RANGE_OVERLAY):
		return
	show_ranges = not show_ranges
	message = "Turret ranges %s" % ("shown" if show_ranges else "hidden")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_range") and not event.is_echo() and GameStateService.is_game_active:
		toggle_ranges()
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
