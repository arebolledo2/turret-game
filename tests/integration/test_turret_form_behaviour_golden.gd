extends GutTest

## Golden probes of the form behaviours that used to read `legacy_stage` (rotor spool, Resonator echoes, volleys, the
## Thunder Spear lane, Omnifire's circle, the Stormblade burst) and of the shop's DPS and burst estimates, recorded from
## the code before the form-table refactor. Together with `test_turret_form_golden.gd` (data) this pins what each form does,
## so the stage shim can go without a behaviour change. Expected values are literals; adapt only how a probe reaches the
## form, never the numbers.

const BASES: Array[String] = ["normal", "melee", "bow", "flamethrower", "bowling", "plasma", "shock", "tesla", "sniper", "quake"]

const SPOOL: Dictionary = {
	"machine_gun": {"tracking_5": [0.0, 1.0], "tracking_20": [0.0, 1.0], "idle_20": [0.0, 1.0]},
	"cyclone_gatling": {"tracking_5": [0.75, 1.75], "tracking_20": [1.5, 2.5], "idle_20": [0.0, 1.0]},
}

const ECHOES: Dictionary = {
	"resonator": [{"echoes": [[0.5, 0.5, 1.0]], "outer_next": false}, {"echoes": [[0.5, 0.5, 1.0]], "outer_next": false}, {"echoes": [[0.5, 0.5, 1.0]], "outer_next": false}],
	"resonance_engine": [{"echoes": [[0.4, 1.0, 0.5], [0.8, 1.0, 0.5]], "outer_next": true}, {"echoes": [[0.4, 0.5, 1.3], [0.8, 0.5, 1.3]], "outer_next": false}, {"echoes": [[0.4, 1.0, 0.5], [0.8, 1.0, 0.5]], "outer_next": true}],
}

const VOLLEY: Dictionary = {
	"repeater_bow": {"left_after_first_draw": 1, "fired_at_once": 1, "fired_after_burst": 2},
	"arrowstorm": {"left_after_first_draw": 4, "fired_at_once": 1, "fired_after_burst": 5},
}

const LANE: Dictionary = {
	"thunder_spear": [true, true, true, false],
}

const OMNIFIRE: Dictionary = {
	"omnifire": 12,
}

const BURST: Dictionary = {
	"stormblade": {"left": 2, "fired": 1, "muzzles": 3},
}

