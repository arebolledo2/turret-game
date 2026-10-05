class_name TerrainZone
extends RefCounted

## One patch of ground with a rule. Positions are on the arena plane (x, z) in metres.
const HIGH_GROUND: String = "high_ground"
const MUD: String = "mud"
const NO_BUILD: String = "no_build"
const POWER_NODE: String = "power_node"

## `strength` meaning per type: high ground = range bonus, mud = enemy and hero slow, power node = Entrench speed bonus.
## No-build has no strength.
const TYPES: Dictionary = {
	HIGH_GROUND: {"name": "High ground", "color": Color("6fd6ff"), "strength": GameConstants.ZONE_HIGH_GROUND_RANGE_BONUS,
		"summary": "turrets +%d%% range"},
	MUD: {"name": "Mud", "color": Color("8aa63a"), "strength": GameConstants.ZONE_MUD_SLOW,
		"summary": "movement -%d%%"},
	NO_BUILD: {"name": "No-build", "color": Color("ff5a5a"), "strength": 0.0, "summary": "turrets cannot be placed"},
	POWER_NODE: {"name": "Power node", "color": Color("d6ff4a"), "strength": GameConstants.ZONE_POWER_NODE_ENTRENCH_BONUS,
		"summary": "Entrench stacks %d%% faster"},
}

var type: String = MUD
var is_circle: bool = true
var centre: Vector2 = Vector2.ZERO
var radius: float = 3.0
var half_extents: Vector2 = Vector2(3, 3)
var strength: float = 0.0

static func circle(zone_type: String, x: float, z: float, zone_radius: float, zone_strength: float = -1.0) -> TerrainZone:
	var zone := TerrainZone.new()
	zone.type = zone_type
	zone.centre = Vector2(x, z)
	zone.radius = zone_radius
	zone.half_extents = Vector2(zone_radius, zone_radius)
	zone.strength = zone_strength if zone_strength >= 0.0 else float(TYPES[zone_type]["strength"])
	return zone

static func rect(zone_type: String, x: float, z: float, half_x: float, half_z: float, zone_strength: float = -1.0) -> TerrainZone:
	var zone := TerrainZone.circle(zone_type, x, z, maxf(half_x, half_z), zone_strength)
	zone.is_circle = false
	zone.half_extents = Vector2(half_x, half_z)
	return zone

func contains(x: float, z: float) -> bool:
	var dx := x - centre.x
	var dz := z - centre.y
	if is_circle:
		return dx * dx + dz * dz <= radius * radius
	return absf(dx) <= half_extents.x and absf(dz) <= half_extents.y

func color() -> Color:
	return TYPES[type]["color"]

func label() -> String:
	var summary := str(TYPES[type]["summary"])
	if "%d" in summary:
		summary = summary % roundi(strength * 100.0)
	return "%s: %s" % [TYPES[type]["name"], summary]

## Distance from the arena origin to the nearest point of this zone (negative when it covers the origin).
func clearance_from_origin() -> float:
	if is_circle:
		return centre.length() - radius
	var outside := Vector2(maxf(absf(centre.x) - half_extents.x, 0.0), maxf(absf(centre.y) - half_extents.y, 0.0))
	return outside.length()
