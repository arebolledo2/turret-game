class_name Drones
extends Node3D

## Engine piece S10: the drones flying in the arena (the Drone Bay's, and whatever later turret sends small actors about). A turret
## builds a `Drone`, hands it to `launch`, and sets its mode as the fight changes (see `Drone.Mode`); this class runs the rest:
## the flight, the airframe's age, the hover and the drawing. Nothing here knows which turret it is, and nothing here shoots:
## damage is the owner's, built and delivered like any other turret hit (`Combat3D.impact`), so crits, Exposed, Marked, burn,
## item multipliers and kill credit all apply.
##
## Cost and bounds:
##   - at most `GameConstants.DRONE_MAX` live at once across the arena, and a drone may carry a cap of its own (`owner_cap`, the
##     most its owner may have out): `launch` refuses beyond either, so one bay can never push another's drones out and a swarm that
##     breeds extras (Reaper Swarm) cannot grow without bound;
##   - a tick does nothing when the list is empty; otherwise it is one pass over at most that many drones, each a few vector
##     operations. No drone queries the crowd, the enemy list or the scene tree: the owners do their own looking, a few times a
##     second;
##   - all drones are drawn by one `MultiMeshInstance3D` whose instance count is fixed at the cap, so a drone is a slot in a buffer,
##     never a node.
## Lifetime: time passes only in combat. Everything is dropped the moment combat stops (wave end, pause, defeat), by `clear_field`
## and on a run reset, and `clear_owner` drops one turret's when it is removed, evolves or sees combat stop. A drone cannot be hurt;
## it goes when its owner takes it down or its airframe (`life`) wears out, and the owner replaces it from its slot.
const BODY_RADIUS: float = .13
const ARM_LENGTH: float = .46
## A drone is within this many metres of its goal when it counts as having arrived (docking, sorties).
const ARRIVE_DISTANCE: float = .2
## Speed falls off inside this many metres of the goal, so a drone settles instead of overshooting.
const SETTLE_DISTANCE: float = .8
const MARGIN: float = .35

var world: ArenaWorld
var items: Array[Drone] = []
var multimesh: MultiMesh
var instance: MultiMeshInstance3D
## Run counters (tests and tools read them).
var launched: int = 0
var lost: int = 0
var _owner_counts: Dictionary = {}

func _init() -> void:
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = body_mesh()
	multimesh.instance_count = GameConstants.DRONE_MAX
	multimesh.visible_instance_count = 0
	instance = MultiMeshInstance3D.new()
	instance.name = "DroneSwarm"
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.custom_aabb = AABB(Vector3(-40, -2, -40), Vector3(80, 6, 80))
	instance.material_override = _material()
	add_child(instance)

func count() -> int:
	return items.size()

func has_drones() -> bool:
	return not items.is_empty()

## How many of `owner_id`'s drones are out.
func count_of(owner_id: int) -> int:
	return int(_owner_counts.get(owner_id, 0))

func of_owner(owner_id: int) -> Array[Drone]:
	var found: Array[Drone] = []
	for drone in items:
		if drone.owner_id == owner_id:
			found.append(drone)
	return found

## Puts `drone` into the arena. False (and nothing launched) when the arena is full or its owner has its cap out.
func launch(drone: Drone) -> bool:
	if items.size() >= GameConstants.DRONE_MAX:
		return false
	if drone.owner_cap > 0 and count_of(drone.owner_id) >= drone.owner_cap:
		return false
	drone.spent = false
	drone.age = 0.0
	drone.velocity = Vector3.ZERO
	items.append(drone)
	_owner_counts[drone.owner_id] = count_of(drone.owner_id) + 1
	launched += 1
	_draw(drone, items.size() - 1)
	multimesh.visible_instance_count = items.size()
	return true

## Takes `drone` out. `worn_out` counts it as lost (its airframe gave out or the owner scrapped it) rather than merely cleared.
func destroy(drone: Drone, worn_out: bool = false) -> void:
	if drone.spent:
		return
	drone.spent = true
	drone.target = null
	items.erase(drone)
	var left := count_of(drone.owner_id) - 1
	if left > 0:
		_owner_counts[drone.owner_id] = left
	else:
		_owner_counts.erase(drone.owner_id)
	if worn_out:
		lost += 1
	multimesh.visible_instance_count = items.size()

## Drops everything (combat stopped, a new run).
func clear() -> void:
	if items.is_empty():
		return
	for drone: Drone in items.duplicate():
		destroy(drone)

## Drops what one turret sent up. Returns at once when it has nothing out, so a form may call it every idle frame.
func clear_owner(owner_id: int) -> void:
	if items.is_empty() or not _owner_counts.has(owner_id):
		return
	for drone: Drone in items.duplicate():
		if drone.owner_id == owner_id:
			destroy(drone)

func _physics_process(delta: float) -> void:
	if world != null and not world.is_combat():
		clear()
		return
	tick(delta)

# --- Per tick ---

func tick(delta: float) -> void:
	if items.is_empty():
		return
	var index := items.size() - 1
	while index >= 0:
		var drone := items[index]
		drone.age += delta
		if drone.life > 0.0 and drone.age >= drone.life:
			if world != null and world.effects != null:
				world.effects.show_burst(Vector3(drone.position.x, drone.height(), drone.position.z), "ion")
			destroy(drone, true)
		else:
			_fly(drone, delta)
		index -= 1
	for slot in items.size():
		_draw(items[slot], slot)

