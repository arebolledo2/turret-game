class_name DroneDock
extends RefCounted

## Where a Drone Bay's drones rest: the geometry of its parking dishes, floor pads and fallback ring, and the parked drones the
## chassis model carries. Pure functions of the model and the slot; `DroneBayForm` keeps the per-bay cache.
## The cp_drone_bay chassis carries two parking dishes (`Drone_Wire` and `Drone_Arm`, the empties its two parked drones hang from):
## the first two slots dock on them, at `PERCH_LIFT` above the empty, and the model's own drone body on a dish is hidden while a real
## drone holds that slot (so the shop and the idle bay show the parked pair, and combat swaps them for the real ones). Slots past the dishes dock on floor pads in the open front arc of the base, `PAD_RING` from the centre,
## `PAD_SPREAD` radians apart, with the drone's centre `PAD_LIFT` above the floor. Any other chassis uses the plain ring at `DOCK_RADIUS`.
const DOCK_RADIUS: float = .95
const PERCH_NODES: Array[String] = ["Drone_Wire", "Drone_Arm"]
const PARKED_PARTS: Array[String] = ["Teal", "Cream", "Glow", "Props"]
const PERCH_LIFT: float = .06
const FLOOR_HEIGHT: float = .165
const PAD_LIFT: float = .075
const PAD_RING: float = .72
const PAD_SPREAD: float = .9

## Model-space positions of the parking dishes the chassis carries (their drone-centre height in `y`); empty on any other chassis.
static func perches(model: Node3D) -> Array[Vector3]:
	var found: Array[Vector3] = []
	if model == null:
		return found
	for label in PERCH_NODES:
		var node := model.find_child(label, true, false) as Node3D
		if node == null:
			continue
		var at := Vector3.ZERO
		var walk := node
		while walk != null and walk != model:
			at += walk.position
			walk = walk.get_parent() as Node3D
		found.append(at + Vector3(0.0, PERCH_LIFT, 0.0))
	return found

## Where slot `slot` of `count` rests, as an offset from the bay with the drone's centre height in `y`: a dish, a floor pad past the
## dishes, or (a chassis with no dishes) the ring at `DOCK_RADIUS`.
static func dock_offset(dishes: Array[Vector3], slot: int, count: int) -> Vector3:
	if dishes.is_empty():
		var ring := dock_angle(slot, count)
		return Vector3(cos(ring) * DOCK_RADIUS, Drone.DOCK_HEIGHT, sin(ring) * DOCK_RADIUS)
	if slot < dishes.size():
		return dishes[maxi(slot, 0)]
	var pads := maxi(count - dishes.size(), 1)
	var angle := PI * .5 + (float(slot - dishes.size()) - float(pads - 1) * .5) * PAD_SPREAD
	return Vector3(cos(angle) * PAD_RING, FLOOR_HEIGHT + PAD_LIFT, sin(angle) * PAD_RING)

## The mesh nodes of the chassis's own parked drone on dish `index` (its body, dome, glow and propellers; the dish itself stays).
static func parked_drone(model: Node3D, index: int) -> Array[Node3D]:
	var found: Array[Node3D] = []
	if model == null or index < 0 or index >= PERCH_NODES.size():
		return found
	for part in PARKED_PARTS:
		var node := model.find_child("%s_%s" % [PERCH_NODES[index], part], true, false) as Node3D
		if node != null:
			found.append(node)
	return found

## Where slot `slot` of `count` docks, as an angle round the bay (turned off the barrel side so a drone never rests on it).
static func dock_angle(slot: int, count: int) -> float:
	return (float(maxi(slot, 0)) + .5) * TAU / float(maxi(count, 1)) + .6
