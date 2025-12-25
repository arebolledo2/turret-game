class_name ChaseBehavior
extends EnemyBehavior

## Chase behavior - enemy moves directly toward the player
## This is the simplest and most common enemy behavior

## Execute chase behavior - move toward target (player or defense target)
func execute(_delta: float) -> Vector2:
	# Use the enemy's player reference (which can be defense target in Tech Defense mode)
	var target = enemy.player
	
	if target and is_instance_valid(target):
		return enemy.global_position.direction_to(target.global_position)
	
	return Vector2.ZERO
