class_name Deployables
extends Node3D

## Engine piece S8: the deployables standing in the arena (the Mine Layer's mines and limpets, and whatever later turret leaves
## things on the floor). A turret builds a `Deployable`, hands it to `lay`, and this class runs the rest: arming, the trigger,
## the blast, chaining, re-arming, limpets, lifetime and the visual. Nothing here knows which turret it is.
##
## Cost and bounds:
##   - at most `GameConstants.DEPLOYABLE_MAX` live at once across the arena (`lay` refuses beyond it, so one layer can never push
##     another's out), and a turret caps its own with `count_of`;
##   - a tick does nothing when the list is empty; otherwise it is one pass over at most that many, and an armed mine asks the
##     crowd grid (the one the wave director rebuilds every tick) for enemies in its cells, never the whole enemy list;
##   - at most `MAX_BLASTS_PER_TICK` blasts go off in a tick (the rest wait one tick), and a chain only marks mines that are
##     armed, once each, `depth` links deep, so it ends: every mine blasts at most once per chain, and a limpet's blast sticks
##     new limpets only when it is a first-generation one;
##   - visuals are pooled `MeshInstance3D`s built on demand up to the cap.
## Blasts hit enemies only (`Combat3D.impact` is handed the crowd's enemies): the hero and turrets are never candidates.
## Lifetime: time passes only in combat. Everything is dropped the moment combat stops (wave end, pause, defeat), by
## `clear_field` and on a run reset, and `clear_owner` drops one turret's when it is picked up, removed or evolves.
const HEIGHT: float = .05
## Seconds between a mine setting off its neighbour and the neighbour going off: the chain reads as a ripple, and a long
## chain is spread over frames instead of landing in one.
const CHAIN_FUSE_SECONDS: float = .12
const MAX_BLASTS_PER_TICK: int = 8
## A limpet has arrived when it is this close to its host (metres).
const ARRIVE_DISTANCE: float = .2
const MINE_RADIUS: float = .17
const LIMPET_RADIUS: float = .13
## Height of a limpet on its host as a share of the host's body scale.
const LIMPET_HEIGHT: float = .75
const ARMING_COLOUR := Color("5a4a1c")
const FUSED_COLOUR := Color("fff0c8")
static var mine_mesh: CylinderMesh
static var limpet_mesh: SphereMesh

var world: ArenaWorld
var items: Array[Deployable] = []
## Every visual built so far, and the ones not currently showing a deployable.
var nodes: Array[MeshInstance3D] = []
var idle: Array[MeshInstance3D] = []
## Run counters (tests and tools read them).
var blasts: int = 0
var laid: int = 0
var _owner_counts: Dictionary = {}
var _riders: Dictionary = {}
var _blasts_left: int = 0

func has_deployables() -> bool:
	return not items.is_empty()

func count() -> int:
	return items.size()

## How many of `owner_id`'s own deployables are out (the ones that count toward its cap; sticky children do not).
func count_of(owner_id: int) -> int:
	return int(_owner_counts.get(owner_id, 0))

## Everything `owner_id` has out, children included.
func of_owner(owner_id: int) -> Array[Deployable]:
	var found: Array[Deployable] = []
	for item in items:
		if item.owner_id == owner_id:
			found.append(item)
	return found

## True when a limpet already rides `enemy`.
func is_ridden(enemy: CombatActor) -> bool:
	return is_instance_valid(enemy) and _riders.has(enemy.get_instance_id())

## Puts `item` into the arena. False (and nothing laid) when the arena is full. Mines are kept inside the arena.
func lay(item: Deployable) -> bool:
	if items.size() >= GameConstants.DEPLOYABLE_MAX:
		return false
	if item.state == Deployable.State.ARMING:
		item.timer = item.arm_seconds
	if not item.is_limpet():
		item.position = WorldGeometry.clamp_position(item.position)
	item.node = _take_node(item)
	items.append(item)
	laid += 1
	if item.counts_toward_cap():
		_owner_counts[item.owner_id] = count_of(item.owner_id) + 1
	if item.is_limpet() and is_instance_valid(item.host):
		item.rider_id = item.host.get_instance_id()
		_riders[item.rider_id] = int(_riders.get(item.rider_id, 0)) + 1
	_paint(item)
	_place(item)
	return true

