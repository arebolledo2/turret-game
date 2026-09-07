class_name ProjectileEmitter
extends RefCounted

## Scene adapter: combat supplies the shot; this owns pool acquisition and setup.
var parent: Node

func emit_shot(origin: Vector2, direction: Vector2, stats: Dictionary, friendly: bool, damage_type: int, is_crit: bool) -> Node2D:
	var projectile := ProjectilePool.acquire(parent)
	if projectile == null:
		return null
	projectile.global_position = origin
	projectile.setup_extended(stats, direction, friendly, damage_type, is_crit)
	return projectile
