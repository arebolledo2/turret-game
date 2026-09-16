class_name SliceTurret
extends Node3D

var world: Node
var carried: bool = false
var cooldown: float = 0.0
var aim: Node3D
var muzzle: Node3D
var aim_rest: Vector3

func _ready() -> void:
	var model := preload("res://assets/models/slice/ion_turret.glb").instantiate()
	add_child(model)
	aim = model.find_child("Aim", true, false) as Node3D
	muzzle = model.find_child("Muzzle", true, false) as Node3D
	aim_rest = aim.position

func _physics_process(delta: float) -> void:
	if not world.is_combat():
		return
	if carried:
		position = world.player.position + Vector3(0, 1.15, .25)
		return
	cooldown = maxf(0.0, cooldown - delta)
	aim.position = aim.position.lerp(aim_rest, minf(delta * 16.0, 1.0))
	var stats: Dictionary = TurretStatsService.get_turret_stats("normal", 1.0)
	var target: SliceActor = world.nearest_enemy(position, float(stats.get("range", 240.0)) * SliceGeometry.METRES_PER_PIXEL)
	if not target:
		return
	var heading := SliceGeometry.planar(target.position - position)
	aim.rotation.y = atan2(-heading.x, -heading.z)
	if cooldown <= 0.0:
		world.fire(muzzle.global_position, target, float(stats.get("damage", 13.0)),
			float(stats.get("projectile_speed", 700.0)) * SliceGeometry.METRES_PER_PIXEL)
		cooldown = 1.0 / maxf(float(stats.get("fire_rate", 1.2)), .01)
		aim.position += heading.normalized() * -.045
