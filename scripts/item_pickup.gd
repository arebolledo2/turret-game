extends Area2D

## Item Pickup
## Visual collectible that drops from tech drops
## Player walks over to collect, then added to loot review queue

@export var magnet_speed: float = 400.0
@export var magnet_acceleration: float = 800.0

var item_id: String = ""
var is_being_collected: bool = false
var is_collected: bool = false
var current_speed: float = 0.0
var target_player: Node2D = null

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("pickups")
	add_to_group("item_pickups")

	# Small spawn animation with bounce
	scale = Vector2.ZERO
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2.ONE, 0.3)


func initialize(new_item_id: String) -> void:
	"""Set the item this pickup contains."""
	item_id = new_item_id

	# Set color based on rarity
	if ItemRegistry.has_item(item_id):
		var item = ItemRegistry.get_item(item_id)
		var color := ItemRegistry.get_rarity_color(item.rarity)
		if sprite:
			sprite.modulate = color

		# Start pulsing glow effect
		_start_glow_pulse(color)


func _physics_process(delta: float) -> void:
	if is_being_collected and target_player and is_instance_valid(target_player):
		# Accelerate toward player
		current_speed = min(current_speed + magnet_acceleration * delta, magnet_speed)
		var direction := global_position.direction_to(target_player.global_position)
		global_position += direction * current_speed * delta

		# Check if close enough to collect
		if global_position.distance_to(target_player.global_position) < 20:
			collect()
	else:
		# Check for nearby player to start magnet effect
		var player = get_tree().get_first_node_in_group("player")
		if player and global_position.distance_to(player.global_position) < Globals.get_pickup_radius():
			start_collection(player)


func start_collection(player: Node2D) -> void:
	is_being_collected = true
	target_player = player
	current_speed = 100.0


func collect() -> void:
	if is_collected:
		return
	is_collected = true

	# Add to loot service queue for review at wave end
	LootService.add_found_item(item_id)
	Events.loot_item_found.emit(item_id)

	# Collection effect
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(queue_free)


func _start_glow_pulse(_base_color: Color) -> void:
	"""Pulsing glow effect based on rarity."""
	if not sprite:
		return

	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(sprite, "modulate:a", 1.0, 0.5)
	tween.tween_property(sprite, "modulate:a", 0.6, 0.5)
