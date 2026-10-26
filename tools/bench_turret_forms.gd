extends Node

## Damage-per-second comparison of evolved turret forms against identical stationary targets.
## Run: godot --headless --fixed-fps 60 --path . res://tools/bench_turret_forms.tscn [-- --seconds=15] [--level=10] [--base=sniper]
## --level=N gives every turret exactly the XP for level N (default: 1500 XP). A final needs level 10, so it is skipped below that.
## --base=ID runs only the rows of that base turret. Cells are CELL apart: keep that above the longest range plus the
## enemy offsets (a Sniper reaches over 10 m at level 10) or turrets shoot each other's targets.
## Each form sits alone in its own cell, so no turret can reach another's enemies. Enemies are tough and
## stationary; damage is credited to the turret that dealt it. Scenarios:
##   single  one enemy 1.5 m away
##   cluster eight enemies packed around a point 1.5 m away
##   lane    three enemies in a line at 1.5, 2.5 and 3.4 m (tests reach and piercing)
## "slow" is the share of enemy-seconds spent slowed (by a status or by standing in a ground zone).
## [base, form(, companion form)]: a form id is reached through its base's level-5 upgrade first; "" is the unevolved base.
## A third entry puts an Ion turret of that form (a Machine Gun) beside it in the same cell; the row then reports the
## whole cell's damage, which is how a team buff such as the Overwatch mark is measured.
const FORMS := [
	["normal", ""], ["shock", ""], ["tesla", ""],
	["shock", "resonator"], ["shock", "resonance_engine"], ["shock", "thunder_spear"],
	["normal", "machine_gun"], ["normal", "cyclone_gatling"], ["normal", "omnifire"],
	["plasma", "siege"], ["plasma", "worldbreaker"],
	["melee", "saber"], ["melee", "orbit_saber"], ["melee", "stormblade"],
	["bow", "repeater_bow"], ["bow", "arrowstorm"], ["bow", "titan_bow"],
	["flamethrower", "wide_flame"], ["flamethrower", "inferno_crown"], ["flamethrower", "dragonheart"],
	["bowling", "heavy_roller"], ["bowling", "juggernaut"], ["bowling", "ricochet_king"],
	["sniper", ""], ["sniper", "piercer_rifle"], ["sniper", "horizon_piercer"], ["sniper", "overwatch"],
	["sniper", "piercer_rifle", "machine_gun"], ["sniper", "horizon_piercer", "machine_gun"], ["sniper", "overwatch", "machine_gun"],
	["quake", ""], ["quake", "aftershock"], ["quake", "tectonic"], ["quake", "cataclysm"],
]
const SCENARIOS := ["single", "cluster", "lane"]
const COLUMNS := 8
const CELL := Vector2(16.0, 18.0)

var world: ArenaWorld
var actors: Array[TurretActor] = []
## Companion turret per row index (only rows with a third entry).
var companions: Dictionary = {}
var level: int = 0
var only_base: String = ""
## FORMS minus the rows this run cannot reach (finals below level 10).
var rows: Array = []
var phase: int = -1
var ticks: int = 0
var seconds: float = 15.0
var damage: Dictionary = {}
var slowed: Dictionary = {}
var samples: Dictionary = {}
var results: Dictionary = {}

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seconds="):
			seconds = float(argument.get_slice("=", 1))
		elif argument.begins_with("--level="):
			level = int(argument.get_slice("=", 1))
		elif argument.begins_with("--base="):
			only_base = argument.get_slice("=", 1)
	seed(73021)
	for spec: Array in FORMS:
		if not only_base.is_empty() and spec[0] != only_base:
			continue
		var tier := TurretEvolution.legacy_stage(spec[1])
		if level > 0 and (level < TurretProgression.EVOLUTION_LEVELS[0] or (tier >= 3 and level < TurretProgression.EVOLUTION_LEVELS[1])):
			continue
		rows.append(spec)
	world = ArenaWorld.new()
	world.auto_start = false
	world.show_hud = false
	add_child(world)
	world.start_run()
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.player.position = Vector3(0, 0, 60)
	world.camera_rig.set_physics_process(false)
	world.session.state.turret_progression_enabled = true
	for old in world.turrets:
		old.set_physics_process(false)
		old.visible = false
	GameStateMachine.force_transition(GameStateMachine.GameState.SHOP)
	for i in rows.size():
		var spec: Array = rows[i]
		var cell := _cell(i)
		var turret := world.add_turret(Vector3(cell.x, 0, cell.y), spec[0])
		_level_up(turret)
		if not spec[1].is_empty():
			var upgrade: String = TurretEvolution.PATHS[spec[0]].upgrade
			var path: Array = [upgrade] if spec[1] == upgrade else [upgrade, spec[1]]
			for form: String in path:
				if not turret.evolve(form):
					push_error("Cannot evolve %s (level %d)" % [form, turret.progression.level])
		actors.append(turret)
		if spec.size() > 2:
			var companion := world.add_turret(Vector3(cell.x + 1.0, 0, cell.y), "normal")
			_level_up(companion)
			if not companion.evolve(spec[2]):
				push_error("Cannot evolve companion %s" % spec[2])
			companions[i] = companion
	world.combat.hit_applied.connect(_hit)
	_next_phase()

