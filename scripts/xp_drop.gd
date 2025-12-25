extends Area2D

@export var xp_value: int = 10
@export var magnet_speed: float = 400.0
@export var magnet_acceleration: float = 800.0

var is_being_collected: bool = false
var is_collected: bool = false  # Guard against multiple collect() calls
var current_speed: float = 0.0
var target_player: Node2D = null

func _ready() -> void:
	add_to_group("pickups")
	
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
		if player and global_position.distance_to(player.global_position) < Globals.PLAYER_PICKUP_RADIUS:
			start_collection(player)

func start_collection(player: Node2D) -> void:
	is_being_collected = true
	target_player = player
	current_speed = 100.0  # Initial speed

func collect() -> void:
	if is_collected:
		return
	is_collected = true

	Globals.total_xp += xp_value
	Events.xp_collected.emit(xp_value, Globals.total_xp)

	# Also award gold from same drop with modifier
	var gold_mult = Globals.get_gold_earn_multiplier()
	var gold_amount = int(Globals.GOLD_PER_ENEMY * gold_mult)
	Globals.total_gold += gold_amount
	Events.gold_collected.emit(gold_amount, Globals.total_gold)

	# Collection effect
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	tween.chain().tween_callback(queue_free)
