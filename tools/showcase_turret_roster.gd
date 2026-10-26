extends Node

## Native, repeatable attack/visual review. Uses ordinary actor physics and projectiles.
## Durable stationary enemies keep every weapon firing without changing balance data.
## [base, level-5 upgrade, level-10 final, level-10 final under --alternate]. Each turret is shown as the upgrade, then evolved.
const ROSTER := [
	["normal", "machine_gun", "cyclone_gatling", "omnifire"],
	["normal", "machine_gun", "omnifire", "cyclone_gatling"],
	["melee", "saber", "orbit_saber", "stormblade"],
	["melee", "saber", "stormblade", "orbit_saber"],
	["plasma", "siege", "worldbreaker", "worldbreaker"],
	["bow", "repeater_bow", "arrowstorm", "titan_bow"],
	["flamethrower", "wide_flame", "inferno_crown", "dragonheart"],
	["bowling", "heavy_roller", "juggernaut", "ricochet_king"],
	["shock", "resonator", "resonance_engine", "thunder_spear"],
	["shock", "resonator", "thunder_spear", "resonance_engine"],
	["sniper", "piercer_rifle", "horizon_piercer", "overwatch"],
	["sniper", "piercer_rifle", "overwatch", "horizon_piercer"],
	["quake", "aftershock", "tectonic", "cataclysm"],
	["quake", "aftershock", "cataclysm", "tectonic"],
]
var world: ArenaWorld
var actors: Array[TurretActor] = []
var labels: Array[Label3D] = []
var hits: Dictionary = {}
var alternate := "--alternate" in OS.get_cmdline_user_args()
var moving := "--moving" in OS.get_cmdline_user_args()
var starts: Dictionary = {}
var moved_enemies := 0
var phase := "initial"
var ticks := 0
var carried_index := -1
var report: Dictionary = {}
var paused_positions: Array[Vector3] = []

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.test-results"))
	seed(73021)
	world = ArenaWorld.new()
	world.auto_start = false
	world.show_hud = false
	add_child(world)
	world.start_run()
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.player.position = Vector3(0, 0, 7)
	if moving:
		world.player.health = 100000
		world.player.max_health = 100000
	world.camera_rig.set_physics_process(false)
	world.camera.position = CameraRig.OFFSET
	world.camera.look_at(Vector3.ZERO)
	world.camera.size = world.camera_rig.view_size(GameConstants.CAMERA_DEFAULT_ZOOM)
	world.session.state.turret_progression_enabled = true
	for old in world.turrets:
		old.set_physics_process(false)
		old.visible = false
	GameStateMachine.force_transition(GameStateMachine.GameState.SHOP)
	for i in ROSTER.size():
		var spec: Array = ROSTER[i]
		var turret := world.add_turret(Vector3((i % 5 - 2) * 4.2, 0, -3.3 + 6.6 * float(i / 5)), spec[0])
		turret.progression.award(1500)
		turret.evolve(spec[1])
		actors.append(turret)
		var label := Label3D.new()
		label.text = turret.display_name()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = turret.position + Vector3(0, .1, 1.2)
		label.font_size = 36
		label.pixel_size = .006
		world.add_child(label)
		labels.append(label)
		_targets(turret.position)
	world.combat.hit_applied.connect(_hit)
	world.crowd.rebuild(world.enemies)
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)

func _targets(center: Vector3) -> void:
	for offset in [Vector3(-.65, 0, -1.6), Vector3(0, 0, -1.9), Vector3(.65, 0, -1.6)]:
		var enemy := world.spawn_enemy(center + offset)
		enemy.stationary = not moving
		if moving:
			starts[enemy] = enemy.position
		enemy.health = 100000
		enemy.max_health = 100000

func _hit(_target: Node3D, hit: CombatHit3D, damage: float) -> void:
	if damage > 0 and hit.source_id > 0:
		hits[hit.source_id] = int(hits.get(hit.source_id, 0)) + 1

