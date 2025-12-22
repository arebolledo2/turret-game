class_name ChaseBehavior
extends EnemyBehavior

## Chase behavior - enemy moves directly toward the player
## This is the simplest and most common enemy behavior

## Execute chase behavior - move toward player
func execute(_delta: float) -> Vector2:
	var player = enemy.get_tree().get_first_node_in_group("player")

	if player and is_instance_valid(player):
		return enemy.global_position.direction_to(player.global_position)

	return Vector2.ZERO