const SHOP: Dictionary = {
	"machine_gun": {"dps": "20.8000", "burst_size": 1, "damage": "6.5000", "range": "2.4000", "fire_rate": "3.2000", "rotation_rate": "0.0000", "area": "0.0000"},
	"cyclone_gatling": {"dps": "31.2000", "burst_size": 1, "damage": "6.5000", "range": "2.4000", "fire_rate": "4.8000", "rotation_rate": "0.0000", "area": "0.0000"},
	"omnifire": {"dps": "12.5000", "burst_size": 1, "damage": "10.0000", "range": "2.2000", "fire_rate": "1.2500", "rotation_rate": "0.0000", "area": "0.0000"},
	"saber": {"dps": "12.8333", "burst_size": 1, "damage": "11.0000", "range": "1.4500", "fire_rate": "0.0000", "rotation_rate": "420.0000", "area": "0.0000"},
	"orbit_saber": {"dps": "28.0000", "burst_size": 1, "damage": "14.0000", "range": "1.7000", "fire_rate": "0.0000", "rotation_rate": "480.0000", "area": "0.0000"},
	"stormblade": {"dps": "61.3902", "burst_size": 1, "damage": "12.0000", "range": "1.7000", "fire_rate": "0.0000", "rotation_rate": "360.0000", "area": "0.0000", "gun": {"burst_size": 3, "damage": "9.0000", "range": "3.0000", "fire_rate": "2.4000"}},
	"repeater_bow": {"dps": "19.9815", "burst_size": 2, "damage": "12.0000", "range": "3.4000", "fire_rate": "0.9000", "rotation_rate": "0.0000", "area": "0.0000"},
	"arrowstorm": {"dps": "55.1576", "burst_size": 5, "damage": "14.0000", "range": "3.4000", "fire_rate": "1.1000", "rotation_rate": "0.0000", "area": "0.0000"},
	"titan_bow": {"dps": "52.8000", "burst_size": 1, "damage": "66.0000", "range": "4.7000", "fire_rate": "0.8000", "rotation_rate": "0.0000", "area": "0.0000"},
	"wide_flame": {"dps": "17.9200", "burst_size": 1, "damage": "3.2000", "range": "2.0000", "fire_rate": "4.0000", "rotation_rate": "0.0000", "area": "2.0000"},
	"inferno_crown": {"dps": "28.0000", "burst_size": 1, "damage": "5.0000", "range": "2.0000", "fire_rate": "4.0000", "rotation_rate": "0.0000", "area": "2.0000"},
	"dragonheart": {"dps": "35.0000", "burst_size": 1, "damage": "5.0000", "range": "3.8000", "fire_rate": "4.0000", "rotation_rate": "0.0000", "area": "3.8000"},
	"heavy_roller": {"dps": "18.0000", "burst_size": 1, "damage": "30.0000", "range": "3.2000", "fire_rate": "0.6000", "rotation_rate": "0.0000", "area": "0.0000"},
	"juggernaut": {"dps": "42.0000", "burst_size": 1, "damage": "60.0000", "range": "3.2000", "fire_rate": "0.7000", "rotation_rate": "0.0000", "area": "0.0000"},
	"ricochet_king": {"dps": "32.4000", "burst_size": 1, "damage": "36.0000", "range": "3.2000", "fire_rate": "0.9000", "rotation_rate": "0.0000", "area": "0.0000"},
	"siege": {"dps": "18.9000", "burst_size": 1, "damage": "42.0000", "range": "3.3000", "fire_rate": "0.4500", "rotation_rate": "0.0000", "area": "1.3500"},
	"worldbreaker": {"dps": "44.0000", "burst_size": 1, "damage": "80.0000", "range": "3.3000", "fire_rate": "0.5500", "rotation_rate": "0.0000", "area": "1.8500"},
	"resonator": {"dps": "6.0000", "burst_size": 1, "damage": "5.0000", "range": "2.4000", "fire_rate": "1.2000", "rotation_rate": "0.0000", "area": "2.4000"},
	"resonance_engine": {"dps": "6.0000", "burst_size": 1, "damage": "5.0000", "range": "2.7600", "fire_rate": "1.2000", "rotation_rate": "0.0000", "area": "2.7600"},
	"thunder_spear": {"dps": "40.8000", "burst_size": 1, "damage": "48.0000", "range": "4.0000", "fire_rate": "0.8500", "rotation_rate": "0.0000", "area": "4.0000"},
	"piercer_rifle": {"dps": "20.8000", "burst_size": 1, "damage": "52.0000", "range": "7.6000", "fire_rate": "0.4000", "rotation_rate": "0.0000", "area": "0.0000"},
	"horizon_piercer": {"dps": "31.5000", "burst_size": 1, "damage": "70.0000", "range": "8.2000", "fire_rate": "0.4500", "rotation_rate": "0.0000", "area": "0.0000"},
	"overwatch": {"dps": "23.5200", "burst_size": 1, "damage": "56.0000", "range": "7.8000", "fire_rate": "0.4200", "rotation_rate": "0.0000", "area": "0.0000"},
	"aftershock": {"dps": "12.1500", "burst_size": 1, "damage": "18.0000", "range": "2.7000", "fire_rate": "0.4500", "rotation_rate": "0.0000", "area": "2.7000"},
	"tectonic": {"dps": "20.0000", "burst_size": 1, "damage": "40.0000", "range": "4.0000", "fire_rate": "0.5000", "rotation_rate": "0.0000", "area": "4.0000"},
	"cataclysm": {"dps": "23.0769", "burst_size": 1, "damage": "30.0000", "range": "2.8000", "fire_rate": "0.5000", "rotation_rate": "0.0000", "area": "2.8000"},
}

var world: ArenaWorld
var _recorded: Dictionary = {}

func before_all() -> void:
	TestHelpers.reset_all_services()
	world = ArenaWorld.new()
	world.auto_start = false
	world.show_hud = false
	add_child(world)
	world.start_run()
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.session.state.turret_progression_enabled = true
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	_recorded = record_all()

func after_all() -> void:
	remove_child(world)
	world.free()

## A turret of `base` already in `form`, standing at the origin, without going through the shop.
func _turret(base: String, form: String) -> TurretActor:
	var turret := world.add_turret(Vector3.ZERO, base)
	turret.set_physics_process(false)
	turret.position = Vector3.ZERO
	turret.progression.evolution_form = form
	turret._rebuild_model()
	turret.invalidate_stats()
	return turret

func _enemy(at: Vector3) -> CombatActor:
	var result := world.spawn_enemy(at, "basic")
	result.set_physics_process(false)
	result.health = 1000.0
	result.max_health = 1000.0
	return result

func _active_projectiles() -> int:
	return world.projectiles.filter(func(p: Projectile3D) -> bool: return p.active).size()

func _clear() -> void:
	for projectile in world.projectiles:
		projectile.active = false
	for enemy in world.enemies.duplicate():
		world.enemies.erase(enemy)
		enemy.free()
	for turret in world.turrets.duplicate():
		world.turrets.erase(turret)
		turret.free()

func _round(values: Array) -> Array:
	var result: Array = []
	for value in values:
		result.append(_round(value) if value is Array else snappedf(float(value), .001))
	return result

