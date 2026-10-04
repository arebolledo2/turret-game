class_name ArenaWorld
extends Node3D

signal menu_requested()

## Native 3D arena. Combat events remain local; progression uses run-owned services.
@export var auto_start: bool = true
@export var show_hud: bool = true
@export var wave_limit: int = 6
var shop := ArenaShop.new()
var session: RunSession
var combat: Combat3D = Combat3D.new()
var crowd: CrowdGrid3D = CrowdGrid3D.new()
var effects: CombatEffects3D
var audio: GameAudio
var difficulty_config: Dictionary
var spawned_this_wave: int = 0
var player: CombatActor
var camera: Camera3D
var camera_rig: CameraRig
var hud: CanvasLayer
var enemies: Array[CombatActor] = []
var turrets: Array[TurretActor] = []
var projectiles: Array[Projectile3D] = []
var pickup_root: Node3D
var actor_root: Node3D
var carried_turret: TurretActor
var carry_origin: Vector3
var paused: bool = false
var time_left: float = 0.0
var announcement_left: float = 0.0
var spawn_clock: float = 0.0
var spawn_interval: float = 1.0
var remaining_spawns: int = 0
var message: String = ""

func _ready() -> void:
	# The supported six-wave mode uses the Easy preset.
	difficulty_config = DifficultyService.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY].duplicate()
	session = RunSession.new()
	shop.world = self
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
	_build_stage()
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
		var type_id := EnemyVariants.pick_type(GameStateService.current_wave, spawned_this_wave)
		spawn_enemy(_spawn_position(), type_id)
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
	audio.play_cue("wave", player.position)
	announcement_left = 2.0
	spawned_this_wave = 0
	time_left = GameStateService.get_wave_duration(GameStateService.current_wave)
	remaining_spawns = GameStateService.get_wave_enemy_count(GameStateService.current_wave, float(difficulty_config["enemy_count_mult"]), 1.0)
	spawn_interval = time_left / maxf(float(remaining_spawns), 1.0)
	spawn_clock = .2
	message = ""
	message = EnemyVariants.notice_for_wave(GameStateService.current_wave)
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
	for pickup: ScrapPickup in pickup_root.get_children():
		pickup.collect()
	if is_instance_valid(carried_turret):
		carried_turret.carried = false
		carried_turret.position = carry_origin
		carried_turret = null
	var reward := EconomyService.get_wave_scrap_base(GameStateService.current_wave)
	collect_scrap(reward)
	audio.reset()
	message = "Wave secured · +%d scrap bonus" % reward
	if GameStateService.current_wave >= wave_limit:
		audio.play_cue("victory", player.position)
		GameStateMachine.transition_to(GameStateMachine.GameState.VICTORY)
		GameStateService.is_game_active = false
	else:
		GameStateMachine.transition_to(GameStateMachine.GameState.SHOP)
		shop.open()
		audio.play_cue("wave", player.position)
	return true

func spawn_enemy(at: Vector3, type_id: String = "basic") -> CombatActor:
	var enemy := CombatActor.new()
	enemy.world = self
	enemy.is_enemy = true
	enemy.enemy_type = type_id
	var base := EnemyRegistry.get_stats_for_wave(type_id, maxi(GameStateService.current_wave, 1), difficulty_config)
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
	actor_root.add_child(enemy)
	enemies.append(enemy)
	return enemy

## Enemies appear on a ring just outside the default-zoom view around the player, clamped to the arena, so they
## reach the fight quickly on the large map. A spot clamped back into view is retried a few times.
func _spawn_position() -> Vector3:
	var centre := WorldGeometry.planar(player.position) if is_instance_valid(player) else Vector3.ZERO
	var ring := camera_rig.visible_half_extents(GameConstants.CAMERA_DEFAULT_ZOOM) + Vector2.ONE * GameConstants.ENEMY_SPAWN_VIEW_MARGIN
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
	if not shop.is_open() or player.health >= player.max_health or not EconomyService.deduct_scrap(5):
		return false
	player.health = minf(player.max_health, player.health + 10.0)
	audio.play_cue("purchase", player.position)
	message = "Hull repaired."
	return true

## First free spot on a grid around the player (the origin when no player exists yet).
func find_placement() -> Vector3:
	var origin := WorldGeometry.planar(player.position) if is_instance_valid(player) else Vector3.ZERO
	for z: float in [-1.0, 1.0, -3.0, 3.0]:
		for x: float in [0.0, -2.0, 2.0, -4.0, 4.0, -6.0, 6.0]:
			var candidate := origin + Vector3(x, 0, z)
			if valid_placement(candidate):
				return candidate
	return Vector3.INF

