extends Area2D
class_name Mine

## Proximity mine deployed by mine turrets
## Explodes when enemy enters proximity radius

var damage: float = 15.0
var explosive_radius: float = 70.0
var proximity_radius: float = 40.0
var knockback_force: float = 150.0
var deployer_turret: Node2D = null # Track parent turret
var is_armed: bool = false # Short delay before arming

# Visual components
var sprite: Sprite2D = null
var proximity_indicator: Polygon2D = null
var arming_timer: Timer = null

func _ready() -> void:
	# Set collision layers
	collision_layer = 0 # No layer
	collision_mask = 32 # Detect enemy hurtboxes

	# Setup visuals
	_setup_visuals()

	# Arm after short delay
	arming_timer = Timer.new()
	arming_timer.wait_time = 0.5
	arming_timer.one_shot = true
	arming_timer.timeout.connect(_on_armed)
	add_child(arming_timer)
	arming_timer.start()

	# Connect collision
	area_entered.connect(_on_area_entered)

func setup(p_damage: float, p_explosive_radius: float, p_proximity_radius: float, p_knockback: float, p_deployer: Node2D) -> void:
	"""Initialize mine with stats."""
	damage = p_damage
	explosive_radius = p_explosive_radius
	proximity_radius = p_proximity_radius
	knockback_force = p_knockback
	deployer_turret = p_deployer

	# Update collision shape to match proximity radius
	if has_node("CollisionShape2D"):
		var col_shape = get_node("CollisionShape2D")
		if col_shape.shape is CircleShape2D:
			col_shape.shape.radius = proximity_radius

func _setup_visuals() -> void:
	"""Create mine visuals."""
	# Main sprite (small circle)
	sprite = Sprite2D.new()
	sprite.texture = _create_circle_texture(8, Color("DD4444"))
	add_child(sprite)

	# Proximity indicator (ring)
	proximity_indicator = Polygon2D.new()
	var points = PackedVector2Array()
	for i in range(32):
		var angle = i * TAU / 32.0
		points.append(Vector2(cos(angle), sin(angle)) * proximity_radius)
	proximity_indicator.polygon = points
	proximity_indicator.color = Color("DD4444")
	proximity_indicator.color.a = 0.15
	add_child(proximity_indicator)
	proximity_indicator.visible = false # Show only when armed

	# Collision shape
	var collision_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = proximity_radius
	collision_shape.shape = circle
	add_child(collision_shape)

func _create_circle_texture(radius: int, color: Color) -> ImageTexture:
	"""Create a simple circle texture."""
	var img = Image.create(radius * 2, radius * 2, false, Image.FORMAT_RGBA8)
	for x in range(radius * 2):
		for y in range(radius * 2):
			var dist = Vector2(x - radius, y - radius).length()
			if dist <= radius:
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)

func _on_armed() -> void:
	"""Mine is now armed and can explode."""
	is_armed = true
	proximity_indicator.visible = true
	# Pulse animation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(sprite, "modulate:a", 0.5, 0.5)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.5)

func _on_area_entered(hurtbox: Area2D) -> void:
	"""Triggered when enemy enters proximity."""
	if not is_armed:
		return

	if not hurtbox.is_in_group("enemy_hurtbox"):
		return

	explode()

func explode() -> void:
	"""Detonate mine and damage enemies in radius."""
	var enemies = get_tree().get_nodes_in_group("enemies")
	var explosion_pos = global_position

	# Roll crit once for entire explosion
	var is_crit := TurretStatsService.roll_turret_crit()
	var final_damage := damage
	if is_crit:
		final_damage = TurretStatsService.calculate_turret_crit_damage(damage)

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var distance = explosion_pos.distance_to(enemy.global_position)
		if distance <= explosive_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(final_damage, is_crit)

			# Apply knockback
			if knockback_force > 0 and enemy.has_method("apply_knockback"):
				var knockback_dir = explosion_pos.direction_to(enemy.global_position)
				enemy.apply_knockback(knockback_force, knockback_dir)

	# Visual explosion effect
	Events.aoe_explosion.emit(explosion_pos, explosive_radius, final_damage)
	_spawn_explosion_effect()

	# Notify deployer turret
	if deployer_turret and deployer_turret.has_method("on_mine_exploded"):
		deployer_turret.on_mine_exploded(self)

	queue_free()

func _spawn_explosion_effect() -> void:
	"""Spawn visual explosion."""
	var viz = Polygon2D.new()
	var points = PackedVector2Array()
	for i in range(32):
		var angle = i * TAU / 32.0
		points.append(Vector2(cos(angle), sin(angle)) * explosive_radius)
	viz.polygon = points
	viz.color = Color("FF6633")
	viz.color.a = 0.5
	viz.global_position = global_position

	var parent = get_tree().current_scene if get_tree().current_scene else get_tree().root
	parent.add_child(viz)

	var tween = viz.create_tween()
	tween.set_parallel(true)
	tween.tween_property(viz, "scale", Vector2.ONE * 1.3, 0.25)
	tween.tween_property(viz, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(viz.queue_free)
