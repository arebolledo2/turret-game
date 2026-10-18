class_name PendingSpawn
extends RefCounted

## An enemy whose ground marker is counting down before it appears.
var type: String
var at: Vector3
var left: float
var marker: MeshInstance3D
var boss: bool

func _init(type_id: String, position: Vector3, seconds: float, ring: MeshInstance3D, is_boss: bool) -> void:
	type = type_id
	at = position
	left = seconds
	marker = ring
	boss = is_boss