func valid_placement(at: Vector3, excluding: TurretActor = null) -> bool:
	if WorldGeometry.clamp_position(at, .55).distance_squared_to(at) > .0001:
		return false
	for turret in turrets:
		if turret != excluding and WorldGeometry.planar(turret.position - at).length() < 1.0:
			return false
	return true

func interact() -> bool:
	if not is_combat():
		return false
	if is_instance_valid(carried_turret):
		var forward := -player.visual.global_basis.z
		var at := WorldGeometry.planar(player.position + forward * .9)
		if not valid_placement(at, carried_turret):
			message = "Move clear of the edge or another turret."
			return false
		carried_turret.position = at
		carried_turret.carried = false
		carried_turret = null
		message = "Turret deployed."
		return true
	var nearest: TurretActor = null
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

func _build_stage() -> void:
	_build_lighting()
	var half := WorldGeometry.HALF_ARENA
	var ground := StaticBody3D.new()
	ground.collision_layer = WorldGeometry.WORLD_LAYER
	ground.collision_mask = 0
	add_child(ground)
	var floor_size := Vector3(half.x * 2.0 + .6, .35, half.y * 2.0 + .6)
	# The collider is a slab; the visible surface is one textured plane on top of it (a single draw call).
	var floor_plane := PlaneMesh.new()
	floor_plane.size = Vector2(floor_size.x, floor_size.z)
	var floor_visual := MeshInstance3D.new()
	floor_visual.mesh = floor_plane
	floor_visual.material_override = WorldGeometry.floor_material(floor_plane.size)
	floor_visual.position.y = -.02
	ground.add_child(floor_visual)
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = floor_size
	floor_shape.shape = floor_box
	floor_shape.position.y = -.2
	ground.add_child(floor_shape)
	var rim := WorldGeometry.material(Color("258e99"), true)
	for z: float in [-half.y - .05, half.y + .05]:
		WorldGeometry.box(self, Vector3(half.x * 2.0 + .3, .08, .06), Vector3(0, .02, z), rim)
	for x: float in [-half.x - .05, half.x + .05]:
		WorldGeometry.box(self, Vector3(.06, .08, half.y * 2.0 + .1), Vector3(x, .02, 0), rim)
	var markings := WorldGeometry.material(Color("c48c48"))
	var stripe_transforms: Array[Transform3D] = []
	for x: float in [-half.x + .35, half.x - .35]:
		for z in range(-int(half.y) + 1, int(half.y)):
			stripe_transforms.append(Transform3D(Basis(Vector3.UP, -.5), Vector3(x, 0, z)))
	_add_multimesh(Vector3(.16, .015, .4), stripe_transforms, markings)
	camera = Camera3D.new()
	add_child(camera)
	camera_rig = CameraRig.new()
	add_child(camera_rig)
	camera_rig.setup(camera, self)

func _build_lighting() -> void:
	# A dark gradient sky doubles as the ambient and reflection source, so metal parts have something to mirror.
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("0b2233")
	sky_material.sky_horizon_color = Color("2a5a6a")
	sky_material.ground_horizon_color = Color("2a5a6a")
	sky_material.ground_bottom_color = Color("08151e")
	sky_material.sky_energy_multiplier = .9
	var sky := Sky.new()
	sky.sky_material = sky_material
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	settings.ambient_light_energy = .7
	settings.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.tonemap_white = 6.0
	# Bloom: only emissive/very bright surfaces cross the threshold, which makes muzzles, eyes and shots glow.
	settings.glow_enabled = true
	settings.glow_intensity = .8
	settings.glow_strength = 1.0
	settings.glow_bloom = .05
	settings.glow_hdr_threshold = 1.0
	settings.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# Contact shadows where models meet the floor and in crevices.
	settings.ssao_enabled = true
	settings.ssao_radius = 1.2
	settings.ssao_intensity = 2.0
	settings.ssao_power = 1.6
	settings.ssil_enabled = true
	settings.ssil_intensity = .6
	# Depth fog pulls the far arena edge into the background colour.
	settings.fog_enabled = true
	settings.fog_light_color = Color("0f2a38")
	settings.fog_density = .012
	settings.fog_sky_affect = .4
	var environment := WorldEnvironment.new()
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_color = Color("d0eaff")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0 # the follow camera only ever sees a small slice of the arena
	add_child(sun)
	# Warm back light, opposite the sun and without shadows, so silhouettes separate from the teal floor.
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-30, 155, 0)
	rim.light_color = Color("ff7a45")
	rim.light_energy = .55
	rim.shadow_enabled = false
	add_child(rim)

func _add_multimesh(size: Vector3, transforms: Array[Transform3D], mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = mat
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
