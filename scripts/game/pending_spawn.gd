class_name PendingSpawn
extends RefCounted

## An enemy arriving through a floor hatch: the hatch opens, the enemy rises, then the hatch closes quickly.
## `enemy` exists (inactive, outside `world.enemies`) from the rise until the hatch starts closing.
var type: String
var at: Vector3
var left: float
var marker: MeshInstance3D
var boss: bool
var enemy: EnemyActor

func _init(type_id: String, position: Vector3, seconds: float, hatch: MeshInstance3D, is_boss: bool) -> void:
	type = type_id
	at = position
	left = seconds
	marker = hatch
	boss = is_boss
