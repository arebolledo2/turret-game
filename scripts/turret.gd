extends Node2D

@export var turret_type: String = "normal"

# Stats cache
var stats: Dictionary = {}
var current_damage: float = 0.0
var current_range: float = 0.0
var current_fire_rate: float = 0.0
var current_rotation_speed: float = 0.0

var target: Node2D = null
var can_fire: bool = true
var fire_timer: Timer
var projectile_scene: PackedScene
var is_in_pickup_range: bool = false

@onready var weapon_sprite: Sprite2D = $WeaponSprite
@onready var range_indicator: Node2D = $RangeIndicator

func _ready() -> void:
	add_to_group("turrets")
	projectile_scene = preload("res://scenes/projectile.tscn")
	
	# Initialize stats
	update_stats()
	
	# Setup visual tint
	var color = Globals.get_turret_color(turret_type)
	if weapon_sprite:
		weapon_sprite.modulate = color
	
	# Setup fire rate timer
	fire_timer = Timer.new()
	fire_timer.one_shot = true
	_update_timer()
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	add_child(fire_timer)
	
	# Setup range indicator
	if range_indicator:
		if range_indicator.has_method("set_radius"):
			range_indicator.set_radius(current_range)
		range_indicator.modulate = color
		range_indicator.modulate.a = 0.0  # Hidden by default
	
	# Spawn animation
	play_spawn_animation()

func update_stats() -> void:
	stats = Globals.get_turret_stats(turret_type)
	current_damage = stats.get("damage", 15.0)
	current_range = stats.get("range", 250.0)
	current_fire_rate = stats.get("fire_rate", 2.0)
	current_rotation_speed = stats.get("rotation_speed", 180.0)
	
	if fire_timer:
		_update_timer()
	
	if range_indicator and range_indicator.has_method("set_radius"):
		range_indicator.set_radius(current_range)

func _update_timer() -> void:
	if current_fire_rate > 0:
		fire_timer.wait_time = 1.0 / current_fire_rate
	else:
		fire_timer.wait_time = 1.0

func _physics_process(delta: float) -> void:
	find_target()
	
	if target and is_instance_valid(target):
		# Rotate the whole turret toward target if it has rotation speed
		if current_rotation_speed > 0:
			var direction_to_target := global_position.direction_to(target.global_position)
			var target_angle: float = direction_to_target.angle()
			var current_angle: float = rotation
			var angle_diff: float = angle_difference(current_angle, target_angle)
			
			var max_rotation: float = deg_to_rad(current_rotation_speed) * delta
			var rotation_amount: float = clampf(angle_diff, -max_rotation, max_rotation)
			rotation += rotation_amount
		
		# Check if we should fire
		var should_fire = false
		if current_rotation_speed <= 0:
			# Non-rotating turrets (like Shock) fire if target is in range
			should_fire = true
		else:
			# Rotating turrets need to be aimed
			var direction_to_target := global_position.direction_to(target.global_position)
			var target_angle: float = direction_to_target.angle()
			var aim_diff: float = absf(angle_difference(rotation, target_angle))
			should_fire = aim_diff < deg_to_rad(20)
			
		if should_fire and can_fire:
			fire()

func find_target() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		target = null
		return
	
	var targeting = stats.get("targeting", "nearest")
	var best_target: Node2D = null
	var best_dist: float = -1.0
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
			
		var dist := global_position.distance_to(enemy.global_position)
		if dist > current_range:
			continue
		
		if best_target == null:
			best_target = enemy
			best_dist = dist
			continue
		
		if targeting == "farthest":
			if dist > best_dist:
				best_target = enemy
				best_dist = dist
		else: # nearest (default)
			if dist < best_dist:
				best_target = enemy
				best_dist = dist
	
	target = best_target

func fire() -> void:
	if not can_fire:
		return
	
	can_fire = false
	fire_timer.start()
	
	# Determine attack style
	var attack_styles = Globals.TURRET_TYPES[turret_type].get("attack_styles", [])
	
	if Globals.AttackStyle.PROJECTILE in attack_styles:
		_fire_projectile()
	elif Globals.AttackStyle.CHAIN in attack_styles:
		_fire_chain()
	elif Globals.AttackStyle.INSTANT in attack_styles:
		_fire_instant()
	elif Globals.AttackStyle.AOE in attack_styles:
		_fire_aoe_pulse()
	
	Events.turret_fired.emit(self)

func _fire_projectile() -> void:
	if target == null or projectile_scene == null:
		return
		
	var projectile = projectile_scene.instantiate()
	var parent = get_tree().current_scene if get_tree().current_scene else get_tree().root
	parent.add_child(projectile)
	projectile.global_position = global_position
	
	# Determine damage type
	var damage_types = Globals.TURRET_TYPES[turret_type].get("damage_types", [Globals.DamageType.PHYSICAL])
	var dtype = damage_types[0] if not damage_types.is_empty() else Globals.DamageType.PHYSICAL
	
	projectile.setup_extended(stats, Vector2.RIGHT.rotated(rotation), true, dtype)
	flash_muzzle()

func _fire_instant() -> void:
	if target == null or not is_instance_valid(target):
		return
		
	# Apply damage immediately
	if target.has_method("take_damage"):
		target.take_damage(current_damage)
	
	# Visual tracer
	_draw_tracer(target.global_position)
	flash_muzzle()

