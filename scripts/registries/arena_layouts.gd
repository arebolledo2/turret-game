class_name ArenaLayouts
extends RefCounted

## Hand-authored terrain layouts in the original 57.6 x 32.4 m reference space, scaled to the current arena. Every zone keeps
## ZONE_CENTRE_CLEARANCE metres clear of the origin, where the hero, the first turret and (in core mode) the core stand.

## id -> {name, theme, zones}; `theme` picks the floor texture set. `random_layout` picks one per run; it stays fixed for every wave of that run.
static func all() -> Array[Dictionary]:
	var H := TerrainZone.HIGH_GROUND
	var M := TerrainZone.MUD
	var N := TerrainZone.NO_BUILD
	var P := TerrainZone.POWER_NODE
	var layouts: Array[Dictionary] = [
		{"id": "crossroads", "name": "Crossroads", "theme": "foundry", "zones": [
			TerrainZone.circle(H, -14, -8, 3.0), TerrainZone.circle(H, 14, 8, 3.0),
			TerrainZone.circle(M, 0, -11.5, 3.5), TerrainZone.circle(M, 0, 11.5, 3.5), TerrainZone.circle(M, -21, 4, 3.0),
			TerrainZone.circle(N, -9, 6.5, 2.5), TerrainZone.circle(N, 9, -6.5, 2.5),
			TerrainZone.circle(P, -17, 10, 2.2), TerrainZone.circle(P, 18, -10, 2.2),
		]},
		{"id": "highlands", "name": "Highlands", "theme": "concrete", "zones": [
			TerrainZone.rect(H, -19, 0, 3.0, 5.0), TerrainZone.circle(H, 19, -9, 3.0),
			TerrainZone.rect(M, 0, -11, 9.0, 1.8), TerrainZone.rect(M, 0, 11, 9.0, 1.8),
			TerrainZone.circle(N, 12, 3.5, 3.0), TerrainZone.circle(N, -12, -3.5, 3.0),
			TerrainZone.circle(P, -10, -12, 2.0), TerrainZone.circle(P, 10, 12, 2.0),
		]},
		{"id": "sump", "name": "The Sump", "theme": "grating", "zones": [
			TerrainZone.circle(M, -12, -6, 4.0), TerrainZone.circle(M, 12, 6, 4.0), TerrainZone.circle(M, 0, 12.5, 3.0),
			TerrainZone.circle(M, 0, -12.5, 3.0), TerrainZone.circle(M, 21, -8, 3.0),
			TerrainZone.circle(H, -20, 9, 3.0), TerrainZone.circle(H, 21, 10, 2.8),
			TerrainZone.circle(N, -6, 8.5, 2.5), TerrainZone.circle(N, 6, -8.5, 2.5),
			TerrainZone.circle(P, -22, -7, 2.2), TerrainZone.circle(P, 10, 0, 2.2),
		]},
	]

	for entry in layouts:
		for zone: TerrainZone in entry["zones"]:
			zone.centre *= WorldGeometry.ARENA_LINEAR_SCALE
			zone.radius *= WorldGeometry.ARENA_LINEAR_SCALE
			zone.half_extents *= WorldGeometry.ARENA_LINEAR_SCALE
	return layouts

static func ids() -> Array[String]:
	var result: Array[String] = []
	for entry in all():
		result.append(str(entry["id"]))
	return result

## The layout with this id, or null.
static func get_layout(layout_id: String) -> ArenaLayout:
	for entry in all():
		if str(entry["id"]) == layout_id:
			return ArenaLayout.from_entry(entry)
	return null

## One layout chosen with `rng` (the gameplay RNG, so seeded runs repeat).
static func random_layout(rng: RandomNumberGenerator) -> ArenaLayout:
	var entries := all()
	return ArenaLayout.from_entry(entries[rng.randi_range(0, entries.size() - 1)])
