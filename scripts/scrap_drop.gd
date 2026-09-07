extends Area2D

@export var scrap_value: int = 10
@export var magnet_speed: float = 400.0
@export var magnet_acceleration: float = 800.0

var is_being_collected: bool = false
var is_collected: bool = false # Guard against multiple collect() calls
var current_speed: float = 0.0
var target_player: Node2D = null

func _ready() -> void:
	add_to_group("pickups")
	
	# Randomly select one of two scrap sprites (50/50)
	var sprite_node = $Sprite2D
	var scrap_sprite_1 = preload("res://assets/sprites/scrap_sprite.png")
	var scrap_sprite_2 = preload("res://assets/sprites/scrap_sprite_2.png")
	sprite_node.texture = scrap_sprite_1 if GameRandom.cosmetic.randf() < 0.5 else scrap_sprite_2
	
	# Small spawn animation
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2.ONE, 0.2)

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
		if player and global_position.distance_to(player.global_position) < PlayerStatsService.get_pickup_radius():
			start_collection(player)

func start_collection(player: Node2D) -> void:
	is_being_collected = true
	target_player = player
	current_speed = 100.0 # Initial speed

func collect() -> void:
	if is_collected:
		return
	is_collected = true

	# Award scrap with multiplier (merged from old xp + gold system)
	var scrap_mult = ItemTrackingService.get_scrap_earn_multiplier()
	var scrap_amount = EconomyService.add_scrap_probabilistic(scrap_value, scrap_mult)
	Events.scrap_collected.emit(scrap_amount, EconomyService.total_scrap)

	# Collection effect
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	tween.chain().tween_callback(queue_free)
