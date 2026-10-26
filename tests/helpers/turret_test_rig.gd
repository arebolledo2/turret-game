class_name TurretTestRig
extends RefCounted

## The world and turret setup that turret tests used to copy: a fresh arena with every actor's physics off, turret
## progression on, and the shop (or combat) state forced. Drive the turrets by hand with `step` and `run`, so a test controls
## exactly when they act.
##
## ```gdscript
## func before_each() -> void:
##     rig = TurretTestRig.start(self)
##     rig.disable_crits()   # exact-damage tests: turret crits roll on the shared RNG, so only the seed keeps them out
## func test_x() -> void:
##     var turret := rig.turret("sniper", ["piercer_rifle"])
##     var target := rig.enemy(Vector3(0, 0, -4), 500.0)
##     rig.combat()
##     rig.step(turret)
## ```

const DEFAULT_STEP: float = 1.0 / 60.0

var test: GutTest
var world: ArenaWorld

## A fresh arena owned by `owner` (freed with it) in the SHOP state, or in COMBAT when `in_combat`. `progression` turns turret
## progression on for the run (forms, levels); pass false to keep the run default.
static func start(owner: GutTest, in_combat: bool = false, progression: bool = true) -> TurretTestRig:
	var rig := TurretTestRig.new()
	rig.test = owner
	TestHelpers.reset_all_services()
	rig.world = ArenaWorld.new()
	rig.world.auto_start = false
	rig.world.show_hud = false
	owner.add_child_autofree(rig.world)
	rig.world.start_run()
	rig.world.set_physics_process(false)
	rig.world.player.set_physics_process(false)
	if progression:
		rig.world.session.state.turret_progression_enabled = true
	for starting in rig.world.turrets:
		starting.set_physics_process(false)
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT if in_combat else GameStateMachine.GameState.SHOP)
	return rig

## A turret of `type_id` at `at` that does not run its own physics. `forms` evolves it through those form ids in order
## (levelling it to 5, or to 10 for two forms, first) and fails the calling test if one is refused.
func turret(type_id: String, forms: Array[String] = [], at: Vector3 = Vector3.ZERO) -> TurretActor:
	var result := world.add_turret(Vector3(30, 0, 30), type_id)
	result.set_physics_process(false)
	result.position = at
	if forms.is_empty():
		return result
	level_to(result, TurretProgression.EVOLUTION_LEVELS[mini(forms.size(), TurretProgression.EVOLUTION_LEVELS.size()) - 1])
	for form in forms:
		test.assert_true(result.evolve(form), "%s evolves" % form)
	return result

## Awards exactly the XP that takes `turret` to `level`.
func level_to(turret: TurretActor, level: int) -> void:
	while turret.progression.level < level:
		turret.progression.award(TurretProgression.cost_to_next(turret.progression.level) - turret.progression.xp)

## An inert enemy (no AI, no ticking) with a fixed health.
func enemy(at: Vector3, health: float = 100.0, type_id: String = "basic") -> CombatActor:
	var result := world.spawn_enemy(at, type_id)
	result.set_physics_process(false)
	result.health = health
	result.max_health = health
	return result

func combat() -> void:
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	world.crowd.rebuild(world.enemies)

func shop() -> void:
	GameStateMachine.force_transition(GameStateMachine.GameState.SHOP)

## One physics step of the real turret loop (targeting, cooldown, firing).
func step(turret: TurretActor, delta: float = DEFAULT_STEP) -> void:
	world.crowd.rebuild(world.enemies)
	turret._physics_process(delta)

func run(turret: TurretActor, seconds: float, delta: float = DEFAULT_STEP) -> void:
	for i in roundi(seconds / delta):
		step(turret, delta)

## See `TestHelpers.disable_crits`.
func disable_crits() -> void:
	TestHelpers.disable_crits()
