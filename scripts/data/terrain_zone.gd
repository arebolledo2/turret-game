class_name TerrainZone
extends RefCounted

## One patch of ground with a rule. Positions are on the arena plane (x, z) in metres.
const HIGH_GROUND: String = "high_ground"
const MUD: String = "mud"
const NO_BUILD: String = "no_build"
const POWER_NODE: String = "power_node"

## `strength` meaning per type: high ground = range bonus, mud = enemy and hero slow, power node = Entrench speed bonus.
## No-build has no strength.
## `color` is the readable palette (blue, murky olive, hazard orange, violet: four distinct hues, none of them damage red).
## `legacy_color` is the original flat tint, kept for the `zone_readability` flag when it is off.
## `kind` selects the ground pattern in `zone_ground.gdshader`; `base`/`accent`/`fill` feed it.
const TYPES: Dictionary = {
	HIGH_GROUND: {"name": "High ground", "color": Color("5ab0ff"), "legacy_color": Color("6fd6ff"), "kind": 0,
		"base": Color("1f5d96"), "accent": Color("9bd4ff"), "fill": .26,
		"strength": GameConstants.ZONE_HIGH_GROUND_RANGE_BONUS, "summary": "turrets +%d%% range"},
	MUD: {"name": "Mud", "color": Color("8f8a3c"), "legacy_color": Color("8aa63a"), "kind": 1,
		"base": Color("2a2a12"), "accent": Color("6e6a2c"), "fill": .5,
		"strength": GameConstants.ZONE_MUD_SLOW, "summary": "slows you and enemies %d%%"},
	NO_BUILD: {"name": "No-build", "color": Color("ff9a2e"), "legacy_color": Color("ff5a5a"), "kind": 2,
		"base": Color("e0801c"), "accent": Color("ffd08a"), "fill": .26,
		"strength": 0.0, "summary": "turrets cannot be placed"},
	POWER_NODE: {"name": "Power node", "color": Color("b98aff"), "legacy_color": Color("d6ff4a"), "kind": 3,
		"base": Color("3a2670"), "accent": Color("e6d4ff"), "fill": .3,
		"strength": GameConstants.ZONE_POWER_NODE_ENTRENCH_BONUS, "summary": "Entrench stacks %d%% faster"},
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

func legacy_color() -> Color:
	return TYPES[type]["legacy_color"]

func title() -> String:
	return str(TYPES[type]["name"])

## What the zone does, in a few words ("turrets +25% range").
func detail() -> String:
	var summary := str(TYPES[type]["summary"])
	if "%d" in summary:
		summary = summary % roundi(strength * 100.0)
	return summary

func label() -> String:
	return "%s: %s" % [title(), detail()]

## Gap in metres between a point and the zone's edge (0 inside).
func distance_to(x: float, z: float) -> float:
	var dx := x - centre.x
	var dz := z - centre.y
	if is_circle:
		return maxf(0.0, sqrt(dx * dx + dz * dz) - radius)
	return Vector2(maxf(absf(dx) - half_extents.x, 0.0), maxf(absf(dz) - half_extents.y, 0.0)).length()

## Distance from the arena origin to the nearest point of this zone (negative when it covers the origin).
func clearance_from_origin() -> float:
	if is_circle:
		return centre.length() - radius
	var outside := Vector2(maxf(absf(centre.x) - half_extents.x, 0.0), maxf(absf(centre.y) - half_extents.y, 0.0))
	return outside.length()
