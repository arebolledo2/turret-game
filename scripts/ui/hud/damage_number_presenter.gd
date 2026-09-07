class_name DamageNumberPresenter
extends Node

## World/canvas positioning and pooled damage-number presentation.
var world_parent: Node
var fallback_parent: Node
var scene: PackedScene = preload("res://scenes/damage_number.tscn")
var enabled: Callable = func() -> bool: return FeatureFlagService.is_enabled(FeatureFlagService.SHOW_DAMAGE_NUMBERS)
var _pool: NodePool
var _pool_parent: Node

func show_damage(position: Vector2, amount: float, is_crit: bool, _enemy: Node2D = null) -> void:
	var number := spawn(position)
	if number != null:
		number.setup(amount, is_crit)

func show_dot(position: Vector2, amount: float) -> void:
	var number := spawn(position)
	if number == null:
		return
	number.setup(amount)
	var label := number.get_node_or_null("Label")
	if label != null:
		label.modulate = Color(1.0, 0.6, 0.2, 1.0)

func spawn(position: Vector2) -> Node2D:
	if not enabled.call() or scene == null:
		return null
	var parent := world_parent if is_instance_valid(world_parent) else fallback_parent
	if not is_instance_valid(parent):
		return null
	if _pool == null or parent != _pool_parent:
		if _pool != null:
			_pool.clear()
		_pool_parent = parent
		_pool = NodePool.new(scene, parent, 16, 128)
	var number := _pool.acquire() as Node2D
	if number == null:
		return null
	var offset := position + Vector2(GameRandom.cosmetic.randf_range(-10, 10), -20)
	if parent == fallback_parent:
		number.position = offset
	else:
		number.global_position = offset
	return number

func _exit_tree() -> void:
	if _pool != null:
		_pool.clear()
