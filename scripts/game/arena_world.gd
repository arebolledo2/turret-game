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
var shop := ArenaShop.new()
var waves := WaveDirector.new()
var salvage := WaveSalvage.new()
## Scrap that does not come from a kill (S5, the Scrap Press); see `ScrapIncome`.
var scrap_income := ScrapIncome.new()
## Headless tools skip presentation; tests can explicitly enable and advance it.
var present_wave_rewards: bool = DisplayServer.get_name() != "headless"
var chest_rewards: ChestRewardScreen
var reward_presentation: SalvagePresentation
var drops := TechDropDirector.new()
var build_zones := BuildZoneDirector.new()
var blasts := BlastEffects.new()
var dev := DevCommands.new()
## This run's terrain (null when the `terrain_zones` flag is off). Chosen once per run and fixed for every wave.
var terrain: TerrainZones
var spawn_zones: SpawnZones
var preparation: PreparationPhase
var placement := TurretPlacement.new()
var launcher := ProjectileLauncher.new()
var roster := TurretRoster.new()
var outcome := RunOutcome.new()
var input := ArenaInput.new()
var stage: ArenaStage
var session: RunSession
var item_effects := ItemCombatEffects.new()
var buff_overlay: BuffOverlay
var combat: Combat3D = Combat3D.new()
var crowd: CrowdGrid3D = CrowdGrid3D.new()
var effects: CombatEffects3D
## The Decoy taunts enemies answer (S1); see `TauntField`.
var taunts := TauntField.new()
## Temporary enemy-only floor patches laid by turrets (Quake fissures); see `GroundZones`.
var ground_zones: GroundZones
## Mines and limpets turrets leave on the floor (engine piece S8); see `Deployables`.
var deployables: Deployables
## The drones turrets send up (engine piece S10); see `Drones`.
var drones: Drones
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
var player: HeroActor
var camera: Camera3D
var camera_rig: CameraRig
var playfield: PlayfieldView
var hud: CanvasLayer
var enemies: Array[CombatActor] = []
## Enemies currently telegraphing an attack (brain state "warning" or charger windup). Lets `EnemyBrain._warning_slot`
## check a handful of actors instead of scanning every enemy.
var warning_actors: Dictionary = {}
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
	item_effects.world = self
	buff_overlay = BuffOverlay.new()
	buff_overlay.world = self
	add_child(buff_overlay)
	_configure_run()
	_create_roots()
	_create_combat_presentation()
	_create_stage_and_hud()
	spawn_zones = SpawnZones.new()
	spawn_zones.world = self
	add_child(spawn_zones)
	preparation = PreparationPhase.new()
	preparation.world = self
	add_child(preparation)
	if auto_start:
		start_run()

## Resolves the run configuration into mode, difficulty and flag state, and binds the helpers that need this world.
func _configure_run() -> void:
	if not run_config:
		run_config = RunConfig.new()
	run_config.sanitize()
	wave_limit = run_config.wave_limit
	if not run_config.flag_preset.is_empty():
		FeatureFlagService.apply_preset(run_config.flag_preset)
	difficulty_config = run_config.difficulty_config()
	convoy_mode = run_config.mode == RunConfig.MODE_CONVOY and FeatureFlagService.is_enabled(FeatureFlagService.MODE_CONVOY)
	core_mode = convoy_mode or (run_config.mode == RunConfig.MODE_CORE and FeatureFlagService.is_enabled(FeatureFlagService.MODE_PROTECT_CORE))
	session = RunSession.new()
	shop.world = self
	waves.world = self
	salvage.world = self
	scrap_income.world = self
	drops.world = self
	build_zones.world = self
	blasts.world = self
	dev.world = self
	placement.world = self
	launcher.world = self
	roster.world = self
	outcome.world = self
	input.world = self
	add_child(session)

## Roots for interpolated actors and pickups, plus the convoy route overlay.
func _create_roots() -> void:
	# Interpolate physics-driven actors; scenery/UI/idle effects keep their own clocks.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	actor_root = Node3D.new()
	actor_root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	actor_root.name = "Actors"
	add_child(actor_root)
	pickup_root = Node3D.new()
	pickup_root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	pickup_root.name = "Scrap"
	add_child(pickup_root)
	if convoy_mode:
		var overlay := RouteOverlay.new()
		overlay.name = "RouteOverlay"
		overlay.world = self
		add_child(overlay)

