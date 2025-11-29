extends Area2D

@export var speed: float = 500.0
@export var damage: float = 10.0
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.RIGHT
var is_player_projectile: bool = true
var is_setup: bool = false

# Extended stats for turret types
var pierce: int = 0  # Number of enemies to pass through (0 = single target)
var pierce_count: int = 0  # Enemies already hit
var aoe_radius: float = 0.0  # If > 0, explodes on hit
var damage_type: Globals.DamageType = Globals.DamageType.PHYSICAL
var dot_damage: float = 0.0
var dot_duration: float = 0.0
var dot_tick_rate: float = 1.0
var hit_enemies: Array = []  # Track enemies hit (for pierce)

func _ready() -> void:
	# Auto-destroy after lifetime
	var timer = get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)
	
	# Connect body entered signal
	body_entered.connect(_on_body_entered)

## Basic setup for simple projectiles (backwards compatible)
func setup(dir: Vector2, spd: float, dmg: float, from_player: bool) -> void:
	direction = dir.normalized()
	speed = spd
	damage = dmg
	is_player_projectile = from_player
	is_setup = true
	
	# Set collision - use call_deferred to avoid physics query error
	call_deferred("set_collision_layer", 4)  # projectile layer
	call_deferred("set_collision_mask", 2)   # enemy layer

## Extended setup for turret-typed projectiles
func setup_extended(stats: Dictionary, dir: Vector2, from_player: bool, dtype: Globals.DamageType) -> void:
	direction = dir.normalized()
	speed = stats.get("projectile_speed", 500.0)
	damage = stats.get("damage", 10.0)
	pierce = int(stats.get("pierce", 0))
	aoe_radius = stats.get("aoe_radius", 0.0)
	dot_damage = stats.get("dot_damage", 0.0)
	dot_duration = stats.get("dot_duration", 0.0)
	dot_tick_rate = stats.get("dot_tick_rate", 1.0)
	damage_type = dtype
	is_player_projectile = from_player
	is_setup = true
	
	# Set collision
	call_deferred("set_collision_layer", 4)  # projectile layer
	call_deferred("set_collision_mask", 2)   # enemy layer

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies"):
		return
	
	# Skip if already hit this enemy (for pierce projectiles)
	if body in hit_enemies:
		return
	
	hit_enemies.append(body)
	
	# Check for AoE explosion
	if aoe_radius > 0:
		_do_aoe_explosion()
		queue_free()
		return
	
	# Apply direct damage
	if body.has_method("take_damage"):
		body.take_damage(damage)
	
	# Apply DoT if applicable
	if dot_damage > 0 and dot_duration > 0 and body.has_method("apply_status_effect"):
		body.apply_status_effect(damage_type, dot_damage, dot_duration, dot_tick_rate)
	
	# Handle pierce
	pierce_count += 1
	if pierce_count > pierce:
		queue_free()

## Execute AoE explosion - damages all enemies in radius
func _do_aoe_explosion() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var explosion_pos = global_position
	
	Events.aoe_explosion.emit(explosion_pos, aoe_radius, damage)
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		var distance = explosion_pos.distance_to(enemy.global_position)
		if distance <= aoe_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage)
			
			# Apply DoT to all enemies in AoE
			if dot_damage > 0 and dot_duration > 0 and enemy.has_method("apply_status_effect"):
				enemy.apply_status_effect(damage_type, dot_damage, dot_duration, dot_tick_rate)
	
	# Visual feedback for explosion (spawn effect or flash)
	_spawn_explosion_effect()

## Spawn a visual explosion effect
func _spawn_explosion_effect() -> void:
	# Create a simple visual flash for the explosion
	# Future: Replace with particle effect
	var flash := Sprite2D.new()
	flash.modulate = Color(1.0, 0.8, 0.3, 0.8)
	flash.global_position = global_position
	
	# Use the projectile's sprite texture scaled up, or a simple circle
	if has_node("Sprite2D") and $Sprite2D.texture:
		flash.texture = $Sprite2D.texture
		flash.scale = Vector2.ONE * (aoe_radius / 20.0)
	
	get_tree().current_scene.add_child(flash)
	
	# Fade out and remove
	var tween = flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", flash.scale * 1.5, 0.2)
	tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(flash.queue_free)