## Takes `item` out without a blast.
func remove(item: Deployable) -> void:
	if item.spent:
		return
	item.spent = true
	items.erase(item)
	if item.counts_toward_cap():
		var left := count_of(item.owner_id) - 1
		if left > 0:
			_owner_counts[item.owner_id] = left
		else:
			_owner_counts.erase(item.owner_id)
	if item.rider_id != 0:
		var riding := int(_riders.get(item.rider_id, 0)) - 1
		if riding > 0:
			_riders[item.rider_id] = riding
		else:
			_riders.erase(item.rider_id)
		item.rider_id = 0
	if item.node:
		item.node.visible = false
		idle.append(item.node)
		item.node = null

## Drops everything (combat stopped, a new run).
func clear() -> void:
	if items.is_empty():
		return
	for item: Deployable in items.duplicate():
		remove(item)

## Drops what one turret laid. Returns at once when it has nothing out, so a form may call it every idle frame.
func clear_owner(owner_id: int) -> void:
	if items.is_empty():
		return
	for item: Deployable in items.duplicate():
		if item.owner_id == owner_id:
			remove(item)

func _physics_process(delta: float) -> void:
	if world != null and not world.is_combat():
		clear()
		return
	tick(delta)

# --- Per tick ---

func tick(delta: float) -> void:
	if items.is_empty():
		return
	_blasts_left = MAX_BLASTS_PER_TICK
	var grid := world.crowd
	# A snapshot: a blast may lay limpets and a kill may remove deployables while the pass runs.
	for item: Deployable in items.duplicate():
		if item.spent:
			continue
		item.age += delta
		if item.lifetime > 0.0 and item.age >= item.lifetime and item.state != Deployable.State.FUSED:
			remove(item)
			continue
		match item.state:
			Deployable.State.ARMING:
				item.timer -= delta
				if item.timer <= 0.0:
					item.state = Deployable.State.ARMED
			Deployable.State.ARMED:
				if grid.any_within(item.position, item.trigger_radius):
					_set_off(item)
			Deployable.State.FLYING:
				_fly(item, delta)
		if item.state == Deployable.State.FUSED:
			_burn(item, delta)
		if not item.spent:
			_paint(item)
			_place(item)
			_animate(item)

## An enemy stepped on it: it goes off this tick, and its blast may pass on `chain_depth` links.
func _set_off(item: Deployable) -> void:
	item.links_left = item.chain_depth
	item.state = Deployable.State.FUSED
	item.timer = 0.0

func _fly(item: Deployable, delta: float) -> void:
	if not item.is_live_host():
		# Its target is gone: it lands where it is and burns.
		item.host = null
		item.state = Deployable.State.FUSED
		item.timer = item.fuse_seconds
		return
	var offset := WorldGeometry.planar(item.host.position - item.position)
	var step := item.speed * delta
	if offset.length() <= step + ARRIVE_DISTANCE:
		item.position = item.host.position
		item.state = Deployable.State.FUSED
		item.timer = item.fuse_seconds
	else:
		item.position += offset.normalized() * step

func _burn(item: Deployable, delta: float) -> void:
	if item.is_limpet() and item.host != null:
		if item.is_live_host():
			item.position = item.host.position
		else:
			# Its host died: it goes off now.
			item.timer = 0.0
	item.timer -= delta
	if item.timer <= 0.0 and _blasts_left > 0:
		_detonate(item)

func _detonate(item: Deployable) -> void:
	_blasts_left -= 1
	blasts += 1
	var struck := world.crowd.query_radius(item.position, item.shot.splash_radius, true)
	world.combat.impact(null, item.position, Vector3(0, 0, -1), item.shot, struck)
	if item.links_left > 0:
		_pass_on(item)
	if item.stick_count > 0 and item.generation == 0:
		_stick_children(item, struck)
	if item.rearm_seconds > 0.0 and not item.is_limpet():
		item.state = Deployable.State.ARMING
		item.timer = item.rearm_seconds
	else:
		remove(item)