func _fire_aoe_pulse() -> void:
	# Damage all enemies in range
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	
	# Visual pulse
	_spawn_pulse_effect()
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		var dist = global_position.distance_to(enemy.global_position)
		if dist <= current_range:
			if enemy.has_method("take_damage"):
				enemy.take_damage(current_damage)
				hit_count += 1
	
	if hit_count > 0:
		Events.aoe_explosion.emit(global_position, current_range, current_damage)

func _fire_chain() -> void:
	if target == null or not is_instance_valid(target):
		return
	
	var chain_count = int(stats.get("chain_count", 3))
	var chain_range = stats.get("chain_range", 150.0)
	var chain_decay = stats.get("chain_decay", 0.7)
	var dmg = current_damage
	
	var current_target = target
	var hit_enemies = []
	var last_pos = global_position
	
	# Chain loop
	for i in range(chain_count + 1): # +1 because first hit counts as 0th chain? No, first hit is direct.
		if not is_instance_valid(current_target):
			break
			
		# Hit current target
		if current_target.has_method("take_damage"):
			current_target.take_damage(dmg)
		
		hit_enemies.append(current_target)
		
		# Visual arc
		_draw_lightning_arc(last_pos, current_target.global_position)
		Events.chain_lightning_hit.emit(last_pos, current_target.global_position, dmg)
		
		last_pos = current_target.global_position
		
		# Decay damage for next hit
		dmg *= chain_decay
		
		# Find next target
		var next_target = _find_closest_enemy_excluding(last_pos, chain_range, hit_enemies)
		if next_target == null:
			break
		current_target = next_target

func _find_closest_enemy_excluding(pos: Vector2, range_limit: float, excluded: Array) -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var best_target: Node2D = null
	var best_dist: float = range_limit
	
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy in excluded:
			continue
			
		var dist = pos.distance_to(enemy.global_position)
		if dist < best_dist:
			best_dist = dist
			best_target = enemy
			
	return best_target

func _draw_tracer(end_pos: Vector2) -> void:
	var line = Line2D.new()
	line.width = 2.0
	line.default_color = Globals.get_turret_color(turret_type)
	line.add_point(Vector2.ZERO) # Local space
	line.add_point(to_local(end_pos))
	add_child(line)
	
	var tween = create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.2)
	tween.tween_callback(line.queue_free)

func _draw_lightning_arc(start_pos: Vector2, end_pos: Vector2) -> void:
	# Create a line in global space (or add to scene root)
	var line = Line2D.new()
	line.width = 3.0
	line.default_color = Color.CYAN
	line.texture_mode = Line2D.LINE_TEXTURE_TILE
	
	# Simple straight line for now, could add jitter for lightning effect
	line.add_point(start_pos)
	line.add_point(end_pos)
	
	var parent = get_tree().current_scene if get_tree().current_scene else get_tree().root
	parent.add_child(line)
	
	var tween = create_tween()
	tween.tween_property(line, "width", 0.0, 0.3)
	tween.tween_callback(line.queue_free)

func _spawn_pulse_effect() -> void:
	# Use a simple visual node
	var viz = Polygon2D.new()
	# Create circle polygon
	var points = PackedVector2Array()
	for i in range(32):
		var angle = i * TAU / 32.0
		points.append(Vector2(cos(angle), sin(angle)) * current_range)
	viz.polygon = points
	viz.color = Globals.get_turret_color(turret_type)
	viz.color.a = 0.3
	
	add_child(viz)
	
	var tween = create_tween()
	tween.tween_property(viz, "scale", Vector2.ONE * 1.2, 0.2)
	tween.parallel().tween_property(viz, "modulate:a", 0.0, 0.2)
	tween.tween_callback(viz.queue_free)

func _on_fire_timer_timeout() -> void:
	can_fire = true

func flash_muzzle() -> void:
	if weapon_sprite:
		weapon_sprite.modulate = Color.WHITE
		var tween = create_tween()
		tween.tween_property(weapon_sprite, "modulate", Globals.get_turret_color(turret_type), 0.1)

func play_spawn_animation() -> void:
	# Scale up from zero
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2.ONE, 0.3)
	
	# Particle burst effect (if we have particles)
	# spawn_particles()

func show_range() -> void:
	if range_indicator:
		range_indicator.modulate.a = 0.3

func hide_range() -> void:
	if range_indicator:
		range_indicator.modulate.a = 0.0

func show_pickup_indicator() -> void:
	is_in_pickup_range = true
	if range_indicator:
		# Set to pickup range and blue color
		if range_indicator.has_method("set_radius"):
			range_indicator.set_radius(Globals.TURRET_PICKUP_RANGE)
		range_indicator.modulate = Color(0.5, 0.8, 1.0, Globals.TURRET_IN_RANGE_INDICATOR_ALPHA)

func hide_pickup_indicator() -> void:
	is_in_pickup_range = false
	if range_indicator:
		# Reset to attack range and hide
		if range_indicator.has_method("set_radius"):
			range_indicator.set_radius(current_range)
		range_indicator.modulate = Globals.get_turret_color(turret_type)
		range_indicator.modulate.a = 0.0