func _level_up(turret: TurretActor) -> void:
	if level <= 0:
		turret.progression.award(1500)
		return
	var xp := 0
	for step in range(1, level):
		xp += TurretProgression.cost_to_next(step)
	turret.progression.award(xp)

func _cell(index: int) -> Vector2:
	return Vector2((index % COLUMNS - COLUMNS / 2.0) * CELL.x, (index / COLUMNS) * CELL.y)

func _hit(_target: Node3D, hit: CombatHit3D, amount: float) -> void:
	if amount > 0.0 and hit.source_id > 0:
		damage[hit.source_id] = float(damage.get(hit.source_id, 0.0)) + amount

func _spawn(centre: Vector2, offset: Vector3) -> CombatActor:
	var enemy := world.spawn_enemy(Vector3(centre.x + offset.x, 0, centre.y + offset.z))
	enemy.stationary = true
	enemy.health = 1000000
	enemy.max_health = 1000000
	return enemy

func _next_phase() -> void:
	phase += 1
	if phase >= SCENARIOS.size():
		_finish()
		return
	GameStateMachine.force_transition(GameStateMachine.GameState.SHOP)
	for projectile in world.projectiles:
		projectile.release()
	for enemy in world.enemies:
		enemy.queue_free()
	world.enemies.clear()
	for turret in actors:
		turret.cooldown = 0.0
	damage.clear()
	slowed.clear()
	samples.clear()
	for i in actors.size():
		var centre := _cell(i)
		match SCENARIOS[phase]:
			"single":
				_spawn(centre, Vector3(0, 0, -1.5))
			"cluster":
				for k in 8:
					var angle := float(k) * TAU / 8.0
					var ring := .45 if k < 4 else .9
					_spawn(centre, Vector3(cos(angle) * ring, 0, -1.5 + sin(angle) * ring))
			"lane":
				for distance in [1.5, 2.5, 3.4]:
					_spawn(centre, Vector3(0, 0, -distance))
	world.crowd.rebuild(world.enemies)
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	ticks = 0

func _physics_process(_delta: float) -> void:
	if phase < 0 or phase >= SCENARIOS.size():
		return
	ticks += 1
	if ticks == 60:
		# One second of warm-up so charge-up, echoes and first shots do not skew the window.
		damage.clear()
	if ticks > 60:
		for enemy: CombatActor in world.enemies:
			if is_instance_valid(enemy) and not enemy.dead:
				var owner_cell := _nearest_cell(enemy.position)
				samples[owner_cell] = int(samples.get(owner_cell, 0)) + 1
				if enemy.statuses.speed_multiplier() < .99 or world.ground_zones.speed_factor_at(enemy.position, enemy.hurtbox_radius()) < .99:
					slowed[owner_cell] = int(slowed.get(owner_cell, 0)) + 1
	if ticks >= 60 + int(seconds * 60.0):
		for i in actors.size():
			var total := float(damage.get(actors[i].turret_id, 0.0))
			if companions.has(i):
				total += float(damage.get(companions[i].turret_id, 0.0))
			var dps := total / seconds
			var slow := float(slowed.get(i, 0)) / maxf(1.0, float(samples.get(i, 1)))
			results[_name(i)] = results.get(_name(i), {})
			results[_name(i)][SCENARIOS[phase]] = [dps, slow]
		_next_phase()

func _nearest_cell(position: Vector3) -> int:
	var best := 0
	var best_distance := INF
	for i in actors.size():
		var cell := _cell(i)
		var distance := Vector2(position.x, position.z).distance_squared_to(cell)
		if distance < best_distance:
			best_distance = distance
			best = i
	return best

func _name(index: int) -> String:
	var label := actors[index].display_name() + (" +MG" if companions.has(index) else "")
	return "%-18s L%d" % [label, actors[index].progression.level]

func _finish() -> void:
	print("FORM                    | single dps slow | cluster dps slow | lane dps slow")
	for i in actors.size():
		var key := _name(i)
		var row: Dictionary = results[key]
		var line := "%-24s|" % key
		for scenario in SCENARIOS:
			line += " %7.1f %4.0f%% |" % [row[scenario][0], row[scenario][1] * 100.0]
		print(line)
	get_tree().quit()
