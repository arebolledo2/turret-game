extends CharacterBody2D

@export var max_health: float = 30.0
@export var speed: float = 150.0
@export var contact_damage: float = 33.0
@export var xp_value: int = 10

var current_health: float
var player: Node2D = null

func _ready() -> void:
	current_health = max_health
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")

func _physics_process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	
	# Move towards player (simple chase AI)
	var direction := global_position.direction_to(player.global_position)
	velocity = direction * speed
	move_and_slide()
	
	# Check for collision with player
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider = collision.get_collider()
		if collider.is_in_group("player") and collider.has_method("take_damage"):
			collider.take_damage(contact_damage)

func initialize(wave: int) -> void:
	# Scale stats based on wave number
	max_health = Globals.get_enemy_health(wave)
	speed = Globals.get_enemy_speed(wave)
	contact_damage = Globals.ENEMY_CONTACT_DAMAGE
	current_health = max_health

func take_damage(amount: float) -> void:
	current_health -= amount
	
	# Visual feedback - flash white
	$Sprite2D.modulate = Color.WHITE
	var tween = create_tween()
	tween.tween_property($Sprite2D, "modulate", Color(1, 0.3, 0.3, 1), 0.1)
	
	if current_health <= 0:
		die()

func die() -> void:
	# Emit signals for XP drop and kill tracking
	Events.enemy_killed.emit(self, global_position)
	Events.xp_dropped.emit(global_position, xp_value)
	Globals.total_kills += 1
	
	# Death effect (scale down and fade)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property($Sprite2D, "scale", Vector2.ZERO, 0.15)
	tween.tween_property($Sprite2D, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(queue_free)

