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
			TerrainZone.circle(N, -9, 7, 2.5), TerrainZone.circle(N, 9, -7, 2.5),
			TerrainZone.circle(P, -17, 10, 2.2), TerrainZone.circle(P, 18, -10, 2.2),
		]},
		{"id": "highlands", "name": "Highlands", "theme": "concrete", "zones": [
			TerrainZone.rect(H, -19, 0, 3.0, 5.0), TerrainZone.circle(H, 19, -9, 3.0),
			TerrainZone.rect(M, 0, -11, 9.0, 1.8), TerrainZone.rect(M, 0, 11, 9.0, 1.8),
			TerrainZone.circle(N, 12, 4, 3.0), TerrainZone.circle(N, -12, -4, 3.0),
			TerrainZone.circle(P, -10, -12, 2.0), TerrainZone.circle(P, 10, 12, 2.0),
		]},
		{"id": "sump", "name": "The Sump", "theme": "grating", "zones": [
			TerrainZone.circle(M, -12, -6, 4.0), TerrainZone.circle(M, 12, 6, 4.0), TerrainZone.circle(M, 0, 12.5, 3.0),
			TerrainZone.circle(M, 0, -12.5, 3.0), TerrainZone.circle(M, 21, -8, 3.0),
			TerrainZone.circle(H, -20, 9, 3.0), TerrainZone.circle(H, 21, 10, 2.8),
			TerrainZone.circle(N, -6, 8.5, 2.5), TerrainZone.circle(N, 6, -8.5, 2.5),
			TerrainZone.circle(P, -22, -7, 2.2), TerrainZone.circle(P, 13, 0, 2.2),
		]},
		{"id": "hive", "name": "The Hive", "theme": "hexworks", "zones": [
			TerrainZone.circle(H, -16, 9, 3.0), TerrainZone.circle(H, 17, -9, 3.0),
			TerrainZone.circle(M, -8, -11, 3.2), TerrainZone.circle(M, 8, 11.5, 3.2), TerrainZone.circle(M, 22, 6, 2.8),
			TerrainZone.circle(N, 13, -7, 2.8), TerrainZone.circle(N, -13, 6, 2.4),
			TerrainZone.circle(P, -21, -8, 2.2), TerrainZone.circle(P, 4, 12.5, 2.0),
		]},
		{"id": "parlour", "name": "The Parlour", "theme": "marquetry", "zones": [
			TerrainZone.rect(H, 0, -12, 4.0, 2.0), TerrainZone.circle(H, 20, 9, 2.8),
			TerrainZone.rect(M, -17, 0, 2.0, 5.5), TerrainZone.rect(M, 17, -2, 2.0, 5.0),
			TerrainZone.circle(N, -8, 9, 2.6), TerrainZone.circle(N, 8, 8, 2.6),
			TerrainZone.circle(P, -23, 10, 2.0), TerrainZone.circle(P, 24, -10, 2.0),
		]},
		{"id": "observatory", "name": "The Observatory", "theme": "orrery", "zones": [
			TerrainZone.circle(H, -14, -9, 3.4), TerrainZone.circle(H, 14, 9, 3.4),
			TerrainZone.circle(M, 14, -9, 3.4), TerrainZone.circle(M, -14, 9, 3.4),
			TerrainZone.circle(N, 0, 12, 2.4), TerrainZone.circle(N, 0, -12, 2.4),
			TerrainZone.circle(P, -24, 0, 2.2), TerrainZone.circle(P, 24, 0, 2.2),
		]},
		{"id": "bathhouse", "name": "The Bathhouse", "theme": "mosaic", "zones": [
			TerrainZone.rect(M, -14, -9, 6.0, 2.0), TerrainZone.rect(M, 14, 9, 6.0, 2.0), TerrainZone.circle(M, 0, 12.5, 3.0),
			TerrainZone.circle(H, -21, 10, 3.0), TerrainZone.circle(H, 21, -10, 3.0),
			TerrainZone.circle(N, 7, -9, 2.6), TerrainZone.circle(N, -7, 9, 2.6),
			TerrainZone.circle(P, -22, -8, 2.0), TerrainZone.circle(P, 23, 9, 2.0),
		]},
		{"id": "glacier", "name": "The Glacier", "theme": "frost", "zones": [
			TerrainZone.circle(H, -19, -6, 3.6), TerrainZone.circle(H, 8, 10, 3.0),
			TerrainZone.circle(M, 14, -6, 4.0), TerrainZone.circle(M, -10, 8, 3.2), TerrainZone.circle(M, 0, -12.5, 2.8),
			TerrainZone.circle(N, -6, -9, 2.6), TerrainZone.circle(N, 18, 8, 2.6),
			TerrainZone.circle(P, -23, 9, 2.2), TerrainZone.circle(P, 14, 3, 2.2),
		]},
	]

	for entry in layouts:
		for zone: TerrainZone in entry["zones"]:
			# Positions follow the narrowed width; sizes only follow the uniform scale so circles stay round.
			zone.centre = Vector2(zone.centre.x * WorldGeometry.ARENA_WIDTH_SCALE, zone.centre.y) * WorldGeometry.ARENA_LINEAR_SCALE
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
