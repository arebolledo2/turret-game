extends Area2D

@export var speed: float = 500.0
@export var damage: float = 10.0
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.RIGHT
var is_player_projectile: bool = true
var is_setup: bool = false

# Extended stats for turret types
var pierce: int = 0 # Number of enemies to pass through (0 = single target)
var pierce_count: int = 0 # Enemies already hit
var aoe_radius: float = 0.0 # If > 0, explodes on hit
var damage_type: GameEnums.DamageType = GameEnums.DamageType.PHYSICAL
var dot_damage: float = 0.0
var dot_duration: float = 0.0
var dot_tick_rate: float = 1.0
var knockback_force: float = 0.0 # Knockback force for explosions
var hit_enemies: Array = [] # Track enemies hit (for pierce)

func _ready() -> void:
	# Render above all gameplay entities
	z_index = 5

	# Auto-destroy after lifetime
	var timer = get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)
	
	# Connect area entered signal for hurtbox detection
	area_entered.connect(_on_hurtbox_entered)

## Basic setup for simple projectiles (backwards compatible)
func setup(dir: Vector2, spd: float, dmg: float, from_player: bool) -> void:
	direction = dir.normalized()
	speed = spd
	damage = dmg
	is_player_projectile = from_player
	is_setup = true
	
	# Set collision - use call_deferred to avoid physics query error
	call_deferred("set_collision_layer", 4) # projectile layer
	call_deferred("set_collision_mask", 96) # enemy_hurtbox (32) + tunnel_door (64)

## Extended setup for turret-typed projectiles
func setup_extended(stats: Dictionary, dir: Vector2, from_player: bool, dtype: GameEnums.DamageType) -> void:
	direction = dir.normalized()
	speed = stats.get("projectile_speed", 500.0)
	damage = stats.get("damage", 10.0)
	pierce = int(stats.get("pierce", 0))
	aoe_radius = stats.get("aoe_radius", 0.0)
	dot_damage = stats.get("dot_damage", 0.0)
	dot_duration = stats.get("dot_duration", 0.0)
	dot_tick_rate = stats.get("dot_tick_rate", 1.0)
	knockback_force = stats.get("knockback_force", 0.0)
	damage_type = dtype
	is_player_projectile = from_player
	is_setup = true

	# Set collision
	call_deferred("set_collision_layer", 4) # projectile layer
	call_deferred("set_collision_mask", 96) # enemy_hurtbox (32) + tunnel_door (64)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_hurtbox_entered(hurtbox: Area2D) -> void:
	print("DEBUG Projectile: Collision with area: ", hurtbox, " name: ", hurtbox.name)
	print("DEBUG Projectile: Is enemy_hurtbox: ", hurtbox.is_in_group("enemy_hurtbox"))
	print("DEBUG Projectile: Is tunnel_door: ", hurtbox.is_in_group("tunnel_doors"))
	
	# Check if this is a tunnel door - handle specially
	var parent = hurtbox.get_parent()
	if parent and parent.is_in_group("tunnel_doors"):
		print("DEBUG Projectile: Hit tunnel door!")
		if parent.has_method("take_damage"):
			parent.take_damage(damage)
			queue_free()
		return
	
	# Verify this is an enemy hurtbox
	if not hurtbox.is_in_group("enemy_hurtbox"):
		return
	
	# Get the enemy (parent of hurtbox)
	var enemy = hurtbox.get_parent()
	if not enemy or not enemy.is_in_group("enemies"):
		return
	
	# Skip if already hit this enemy (for pierce projectiles)
	if enemy in hit_enemies:
		return
	
	hit_enemies.append(enemy)
	
	# Check for AoE explosion
	if aoe_radius > 0:
		_do_aoe_explosion()
		queue_free()
		return
	
	# Apply direct damage
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage)
	
	# Apply DoT if applicable
	if dot_damage > 0 and dot_duration > 0 and enemy.has_method("apply_status_effect"):
		enemy.apply_status_effect(damage_type, dot_damage, dot_duration, dot_tick_rate)
	
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

			# Apply knockback
			if knockback_force > 0 and enemy.has_method("apply_knockback"):
				var knockback_dir := explosion_pos.direction_to(enemy.global_position)
				enemy.apply_knockback(knockback_force, knockback_dir)

	# Visual feedback for explosion (spawn effect or flash)
	_spawn_explosion_effect()

## Spawn a visual explosion effect
func _spawn_explosion_effect() -> void:
	# Create a circle polygon similar to shock turret pulse
	var viz = Polygon2D.new()
	
	# Create circle polygon with the aoe_radius
	var points = PackedVector2Array()
	var segments = 32
	for i in range(segments):
		var angle = i * TAU / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * aoe_radius)
	viz.polygon = points
	
	# Color based on damage type (plasma = purple/magenta)
	var explosion_color: Color
	match damage_type:
		GameEnums.DamageType.PLASMA:
			explosion_color = Color("AA44DD") # Purple/magenta for plasma
		GameEnums.DamageType.FIRE:
			explosion_color = Color("FF6633") # Orange for fire
		GameEnums.DamageType.ELECTRIC:
			explosion_color = Color("44DDDD") # Cyan for electric
		_:
			explosion_color = Color("FFAA33") # Default orange/yellow
	
	viz.color = explosion_color
	viz.color.a = 0.5
	viz.global_position = global_position
	
	var parent = get_tree().current_scene if get_tree().current_scene else get_tree().root
	parent.add_child(viz)
	
	# Animate: expand slightly and fade out
	var tween = viz.create_tween()
	tween.set_parallel(true)
	tween.tween_property(viz, "scale", Vector2.ONE * 1.3, 0.25)
	tween.tween_property(viz, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(viz.queue_free)
