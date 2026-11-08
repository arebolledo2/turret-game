class_name ChainForm
extends TurretForm

## Tesla forms. One class serves the Forked Coil, Storm Network, Capacitor and Thunderhead; the rows' `params` pick the parts.
##   fork          the first jump forks in two: after the primary hit, the two nearest unstruck enemies each start a chain
##                 (no enemy is hit twice by one strike). With `shared_budget` the forks split `chain_count` between them;
##                 otherwise each fork gets the full count.
##   meter         a charge meter on the chassis (`ChargeMeter`) that fills while the cooldown runs. A form that charges
##                 simply has a long cooldown and heavy stats; the meter only shows it
##   storm_seconds, storm_interval, storm_share, storm_jumps   Thunderhead: after a strike a storm cloud hangs over the main
##                 target for `storm_seconds`, and every `storm_interval` seconds fires a bounded arc (`storm_jumps` jumps
##                 at `storm_share` of the strike's damage) at the nearest enemy near it. One cloud per turret.
## A Storm Network has several coil heads (`TurretActor.chain_muzzles`) that fire in turn.
## The cloud is dropped by `clear()` when combat stops.
const CLOUD_HEIGHT: float = 1.6
const CLOUD_REACH: float = 2.25
const CLOUD_TINT: Color = Color("6fa8ff")

var head_index: int = -1
## The storm cloud: {"left", "next" (seconds), "at" (ground position), "follow" (CombatActor), "shot", "node"} or empty.
var cloud: Dictionary = {}
var strikes: int = 0
var cloud_arcs: int = 0

func estimate_dps(stats: TurretStats) -> float:
	var dps := stats.damage * stats.fire_rate
	var storm := float(param("storm_seconds", 0.0))
	if storm > 0.0:
		var arcs := floorf(storm / float(param("storm_interval", .5)))
		dps += stats.damage * float(param("storm_share", 0.0)) * arcs * stats.fire_rate
	return dps

func rebuilt() -> void:
	_drop_cloud()

func fire_chain(stats: TurretStats) -> bool:
	var world := actor.world
	var target := actor.target
	var origin := _head_origin()
	world.effects.show_muzzle(origin, GameEnums.DamageType.ELECTRIC)
	var shot := actor._new_shot(stats)
	if bool(param("fork", false)):
		_fork(origin, target, shot, stats)
	else:
		world.combat.chain(origin, target, shot, stats.chain_count, stats.chain_range_metres, stats.chain_decay, world.enemies)
	strikes += 1
	if float(param("storm_seconds", 0.0)) > 0.0:
		_raise_cloud(target, shot)
	actor._reset_cooldown(stats)
	return true

## The muzzle of the head whose turn it is (the chassis muzzle when there is only one).
func _head_origin() -> Vector3:
	var heads := actor.chain_muzzles
	if heads.size() <= 1:
		return actor.muzzle.global_position
	head_index = (head_index + 1) % heads.size()
	return heads[head_index].global_position

func _fork(origin: Vector3, primary: CombatActor, shot: CombatShot3D, stats: TurretStats) -> void:
	var per_fork := stats.chain_count
	if bool(param("shared_budget", false)):
		per_fork = maxi(1, stats.chain_count / 2)
	actor.world.combat.chain_forked(origin, primary, shot, per_fork, stats.chain_range_metres, stats.chain_decay, actor.world.enemies)

# --- Thunderhead's storm cloud ---

func _raise_cloud(main: CombatActor, shot: CombatShot3D) -> void:
	_drop_cloud()
	if not is_instance_valid(main):
		return
	var arc := shot.copy()
	arc.critical = shot.critical
	arc.damage = shot.damage * float(param("storm_share", .35))
	var node := MeshInstance3D.new()
	node.name = "StormCloud"
	var mesh := SphereMesh.new()
	mesh.radius = .9
	mesh.height = .8
	mesh.radial_segments = 20
	mesh.rings = 8
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(.18, .22, .36, .72)
	material.emission_enabled = true
	material.emission = CLOUD_TINT
	material.emission_energy_multiplier = .5
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	node.material_override = material
	node.top_level = true
	actor.add_child(node)
	var ground := WorldGeometry.planar(main.position)
	node.global_position = ground + Vector3(0, CLOUD_HEIGHT, 0)
	cloud = {"left": float(param("storm_seconds", 2.5)), "next": float(param("storm_interval", .5)), "at": ground, "follow": main, "shot": arc, "node": node}

func tick(delta: float) -> void:
	if cloud.is_empty():
		return
	var follow: CombatActor = cloud["follow"]
	if is_instance_valid(follow) and not follow.dead:
		cloud["at"] = WorldGeometry.planar(follow.position)
	var node: Node3D = cloud["node"]
	if is_instance_valid(node):
		node.global_position = (cloud["at"] as Vector3) + Vector3(0, CLOUD_HEIGHT, 0)
	cloud["left"] = float(cloud["left"]) - delta
	cloud["next"] = float(cloud["next"]) - delta
	if float(cloud["next"]) <= 0.0:
		cloud["next"] = float(param("storm_interval", .5))
		_cloud_arc()
	if float(cloud["left"]) <= 0.0:
		_drop_cloud()

func _cloud_arc() -> void:
	var world := actor.world
	var at: Vector3 = cloud["at"]
	var nothing_struck: Array[CombatActor] = []
	var victim := world.combat.nearest_unstruck(at, CLOUD_REACH, nothing_struck, world.enemies)
	if not victim:
		return
	cloud_arcs += 1
	var stats := actor._current_view(0.0)
	world.combat.chain(at + Vector3(0, CLOUD_HEIGHT, 0), victim, cloud["shot"], int(param("storm_jumps", 2)), stats.chain_range_metres, stats.chain_decay, world.enemies)

func _drop_cloud() -> void:
	if not cloud.is_empty():
		var node: Node3D = cloud["node"]
		if is_instance_valid(node):
			node.queue_free()
	cloud = {}

func clear() -> void:
	_drop_cloud()

func removed() -> void:
	_drop_cloud()

# --- Charge meter ---

func tick_mechanisms(_delta: float, _tracking: bool) -> void:
	if not bool(param("meter", false)) or not is_instance_valid(actor.model):
		return
	var meter := actor.model.find_child("ChargeMeter", true, false) as MeshInstance3D
	if meter == null:
		return
	var charge := fposmod(Time.get_ticks_msec() / 1000.0, 1.5) / 1.5 # the showcase turntable has no arena: a looping demo charge
	if actor.world != null:
		var total := maxf(.01, actor._current_view(0.0).cooldown_seconds)
		charge = 1.0 - clampf(actor.cooldown / total, 0.0, 1.0)
	meter.scale = Vector3.ONE * (.35 + .65 * charge)
	var material := meter.material_override as StandardMaterial3D
	if material:
		material.emission_energy_multiplier = .4 + 2.6 * charge