func record_all() -> Dictionary:
	var result := {"spool": {}, "echoes": {}, "volley": {}, "lane": {}, "omnifire": {}, "burst": {}, "shop": {}}
	for form in ["machine_gun", "cyclone_gatling"]:
		var turret := _turret("normal", form)
		var steps := {}
		for entry in [["tracking_5", 5, true], ["tracking_20", 15, true], ["idle_20", 20, false]]:
			for i in range(int(entry[1])):
				turret.form.tick_mechanisms(.1, entry[2])
			steps[entry[0]] = [snappedf(turret.form.spool, .001), snappedf(turret.form.cooldown_divisor(), .001)]
		result.spool[form] = steps
		_clear()
	for form in ["resonator", "resonance_engine"]:
		var turret := _turret("shock", form)
		var stats := turret._current_view(0.0)
		var log: Array = []
		for shot in range(3):
			turret.form.fire(stats, 2.4)
			log.append({"echoes": _round(turret.form.echoes.duplicate(true)), "outer_next": turret.form.outer_next})
			turret.form.echoes.clear()
		result.echoes[form] = log
		_clear()
	for form in ["repeater_bow", "arrowstorm"]:
		var turret := _turret("bow", form)
		turret.target = _enemy(Vector3(0, 0, -4))
		var stats := turret._current_view(0.0)
		turret._fire_projectile(stats)
		var queued: int = turret.bow_burst.left
		var fired_at_once := _active_projectiles()
		turret._tick_bow_burst(1.0, stats)
		result.volley[form] = {"left_after_first_draw": queued, "fired_at_once": fired_at_once, "fired_after_burst": _active_projectiles()}
		_clear()
	var spear := _turret("shock", "thunder_spear")
	var lane: Array[CombatActor] = [_enemy(Vector3(0, 0, -1)), _enemy(Vector3(0, 0, -2)), _enemy(Vector3(.3, 0, -3.5)), _enemy(Vector3(3, 0, -2))]
	world.crowd.rebuild(world.enemies)
	var spear_stats := spear._current_view(0.0)
	spear.form.fire(spear_stats, spear.effective_range(spear_stats), lane[0])
	var struck: Array = []
	for enemy in lane:
		struck.append(enemy.health < 1000.0)
	result.lane["thunder_spear"] = struck
	_clear()
	var omni := _turret("normal", "omnifire")
	omni.target = _enemy(Vector3(0, 0, -2))
	omni.form.fire_projectile(omni._current_view(0.0), Vector3.FORWARD)
	result.omnifire["omnifire"] = _active_projectiles()
	_clear()
	var storm := _turret("melee", "stormblade")
	_enemy(Vector3(0, 0, -2.8))
	world.crowd.rebuild(world.enemies)
	storm._current_view(0.0)
	storm.form.fire()
	result.burst["stormblade"] = {"left": storm.gun_burst_left, "fired": _active_projectiles(), "muzzles": storm.gun_muzzles.size()}
	_clear()
	for base in BASES:
		var forms: Array[String] = []
		forms.append_array(TurretEvolution.options(base, 0))
		forms.append_array(TurretEvolution.options(base, 1))
		for form in forms:
			if not TurretEvolution.is_implemented(form):
				continue
			var turret := _turret(base, form)
			var numbers := ShopViewData._actor_numbers(turret)
			var row := {"dps": "%.4f" % ShopViewData._actor_dps(turret), "burst_size": numbers.burst_size,
				"damage": "%.4f" % numbers.damage, "range": "%.4f" % numbers.range, "fire_rate": "%.4f" % numbers.fire_rate,
				"rotation_rate": "%.4f" % numbers.rotation_rate, "area": "%.4f" % numbers.area}
			if form == "stormblade":
				var gun := ShopViewData._actor_numbers(turret, true)
				row["gun"] = {"burst_size": gun.burst_size, "damage": "%.4f" % gun.damage, "range": "%.4f" % gun.range, "fire_rate": "%.4f" % gun.fire_rate}
			result.shop[form] = row
			_clear()
	return result

func _assert_same(actual: Variant, expected: Variant, label: String) -> void:
	if actual is Dictionary and expected is Dictionary:
		for key in expected:
			if not actual.has(key):
				fail_test("%s: missing key %s" % [label, key])
			else:
				_assert_same(actual[key], expected[key], "%s.%s" % [label, key])
		for key in actual:
			if not expected.has(key):
				fail_test("%s: unexpected key %s = %s" % [label, key, actual[key]])
	elif typeof(actual) != typeof(expected) or actual != expected:
		fail_test("%s: expected %s but got %s" % [label, expected, actual])
	else:
		pass_test("%s matches" % label)

func _assert_section(section: String, expected: Dictionary) -> void:
	_assert_same(_recorded[section], expected, section)

func test_rotor_spool_ceiling_and_rates_per_machine_gun_form() -> void:
	_assert_section("spool", SPOOL)

func test_resonator_echo_queues_per_form() -> void:
	_assert_section("echoes", ECHOES)

func test_repeater_volleys_per_form() -> void:
	_assert_section("volley", VOLLEY)

func test_thunder_spear_strikes_its_lane_only() -> void:
	_assert_section("lane", LANE)

func test_omnifire_fires_from_every_exit() -> void:
	_assert_section("omnifire", OMNIFIRE)

func test_stormblade_queues_two_follow_up_shots() -> void:
	_assert_section("burst", BURST)

func test_shop_dps_and_burst_estimates_per_implemented_form() -> void:
	_assert_section("shop", SHOP)