## Effects, audio and reward screens, and the combat signals that drive them.
func _create_combat_presentation() -> void:
	effects = CombatEffects3D.new()
	effects.world = self
	add_child(effects)
	ground_zones = GroundZones.new()
	ground_zones.name = "GroundZones"
	ground_zones.world = self
	add_child(ground_zones)
	deployables = Deployables.new()
	deployables.name = "Deployables"
	deployables.world = self
	add_child(deployables)
	drones = Drones.new()
	drones.name = "Drones"
	drones.world = self
	add_child(drones)
	audio = GameAudio.new()
	audio.world = self
	add_child(audio)
	combat.hit_applied.connect(audio.on_hit)
	combat.hit_applied.connect(effects.show_hit)
	combat.explosion.connect(audio.on_explosion)
	combat.shock_pulse.connect(audio.on_shock)
	combat.explosion.connect(effects.show_explosion)
	combat.explosion.connect(func(at: Vector3, radius: float) -> void: stage.floor_decals.add_scorch(at, radius))
	combat.shock_pulse.connect(effects.show_shock)
	combat.chain_arc.connect(audio.on_arc)
	combat.chain_arc.connect(effects.show_arc)
	combat.actor_defeated.connect(_on_actor_defeated)
	combat.hit_applied.connect(_record_hit)
	reward_presentation = SalvagePresentation.new()
	reward_presentation.world = self
	reward_presentation.finished.connect(waves.complete_wave)
	add_child(reward_presentation)
	chest_rewards = ChestRewardScreen.new()
	chest_rewards.world = self
	add_child(chest_rewards)

func _create_stage_and_hud() -> void:
	stage = ArenaStage.new()
	stage.name = "Stage"
	add_child(stage)
	stage.build(self)
	camera = stage.camera
	camera_rig = stage.camera_rig
	if show_hud:
		playfield = PlayfieldView.new()
		playfield.world = self
		add_child(playfield)
		hud = preload("res://scripts/game/game_hud.gd").new()
		hud.world = self
		add_child(hud)
		var health_overlay := EnemyHealthOverlay.new()
		health_overlay.world = self
		hud.add_child(health_overlay)
	if FeatureFlagService.dev_panel_available():
		dev_panel = DevPanel.new()
		dev_panel.world = self
		add_child(dev_panel)

## Floor theme for a run without terrain zones: the named layout's, else one picked from a stream derived from (not
## advancing) the gameplay RNG, so combat and shop rolls are undisturbed and seeded runs still repeat.
func _zoneless_floor_theme() -> String:
	if run_config.layout_id != "":
		return ArenaLayouts.get_layout(run_config.layout_id).floor_theme
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(GameRandom.gameplay.state)
	return WorldGeometry.FLOOR_THEMES[rng.randi_range(0, WorldGeometry.FLOOR_THEMES.size() - 1)]

func start_run() -> void:
	DeathShatter.warm_up()
	_clear_actors()
	stage.floor_decals.clear_scorches()
	session.begin_run()
	# Derive a separate stream without advancing combat/shop randomness.
	salvage.reset(GameRandom.gameplay.state)
	scrap_income.reset(GameRandom.gameplay.state)
	telemetry.begin_run()
	FeatureFlagService.clear_pending()
	roster.reset()
	GameStateMachine.force_transition(GameStateMachine.GameState.IDLE)
	GameStateService.is_game_active = true
	GameStateService.current_wave = 0
	paused = false
	message = ""
	player = HeroActor.new()
	player.world = self
	player.max_health = PlayerStatsService.get_player_max_health(float(difficulty_config["player_health_mult"]))
	player.health = player.max_health
	player.position = Vector3(0, 0, 1)
	var turret_start := Vector3(0, 0, -1)
	defeat_reason = ""
	if core_mode:
		core = CoreObjective.new()
		core.world = self
		core.name = "Core"
		actor_root.add_child(core)
		core.reset(core_max_health())
		player.position = Vector3(0, 0, GameConstants.CORE_START_OFFSET)
		turret_start = Vector3(0, 0, -GameConstants.CORE_START_OFFSET)
	if FeatureFlagService.is_enabled(FeatureFlagService.TERRAIN_ZONES):
		var layout := ArenaLayouts.get_layout(run_config.layout_id) if run_config.layout_id != "" else ArenaLayouts.random_layout(GameRandom.gameplay)
		stage.set_floor_theme(layout.floor_theme)
		stage.set_space_theme(run_config.space_theme if run_config.space_theme != "" else layout.space_theme)
		terrain = TerrainZones.new(layout)
		terrain.build_visuals(actor_root)
	else:
		var floor_theme := _zoneless_floor_theme()
		stage.set_floor_theme(floor_theme)
		stage.set_space_theme(run_config.space_theme if run_config.space_theme != "" else ArenaLayouts.space_for_floor(floor_theme))
	if convoy_mode:
		# A dedicated seed keeps every route reproducible without disturbing the shop and spawn rolls.
		_convoy_seed = GameRandom.gameplay.randi()
		plan_convoy_route(1)
		core.position = convoy_route.doors[0]
		var inward := -WorldGeometry.planar(core.position).normalized()
		player.position = core.position + inward * 2.2
		turret_start = core.position + inward * 3.4
	actor_root.add_child(player)
	player.reset_physics_interpolation()
	var listener := AudioListener3D.new()
	player.add_child(listener)
	listener.make_current()
	add_turret(turret_start, str(run_config.hero.starting_turret), true)
	camera_rig.snap()
	begin_next_wave()

