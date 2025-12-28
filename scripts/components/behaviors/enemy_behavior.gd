class_name EnemyBehavior
extends RefCounted

## Base class for enemy AI behaviors
## Behaviors are stateful strategies that determine how enemies move and act

## Reference to the enemy using this behavior
var enemy: CharacterBody2D

## Behavior configuration parameters
var params: Dictionary = {}

## Initialize behavior with enemy reference and parameters
func _init(enemy_ref: CharacterBody2D, behavior_params: Dictionary = {}) -> void:
	enemy = enemy_ref
	params = behavior_params

## Called when behavior is activated (switched to)
func enter() -> void:
	pass

## Called when behavior is deactivated (switched from)
func exit() -> void:
	pass

## Execute behavior logic and return movement direction
## Returns: Normalized Vector2 direction for movement (or Vector2.ZERO for no movement)
func execute(delta: float) -> Vector2:
	DebugService.error(DebugService.VALIDATION, "EnemyBehavior.execute() must be overridden by subclass")
	return Vector2.ZERO

## Get default parameters for this behavior type
## Override in subclasses to provide behavior-specific defaults
static func get_default_params() -> Dictionary:
	return {}