func _fly(drone: Drone, delta: float) -> void:
	var cruise := drone.dock_height if drone.mode == Drone.Mode.DOCKED else Drone.HEIGHT
	drone.altitude = move_toward(drone.altitude, cruise, Drone.CLIMB_RATE * delta)
	if drone.mode == Drone.Mode.DOCKED:
		drone.position = drone.home
		drone.velocity = Vector3.ZERO
		return
	var goal := goal_of(drone, delta)
	var offset := WorldGeometry.planar(goal - drone.position)
	var distance := offset.length()
	if drone.mode == Drone.Mode.RETURN and distance <= ARRIVE_DISTANCE:
		drone.position = drone.home
		drone.velocity = Vector3.ZERO
		drone.mode = Drone.Mode.DOCKED
		return
	var wanted := Vector3.ZERO
	if distance > .001:
		wanted = offset / distance * minf(drone.speed, drone.speed * distance / SETTLE_DISTANCE)
	drone.velocity = drone.velocity.move_toward(wanted, drone.accel * delta)
	drone.position = WorldGeometry.clamp_position(drone.position + drone.velocity * delta, MARGIN)
	if drone.has_target() and drone.mode == Drone.Mode.HOLD:
		var look := WorldGeometry.planar(drone.target.position - drone.position)
		if look.length_squared() > .0001:
			drone.yaw = atan2(-look.x, -look.z)
	elif drone.velocity.length_squared() > .25:
		drone.yaw = atan2(-drone.velocity.x, -drone.velocity.z)

## The planar point `drone` is steering toward this step (advances an orbit, and a strafing run's drift).
func goal_of(drone: Drone, delta: float) -> Vector3:
	match drone.mode:
		Drone.Mode.SEEK:
			return drone.point
		Drone.Mode.ORBIT:
			drone.orbit_angle = fposmod(drone.orbit_angle + drone.orbit_rate * delta, TAU)
			return drone.anchor + Vector3(cos(drone.orbit_angle), 0.0, sin(drone.orbit_angle)) * drone.orbit_radius
		Drone.Mode.HOLD:
			if not drone.has_target():
				return drone.position
			var from_enemy := WorldGeometry.planar(drone.position - drone.target.position)
			if from_enemy.length_squared() < .0001:
				from_enemy = Vector3(cos(drone.orbit_angle), 0.0, sin(drone.orbit_angle))
			# Round the target, not onto it: the drone sits on its own side and slowly circles.
			var angle := atan2(from_enemy.z, from_enemy.x) + drone.orbit_rate * .25 * delta
			return WorldGeometry.planar(drone.target.position) + Vector3(cos(angle), 0.0, sin(angle)) * drone.hold_distance
		Drone.Mode.RETURN:
			return drone.home
	return drone.position

# --- Visual ---

func _draw(drone: Drone, slot: int) -> void:
	var lift := drone.height()
	# Lean into the flight a little, so a drone reads as moving (reduced motion keeps it level).
	var lean := 0.0 if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION) else clampf(drone.velocity.length() / maxf(drone.speed, .1), 0.0, 1.0) * .25
	var basis := Basis(Vector3.UP, drone.yaw) * Basis(Vector3.RIGHT, -lean)
	multimesh.set_instance_transform(slot, Transform3D(basis, Vector3(drone.position.x, lift, drone.position.z)))
	multimesh.set_instance_color(slot, drone.tint)

static var _shared_mesh: ArrayMesh
static var _shared_material: StandardMaterial3D

## A flattened body, two crossed arms with a rotor pad at each end, and a nose: about 150 triangles, shared by every drone.
static func body_mesh() -> ArrayMesh:
	if _shared_mesh:
		return _shared_mesh
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := SphereMesh.new()
	body.radius = BODY_RADIUS
	body.height = BODY_RADIUS * 2.0
	body.radial_segments = 10
	body.rings = 5
	builder.append_from(body, 0, Transform3D(Basis.from_scale(Vector3(1.0, .5, 1.25)), Vector3.ZERO))
	for yaw: float in [PI * .25, -PI * .25]:
		var arm := BoxMesh.new()
		arm.size = Vector3(ARM_LENGTH, .025, .035)
		builder.append_from(arm, 0, Transform3D(Basis(Vector3.UP, yaw), Vector3(0, .01, 0)))
		for end: float in [-1.0, 1.0]:
			var pad := CylinderMesh.new()
			pad.top_radius = .09
			pad.bottom_radius = .09
			pad.height = .012
			pad.radial_segments = 8
			pad.rings = 1
			builder.append_from(pad, 0, Transform3D(Basis.IDENTITY, Vector3(cos(yaw) * end * ARM_LENGTH * .5, .045, -sin(yaw) * end * ARM_LENGTH * .5)))
	var nose := BoxMesh.new()
	nose.size = Vector3(.06, .05, .14)
	builder.append_from(nose, 0, Transform3D(Basis.IDENTITY, Vector3(0, -.01, -BODY_RADIUS * 1.3)))
	builder.generate_normals()
	_shared_mesh = builder.commit()
	return _shared_mesh

static func _material() -> StandardMaterial3D:
	if not _shared_material:
		_shared_material = StandardMaterial3D.new()
		_shared_material.vertex_color_use_as_albedo = true
		_shared_material.roughness = .45
		_shared_material.metallic = .3
		_shared_material.emission_enabled = true
		_shared_material.emission = Color(.35, .5, .55)
		_shared_material.emission_energy_multiplier = .6
	return _shared_material