func _clear_actors() -> void:
	preparation.end()
	preparation.reset_layout()
	waves.clear_spawn_warnings()
	item_effects.reset()
	reward_presentation.cancel()
	chest_rewards.cancel()
	drops.pending_items.clear()
	audio.reset()
	core = null
	convoy_route = null
	convoy_mover = null
	terrain = null
	drops.reset()
	build_zones.reset_run()
	placement.carried = null
	enemies.clear()
	turrets.clear()
	taunts.clear()
	projectiles.clear()
	crowd.rebuild(enemies)
	effects.reset()
	ground_zones.clear()
	deployables.clear()
	drones.clear()
	for container: Node3D in [actor_root, pickup_root]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()

## Ends the fight on the field: removes enemies, projectiles, effects and drops, stops audio and drops any carried
## turret. Scrap pickups are banked when `bank_pickups` is set, otherwise discarded.
func clear_field(bank_pickups: bool, return_carried: bool = true) -> void:
	waves.clear_spawn_warnings()
	item_effects.clear_wave()
	for node in get_tree().get_nodes_in_group("hostile_ordnance"):
		if node.world == self:
			node.queue_free()
	# Progression awards are committed explicitly by WaveDirector, never by cleanup.
	bank_pickups = bank_pickups and not session.state.turret_progression_enabled
	for enemy in enemies:
		enemy.dead = true
		enemy.clear_transients()
		enemy.queue_free()
	enemies.clear()
	crowd.rebuild(enemies)
	effects.reset()
	ground_zones.clear()
	deployables.clear()
	drones.clear()
	salvage.discard_direct()
	drops.reset()
	build_zones.reset()
	player.clear_transients()
	for projectile in projectiles:
		projectile.release()
	if bank_pickups:
		var leftover := 0
		for pickup: ScrapPickup in pickup_root.get_children():
			if not pickup.collected and not pickup.is_queued_for_deletion():
				leftover += pickup.amount
		build_zones.note_leftover(leftover)
	for pickup: ScrapPickup in pickup_root.get_children():
		if bank_pickups:
			pickup.collect()
		else:
			pickup.queue_free()
	if return_carried:
		placement.drop_carried()
	audio.reset()

func mark_warning(actor: CombatActor, warning: bool) -> void:
	if warning:
		warning_actors[actor] = true
	else:
		warning_actors.erase(actor)

## Core runs that use the escort rosters; convoy rounds keep the standard ones.
func escort_mode() -> bool:
	return core_mode and not convoy_mode

func is_combat() -> bool:
	return not paused and GameStateService.is_game_active and GameStateMachine.is_in_combat()

func _physics_process(delta: float) -> void:
	if paused or not GameStateService.is_game_active or GameStateMachine.current_state == GameStateMachine.GameState.PREPARATION:
		return
	item_effects.tick(delta)
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
	core.position = convoy_mover.position
	core.reset_physics_interpolation()

func spawn_enemy(at: Vector3, type_id: String = "basic") -> EnemyActor:
	return waves.spawn_enemy(at, type_id)