## Sets off the armed mines of the same layer within reach of this blast, one link shorter and a beat later.
func _pass_on(item: Deployable) -> void:
	var reach := item.chain_reach * item.chain_reach
	for other: Deployable in items:
		if other == item or other.spent or other.owner_id != item.owner_id or not other.is_armed():
			continue
		if WorldGeometry.planar(other.position - item.position).length_squared() <= reach:
			other.links_left = item.links_left - 1
			other.state = Deployable.State.FUSED
			other.timer = CHAIN_FUSE_SECONDS

## Sticks a new limpet on up to `stick_count` of the enemies this blast left standing, nearest to its centre first. The new ones
## stick no further, so a launch makes at most `1 + stick_count` blasts.
func _stick_children(item: Deployable, struck: Array[CombatActor]) -> void:
	var candidates: Array[CombatActor] = []
	for enemy in struck:
		if is_instance_valid(enemy) and not enemy.dead and enemy != item.host and not is_ridden(enemy) \
				and enemy.overlaps_attack_range(item.position, item.shot.splash_radius):
			candidates.append(enemy)
	candidates.sort_custom(func(a: CombatActor, b: CombatActor) -> bool:
		return WorldGeometry.planar(a.position - item.position).length_squared() < WorldGeometry.planar(b.position - item.position).length_squared())
	for index in mini(item.stick_count, candidates.size()):
		var child := Deployable.new()
		child.kind = Deployable.KIND_LIMPET
		child.state = Deployable.State.FLYING
		child.owner_id = item.owner_id
		child.position = item.position
		child.shot = item.shot.copy()
		child.host = candidates[index]
		child.fuse_seconds = item.fuse_seconds
		child.speed = item.speed
		child.generation = item.generation + 1
		child.tint = item.tint
		if not lay(child):
			return

# --- Visual ---

func _take_node(item: Deployable) -> MeshInstance3D:
	var instance: MeshInstance3D
	if not idle.is_empty():
		instance = idle.pop_back()
	else:
		instance = MeshInstance3D.new()
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.material_override = StandardMaterial3D.new()
		add_child(instance)
		nodes.append(instance)
	instance.mesh = _limpet_mesh() if item.is_limpet() else _mine_mesh()
	instance.visible = true
	return instance

static func _mine_mesh() -> CylinderMesh:
	if not mine_mesh:
		mine_mesh = CylinderMesh.new()
		mine_mesh.top_radius = MINE_RADIUS * .8
		mine_mesh.bottom_radius = MINE_RADIUS
		mine_mesh.height = .09
		mine_mesh.radial_segments = 14
		mine_mesh.rings = 1
	return mine_mesh

static func _limpet_mesh() -> SphereMesh:
	if not limpet_mesh:
		limpet_mesh = SphereMesh.new()
		limpet_mesh.radius = LIMPET_RADIUS
		limpet_mesh.height = LIMPET_RADIUS * 2.0
		limpet_mesh.radial_segments = 12
		limpet_mesh.rings = 6
	return limpet_mesh

## Recolours the visual when the state changed: dark while arming, the item's colour armed, white-hot once fused.
func _paint(item: Deployable) -> void:
	if not item.node or item.drawn_state == int(item.state):
		return
	item.drawn_state = int(item.state)
	var material := item.node.material_override as StandardMaterial3D
	var colour := item.tint
	var glow := 1.0
	match item.state:
		Deployable.State.ARMING:
			colour = ARMING_COLOUR
			glow = .25
		Deployable.State.FUSED:
			colour = FUSED_COLOUR
			glow = 3.0
	material.albedo_color = colour
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = glow

func _place(item: Deployable) -> void:
	if not item.node:
		return
	var lift := HEIGHT
	if item.is_limpet() and is_instance_valid(item.host):
		lift = LIMPET_HEIGHT * item.host.body_scale
	item.node.position = Vector3(item.position.x, lift, item.position.z)

## An armed mine breathes a little so it reads as live; a fused one swells. Reduced motion keeps everything still.
func _animate(item: Deployable) -> void:
	if not item.node:
		return
	var pulse := 1.0
	if not FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION):
		if item.state == Deployable.State.ARMED:
			pulse = 1.0 + .08 * sin(item.age * 6.0)
		elif item.state == Deployable.State.FUSED:
			pulse = 1.0 + .25 * sin(item.age * 30.0)
	item.node.scale = Vector3.ONE * pulse
