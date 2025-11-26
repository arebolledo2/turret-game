extends Area2D

@export var speed: float = 500.0
@export var damage: float = 10.0
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.RIGHT
var is_player_projectile: bool = true
var is_setup: bool = false

func _ready() -> void:
	# Auto-destroy after lifetime
	var timer = get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)
	
	# Connect body entered signal
	body_entered.connect(_on_body_entered)

func setup(dir: Vector2, spd: float, dmg: float, from_player: bool) -> void:
	direction = dir.normalized()
	speed = spd
	damage = dmg
	is_player_projectile = from_player
	is_setup = true
	
	# Set collision - use call_deferred to avoid physics query error
	call_deferred("set_collision_layer", 4)  # projectile layer
	call_deferred("set_collision_mask", 2)   # enemy layer

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		
		# Destroy projectile on hit (single target)
		queue_free()