func nearest_enemy(origin: Vector3, range_metres: float) -> CombatActor:
	return combat.select_target(origin, range_metres, enemies)

func fire(origin: Vector3, target: CombatActor, damage: float, speed: float) -> Projectile3D:
	return launcher.fire(origin, target, damage, speed)

func fire_shot(origin: Vector3, target: CombatActor, spec: CombatShot3D) -> Projectile3D:
	return launcher.fire_shot(origin, target, spec)

func fire_direction(origin: Vector3, heading: Vector3, spec: CombatShot3D) -> Projectile3D:
	return launcher.fire_direction(origin, heading, spec)

## `level` and `form` place a turret that arrives already grown (a shop purchase); `value_basis` is what its level 1 self
## cost, or -1 for the type's base price.
func add_turret(at: Vector3, type_id: String = "normal", starting: bool = false, level: int = 1, form: String = "", value_basis: int = -1) -> TurretActor:
	return roster.add(at, type_id, starting, level, form, value_basis)

## Takes a turret out of the run (a sale).
func remove_turret(turret: TurretActor) -> void:
	roster.remove(turret)

## Lays a scrap pickup on the floor (kills and the Scrap Press).
func spawn_scrap_pickup(at: Vector3, amount: int) -> ScrapPickup:
	var pickup := ScrapPickup.new()
	pickup.world = self
	pickup.amount = amount
	pickup.position = at
	pickup_root.add_child(pickup)
	pickup.reset_physics_interpolation()
	return pickup

func collect_scrap(amount: int) -> void:
	var added := EconomyService.add_scrap_probabilistic(amount, ItemTrackingService.get_scrap_earn_multiplier())
	telemetry.record_scrap_earned(added)
	GameStateService.lifetime_scrap += added
	award_hero_xp(roundi(amount * GameConstants.HERO_XP_PER_SCRAP))
	if is_combat():
		audio.play_cue("pickup", player.position)

## Collected scrap feeds the hero's own growth (uncollected scrap still goes to the turrets at wave end).
func award_hero_xp(amount: int) -> void:
	if not session.state.turret_progression_enabled or not is_instance_valid(player):
		return
	var change: Dictionary = PlayerStatsService.state.hero_progression.award(amount)
	if change.leveled:
		_refresh_hero_growth(true)
		Events.hero_leveled.emit(int(change.after.level))

## Takes one of the hero's evolutions; only while the shop is open, like a turret's.
func evolve_hero(form_id: String) -> bool:
	if not shop.is_open() or not PlayerStatsService.state.hero_progression.evolve(form_id):
		return false
	_refresh_hero_growth(false)
	player.apply_form_look(form_id)
	Events.hero_evolved.emit(form_id)
	return true

## Re-derives max health after a level or form change; the health gained is also healed.
func _refresh_hero_growth(heal_gain: bool) -> void:
	var previous := player.max_health
	player.max_health = maxf(1.0, PlayerStatsService.get_player_max_health(float(difficulty_config["player_health_mult"])))
	if heal_gain:
		player.health += maxf(0.0, player.max_health - previous)
	player.health = minf(player.health, player.max_health)

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
	if not enemy.enemy_type in EnemyEcology.SUMMONS:
		GameStateService.total_kills += 1
	if EnemyEcology.is_boss(enemy.enemy_type):
		drops.reward_boss(enemy.enemy_type)
	if enemy.scrap_value > 0:
		spawn_scrap_pickup(enemy.position, enemy.scrap_value)
	enemies.erase(enemy)
	if not DeathShatter.spawn(actor_root, enemy):
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
	outcome.end_in_defeat("HULL LOST" if core_mode else "")

func core_max_health() -> float:
	return outcome.core_max_health()

## Enemy contact and blasts land here. Ends the run when the core falls.
func damage_core(amount: float) -> void:
	outcome.damage_core(amount)

func _end_run_in_defeat(reason: String) -> void:
	outcome.end_in_defeat(reason)

func turret_price(type_id: String = "normal") -> int:
	return EconomyService.calculate_turret_price(TurretRegistry.get_base_price(type_id), GameStateService.current_wave)

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
	input.handle(event)

## Between waves the hero and the core are fully healed for free.
func heal_between_waves() -> void:
	outcome.heal_between_waves()
