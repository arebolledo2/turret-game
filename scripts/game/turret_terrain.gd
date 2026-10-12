class_name TurretTerrain
extends RefCounted

## Terrain under one turret, refreshed with its cached stats: high ground adds range and power nodes speed up Entrench.
## A ring in the zone's colour marks a turret that is benefiting, but only while zones are readable.
var turret: TurretActor
var range_bonus: float = 0.0
var entrench_bonus: float = 0.0
var badge: MeshInstance3D
var badge_type: String = ""

func _init(owner: TurretActor) -> void:
	turret = owner

func refresh() -> void:
	var terrain := turret.world.terrain
	if terrain and not turret.carried:
		range_bonus = terrain.range_bonus_at(turret.position)
		entrench_bonus = terrain.entrench_bonus_at(turret.position)
	else:
		range_bonus = 0.0
		entrench_bonus = 0.0
	_update_badge()

func _update_badge() -> void:
	var wanted := ""
	var terrain := turret.world.terrain
	if terrain and terrain.readable and not turret.carried:
		if range_bonus > 0.0:
			wanted = TerrainZone.HIGH_GROUND
		elif entrench_bonus > 0.0:
			wanted = TerrainZone.POWER_NODE
	if wanted == badge_type:
		return
	badge_type = wanted
	if badge:
		badge.queue_free()
		badge = null
	if wanted != "":
		badge = WorldGeometry.ring(turret, .9, TerrainZone.TYPES[wanted]["color"])
		badge.position.y = .025