func _physics_process(_delta: float) -> void:
	if not world:
		return
	if moving and world.is_combat():
		world.crowd.rebuild(world.enemies)
		for enemy in starts.keys():
			if not is_instance_valid(enemy):
				starts.erase(enemy)
			elif enemy.position.distance_to(starts[enemy]) > .3:
				moved_enemies += 1
				starts.erase(enemy)
	ticks += 1
	if ticks == 180 and phase in ["initial", "final"]:
		capture.call_deferred(phase)
	if ticks < (60 if phase == "paused" else 180 if phase == "carried" else 240):
		return
	if phase == "initial":
		_record("initial")
		GameStateMachine.force_transition(GameStateMachine.GameState.SHOP)
		for i in actors.size():
			var last_form: String = ROSTER[i][3 if alternate else 2]
			if not actors[i].evolve(last_form):
				push_error("Unavailable showcase evolution: " + last_form)
				get_tree().quit(1)
				return
			labels[i].text = actors[i].display_name()
		if moving:
			_reset_moving_targets()
			for turret in actors:
				_targets(turret.position)
		GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
		phase = "final"
	elif phase == "final":
		_record("final")
		phase = "paused"
		world.toggle_pause()
		for projectile in world.projectiles:
			paused_positions.append(projectile.position)
	elif phase == "paused":
		var unchanged := hits.is_empty()
		for i in world.projectiles.size():
			unchanged = unchanged and world.projectiles[i].position.is_equal_approx(paused_positions[i])
		report["pause_stops_damage_and_projectile_motion"] = 1 if unchanged else 0
		world.toggle_pause()
		phase = "carried"
		_targets(world.player.position)
		world.crowd.rebuild(world.enemies)
		_next_carried()
	else:
		var turret := actors[carried_index]
		report["carried_%d_%s" % [carried_index, turret.display_name()]] = int(hits.get(turret.turret_id, 0))
		turret.carried = false
		turret.set_physics_process(false)
		if carried_index == actors.size() - 1:
			finish()
			return
		_next_carried()
	hits.clear()
	ticks = 0

func _next_carried() -> void:
	# Remove prior shots and burns so attributed hits prove new carried attacks.
	for projectile in world.projectiles:
		projectile.release()
	for enemy in world.enemies:
		enemy.statuses.clear()
	for turret in actors:
		turret.set_physics_process(false)
	if moving:
		_reset_moving_targets()
		_targets(world.player.position)
	carried_index += 1
	actors[carried_index].carried = true
	actors[carried_index].cooldown = 0
	actors[carried_index].set_physics_process(true)

func _record(prefix: String) -> void:
	for i in actors.size():
		report["%s_%d_%s" % [prefix, i, actors[i].display_name()]] = int(hits.get(actors[i].turret_id, 0))

func capture(suffix: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.test-results/roster-%s%s.png" % [suffix, ("-alternate" if alternate else "") + ("-moving" if moving else "")]))

func finish() -> void:
	if moving:
		report["enemies_moved_under_normal_ai"] = moved_enemies
		# Exercise actual player defeat while attacks and enemies are live.
		world.player.invulnerability = 0.0
		world.combat.apply_hit(world.player, CombatHit3D.new(1000000, Vector3.ZERO))
		var stopped := not world.is_combat() and world.player.dead
		for projectile in world.projectiles:
			stopped = stopped and not projectile.active
		for ribbon in world.effects.flame_ribbons:
			stopped = stopped and not ribbon.visible
		report["player_defeat_stops_combat_and_clears_attacks"] = 1 if stopped else 0
	world.clear_field(false)
	var clean := world.enemies.is_empty()
	for projectile in world.projectiles:
		clean = clean and not projectile.active
	for ribbon in world.effects.flame_ribbons:
		clean = clean and not ribbon.visible
	report["cleanup_removes_enemies_projectiles_and_flames"] = 1 if clean else 0
	var passed := true
	for count in report.values():
		passed = passed and int(count) > 0
	var file := FileAccess.open("res://.test-results/roster-showcase%s.json" % (("-alternate" if alternate else "") + ("-moving" if moving else "")), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("ROSTER_SHOWCASE ", "PASS" if passed else "FAIL", " ", JSON.stringify(report))
	get_tree().quit(0 if passed else 1)

func _reset_moving_targets() -> void:
	for enemy in world.enemies:
		enemy.queue_free()
	world.enemies.clear()
	starts.clear()
	for projectile in world.projectiles:
		projectile.release()
	world.crowd.rebuild(world.enemies)
