extends Node
class_name TurretCombat

## Handles turret targeting, firing, and all attack styles.
##
## Responsibilities:
## - Target finding (nearest/farthest)
## - Fire rate timing
## - Projectile attacks
## - Instant hitscan attacks
## - Chain lightning attacks
## - AOE pulse attacks
## - Visual effects (tracers, arcs, pulses)

# Dependencies (set via initialize)
var turret: Node2D = null
var turret_type: String = ""
var stats: Dictionary = {}

# Combat state
var target: Node2D = null
var can_fire: bool = true
var fire_timer: Timer = null
var projectile_scene: PackedScene

func initialize(p_turret: Node2D, p_turret_type: String, p_stats: Dictionary) -> void:
	"""Initialize component with required references."""
	turret = p_turret
	turret_type = p_turret_type
	stats = p_stats
	assert(turret != null, "TurretCombat: turret reference required")

	# Preload projectile scene
	projectile_scene = preload("res://scenes/projectile.tscn")

	# Setup fire rate timer
	fire_timer = Timer.new()
	fire_timer.one_shot = true
	_update_fire_timer()
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	turret.add_child(fire_timer)

func update_stats(new_stats: Dictionary) -> void:
	"""Update stats cache and fire timer."""
	stats = new_stats
	if fire_timer:
		_update_fire_timer()

func _update_fire_timer() -> void:
	"""Update fire timer based on current fire rate."""
	var current_fire_rate: float = stats.get("fire_rate", 2.0)
	if current_fire_rate > 0:
		fire_timer.wait_time = 1.0 / current_fire_rate
	else:
		fire_timer.wait_time = 1.0

func process() -> void:
	"""Process combat logic (targeting and firing)."""
	find_target()

	# Fire if target is in range and can fire
	if target and is_instance_valid(target) and can_fire:
		fire()

func find_target() -> void:
	"""Find target in range for firing."""
	var enemies = turret.get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		target = null
		return

	var current_range: float = stats.get("range", 250.0)
	var targeting = stats.get("targeting", "nearest")
	var best_target: Node2D = null
	var best_dist: float = -1.0

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var dist := turret.global_position.distance_to(enemy.global_position)
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

func find_tracking_target() -> Node2D:
	"""Find the closest enemy regardless of range (for tracking/rotation)."""
	var enemies = turret.get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return null

	var best_target: Node2D = null
	var best_dist: float = INF

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := turret.global_position.distance_to(enemy.global_position)
		if dist < best_dist:
			best_target = enemy
			best_dist = dist

	return best_target

func fire() -> void:
	"""Execute firing logic based on turret attack style."""
	if not can_fire:
		return

	can_fire = false
	fire_timer.start()

	# Determine attack style
	var turret_def = TurretRegistry.get_type(turret_type)
	var attack_styles = turret_def.get("attack_styles", [])

	if GameEnums.AttackStyle.PROJECTILE in attack_styles:
		_fire_projectile()
	elif GameEnums.AttackStyle.CHAIN in attack_styles:
		_fire_chain()
	elif GameEnums.AttackStyle.INSTANT in attack_styles:
		_fire_instant()
	elif GameEnums.AttackStyle.AOE in attack_styles:
		_fire_aoe_pulse()

	Events.turret_fired.emit(turret)

func _fire_projectile() -> void:
	"""Fire a projectile at the target."""
	if target == null or projectile_scene == null:
		return

	var projectile = projectile_scene.instantiate()
	var parent = turret.get_tree().current_scene if turret.get_tree().current_scene else turret.get_tree().root
	parent.add_child(projectile)
	projectile.global_position = turret.global_position

	# Determine damage type
	var turret_def = TurretRegistry.get_type(turret_type)
	var damage_types = turret_def.get("damage_types", [GameEnums.DamageType.PHYSICAL])
	var dtype = damage_types[0] if not damage_types.is_empty() else GameEnums.DamageType.PHYSICAL

	# Calculate direction to target
	var direction = turret.global_position.direction_to(target.global_position)
	projectile.setup_extended(stats, direction, true, dtype)

