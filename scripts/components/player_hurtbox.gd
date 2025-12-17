extends Area2D
class_name PlayerHurtbox

## Player hurtbox component for receiving damage
## This Area2D detects incoming damage from enemy damage zones
## and forwards it to the parent player while respecting invincibility.

func _ready() -> void:
	# Set collision layer and mask
	collision_layer = 16  # Layer 5 (player_hurtbox = 2^4 = 16)
	collision_mask = 64  # Layer 7 (enemy_damage_zone = 2^6 = 64)
	monitoring = true  # Detect damage zones
	monitorable = true  # Allow detection by damage zones

	# Add to group for identification
	add_to_group("player_hurtbox")

	# Connect signals - damage is handled by enemy_damage_zone
	# This hurtbox just needs to be detectable
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	"""Handle incoming damage from enemy damage zones."""
	# The EnemyDamageZone handles damage application
	# This is here for potential future use or debugging
	pass