func _fire_instant() -> void:
	"""Apply instant hitscan damage to target."""
	if target == null or not is_instance_valid(target):
		return

	# Apply damage immediately
	var current_damage: float = stats.get("damage", 15.0)
	if target.has_method("take_damage"):
		target.take_damage(current_damage)

	# Visual tracer
	_draw_tracer(target.global_position)

func _fire_aoe_pulse() -> void:
	"""Damage all enemies in range with a pulse."""
	var enemies = turret.get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	var current_range: float = stats.get("range", 250.0)
	var current_damage: float = stats.get("damage", 15.0)

	# Visual pulse
	_spawn_pulse_effect()

	# Get slow parameters if this turret applies slow
	var slow_intensity: float = stats.get("slow_intensity", 0.0)
	var slow_duration: float = stats.get("slow_duration", 0.0)

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var dist = turret.global_position.distance_to(enemy.global_position)
		if dist <= current_range:
			if enemy.has_method("take_damage"):
				enemy.take_damage(current_damage)
				hit_count += 1

			# Apply slow effect if configured
			if slow_intensity > 0 and slow_duration > 0 and enemy.has_method("apply_status_effect"):
				var turret_def = TurretRegistry.get_type(turret_type)
				var damage_types = turret_def.get("damage_types", [])
				var dtype = damage_types[0] if not damage_types.is_empty() else GameEnums.DamageType.ELECTRIC
				enemy.apply_status_effect(dtype, 0.0, slow_duration, 1.0, slow_intensity)

	if hit_count > 0:
		Events.aoe_explosion.emit(turret.global_position, current_range, current_damage)

func _fire_chain() -> void:
	"""Fire chain lightning that bounces between enemies."""
	if target == null or not is_instance_valid(target):
		return

	var chain_count = int(stats.get("chain_count", 3))
	var chain_range = stats.get("chain_range", 150.0)
	var chain_decay = stats.get("chain_decay", 0.7)
	var current_damage: float = stats.get("damage", 15.0)
	var dmg = current_damage

	var current_target = target
	var hit_enemies = []
	var last_pos = turret.global_position

	# Chain loop
	for i in range(chain_count + 1):
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
	"""Find closest enemy to a position, excluding specific enemies."""
	var enemies = turret.get_tree().get_nodes_in_group("enemies")
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
	"""Draw instant hitscan tracer line."""
	var line = Line2D.new()
	line.width = 2.0
	line.default_color = TurretRegistry.get_color(turret_type)
	line.add_point(Vector2.ZERO) # Local space
	line.add_point(turret.to_local(end_pos))
	turret.add_child(line)

	var tween = turret.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.2)
	tween.tween_callback(line.queue_free)

func _draw_lightning_arc(start_pos: Vector2, end_pos: Vector2) -> void:
	"""Draw chain lightning arc effect."""
	var line = Line2D.new()
	line.width = 3.0
	line.default_color = Color.CYAN
	line.texture_mode = Line2D.LINE_TEXTURE_TILE

	# Simple straight line for now
	line.add_point(start_pos)
	line.add_point(end_pos)

	var parent = turret.get_tree().current_scene if turret.get_tree().current_scene else turret.get_tree().root
	parent.add_child(line)

	var tween = turret.create_tween()
	tween.tween_property(line, "width", 0.0, 0.3)
	tween.tween_callback(line.queue_free)

func _spawn_pulse_effect() -> void:
	"""Spawn AOE pulse visual effect."""
	var current_range: float = stats.get("range", 250.0)
	var viz = Polygon2D.new()

	# Create circle polygon
	var points = PackedVector2Array()
	for i in range(32):
		var angle = i * TAU / 32.0
		points.append(Vector2(cos(angle), sin(angle)) * current_range)
	viz.polygon = points
	viz.color = TurretRegistry.get_color(turret_type)
	viz.color.a = 0.3

	turret.add_child(viz)

	var tween = turret.create_tween()
	tween.tween_property(viz, "scale", Vector2.ONE * 1.2, 0.2)
	tween.parallel().tween_property(viz, "modulate:a", 0.0, 0.2)
	tween.tween_callback(viz.queue_free)

func _on_fire_timer_timeout() -> void:
	"""Re-enable firing after cooldown."""
	can_fire = true
