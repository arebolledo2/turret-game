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
## Presentation and projectile creation are injected collaborators.

# Dependencies (set via initialize)
var turret: Node2D = null
var turret_type: String = ""
var stats: Dictionary = {}
var combat_stats: CombatStats = CombatStats.new({})
var effects: TurretAttackEffects
var emitter: ProjectileEmitter
var combat_time: float = 0.0

# Combat state
var target: Node2D = null
var can_fire: bool = true
var fire_timer: Timer = null
var projectile_scene: PackedScene

# Melee state
var melee_rotation: float = 0.0
var melee_hitbox: Area2D = null
var melee_hit_cooldowns: Dictionary = {}

# Deployable (mine) state
var active_mines: Array = []
var mine_scene: PackedScene = null

func initialize(p_turret: Node2D, p_turret_type: String, p_stats: Dictionary, presentation: TurretAttackEffects = null, projectile_emitter: ProjectileEmitter = null) -> void:
	"""Initialize component with required references."""
	assert(p_turret != null, "TurretCombat: turret reference required")
	turret = p_turret
	turret_type = p_turret_type
	combat_stats = CombatStats.new(p_stats)
	stats = combat_stats.to_dictionary()
	effects = presentation if presentation != null else TurretAttackEffects.new()
	effects.turret = turret
	effects.turret_type = turret_type
	effects.stats = stats
	emitter = projectile_emitter if projectile_emitter != null else ProjectileEmitter.new()
	if emitter.parent == null:
		emitter.parent = turret.get_tree().current_scene if turret.get_tree().current_scene else turret.get_tree().root

	# Preload projectile scene
	projectile_scene = preload("res://scenes/projectile.tscn")

	# Setup fire rate timer
	fire_timer = Timer.new()
	fire_timer.one_shot = true
	_update_fire_timer()
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	turret.add_child(fire_timer)

	# Setup melee hitbox if this is a melee turret
	if TurretRegistry.has_attack_style(turret_type, GameEnums.AttackStyle.MELEE):
		_setup_melee_hitbox()

	# Preload mine scene if deployable turret
	if TurretRegistry.has_attack_style(turret_type, GameEnums.AttackStyle.DEPLOYABLE):
		mine_scene = preload("res://scenes/mine.tscn")

func update_stats(new_stats: Dictionary) -> void:
	"""Update stats cache and fire timer."""
	combat_stats = CombatStats.new(new_stats)
	stats = combat_stats.to_dictionary()
	if effects != null:
		effects.stats = stats
	if fire_timer:
		_update_fire_timer()

func _update_fire_timer() -> void:
	"""Update fire timer based on current fire rate."""
	var current_fire_rate: float = combat_stats.fire_rate
	if current_fire_rate > 0:
		fire_timer.wait_time = 1.0 / current_fire_rate
	else:
		fire_timer.wait_time = 1.0

func process(delta: float = 0.0) -> void:
	"""Process combat logic (targeting and firing)."""
	combat_time += delta
	for enemy_id in melee_hit_cooldowns.keys():
		if combat_time - melee_hit_cooldowns[enemy_id] >= 0.3:
			melee_hit_cooldowns.erase(enemy_id)
	# Handle melee rotation
	if TurretRegistry.has_attack_style(turret_type, GameEnums.AttackStyle.MELEE):
		_process_melee_rotation(delta)
		return # Skip normal targeting

	find_target()

	# Fire if target is in range and can fire
	if target and is_instance_valid(target) and can_fire:
		fire()

func find_target() -> void:
	"""Find target in range for firing."""
	var current_range: float = combat_stats.attack_range
	var targeting = combat_stats.targeting
	# Compared in squared space throughout - ordering is identical to real
	# distance, and this avoids a sqrt per enemy per turret per frame.
	var range_sq := current_range * current_range
	var origin := turret.global_position

	# In Tunneling mode, also check for tunnel door as a valid target
	if GameModeService.should_spawn_tunnel_door():
		var doors = turret.get_tree().get_nodes_in_group("tunnel_doors")
		for door in doors:
			if not is_instance_valid(door):
				continue
			if origin.distance_squared_to(door.global_position) <= range_sq:
				# Door is highest priority target
				target = door
				return

	target = TargetSelection.select(origin, EnemyQuery.get_enemies(turret.get_tree()), current_range, targeting == "farthest")

func find_tracking_target() -> Node2D:
	return TargetSelection.select(turret.global_position, EnemyQuery.get_enemies(turret.get_tree()))

func fire() -> void:
	"""Execute firing logic based on turret attack style."""
	if not can_fire:
		return

	can_fire = false
	fire_timer.start()

	# Determine attack style
	var turret_def = TurretRegistry.get_type(turret_type)
	var attack_styles = turret_def.get("attack_styles", [])

	if GameEnums.AttackStyle.MELEE in attack_styles:
		return # Melee is passive, no firing action
	elif GameEnums.AttackStyle.DEPLOYABLE in attack_styles:
		_fire_deployable()
	elif GameEnums.AttackStyle.PROJECTILE in attack_styles:
		_fire_projectile()
	elif GameEnums.AttackStyle.CHAIN in attack_styles:
		_fire_chain()
	elif GameEnums.AttackStyle.INSTANT in attack_styles:
		_fire_instant()
	elif GameEnums.AttackStyle.AOE in attack_styles:
		_fire_aoe_pulse()

	# Keep the firing moment readable even for attacks whose projectile or
	# impact happens later. TurretVisuals owns the actual presentation.
	if turret.has_method("flash_muzzle"):
		turret.flash_muzzle()

	Events.turret_fired.emit(turret)

func _fire_projectile() -> void:
	"""Fire a projectile at the target."""
	if target == null or projectile_scene == null:
		return

	# Roll for crit
	var is_crit := TurretStatsService.roll_turret_crit()
	var base_damage := combat_stats.damage_or(15.0)
	var final_damage := base_damage
	if is_crit:
		final_damage = TurretStatsService.calculate_turret_crit_damage(base_damage)

	# Determine damage type
	var turret_def = TurretRegistry.get_type(turret_type)
	var damage_types = turret_def.get("damage_types", [GameEnums.DamageType.PHYSICAL])
	var dtype = damage_types[0] if not damage_types.is_empty() else GameEnums.DamageType.PHYSICAL

	# Calculate direction to target
	var direction = turret.global_position.direction_to(target.global_position)

	# Create modified stats with crit damage
	var modified_stats := stats.duplicate()
	modified_stats["damage"] = final_damage

	emitter.emit_shot(turret.global_position, direction, modified_stats, true, dtype, is_crit)

func _fire_instant() -> void:
	"""Apply instant hitscan damage to target."""
	if target == null or not is_instance_valid(target):
		return

	# Roll for crit
	var is_crit := TurretStatsService.roll_turret_crit()
	var base_damage := combat_stats.damage_or(15.0)
	var final_damage := base_damage
	if is_crit:
		final_damage = TurretStatsService.calculate_turret_crit_damage(base_damage)

	# Apply damage immediately
	if target.has_method("take_damage"):
		target.take_damage(final_damage, is_crit)

	# Visual tracer
	effects.draw_tracer(target.global_position)

func _fire_aoe_pulse() -> void:
	"""Damage all enemies in range with a pulse."""
	var enemies := EnemyQuery.get_enemies(turret.get_tree())
	var hit_count = 0
	var current_range: float = combat_stats.attack_range
	var base_damage: float = combat_stats.damage_or(15.0)

	# Visual pulse
	effects.spawn_pulse_effect()

	# Get slow parameters if this turret applies slow
	var slow_intensity: float = stats.get("slow_intensity", 0.0)
	var slow_duration: float = stats.get("slow_duration", 0.0)

	# Roll crit once for entire pulse (all enemies get same crit state)
	var is_crit := TurretStatsService.roll_turret_crit()
	var final_damage := base_damage
	if is_crit:
		final_damage = TurretStatsService.calculate_turret_crit_damage(base_damage)

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var dist = turret.global_position.distance_to(enemy.global_position)
		if dist <= current_range:
			if enemy.has_method("take_damage"):
				enemy.take_damage(final_damage, is_crit)
				hit_count += 1

			# Apply slow effect if configured
			if slow_intensity > 0 and slow_duration > 0 and enemy.has_method("apply_status_effect"):
				var turret_def = TurretRegistry.get_type(turret_type)
				var damage_types = turret_def.get("damage_types", [])
				var dtype = damage_types[0] if not damage_types.is_empty() else GameEnums.DamageType.ELECTRIC
				enemy.apply_status_effect(dtype, 0.0, slow_duration, 1.0, slow_intensity)

	if hit_count > 0:
		Events.aoe_explosion.emit(turret.global_position, current_range, final_damage)

func _fire_chain() -> void:
	"""Fire chain lightning that bounces between enemies."""
	if target == null or not is_instance_valid(target):
		return

	var chain_count = int(stats.get("chain_count", 3))
	var chain_range = stats.get("chain_range", 150.0)
	var chain_decay = stats.get("chain_decay", 0.7)
	var base_damage: float = combat_stats.damage_or(15.0)

	# Roll crit once for initial hit
	var is_crit := TurretStatsService.roll_turret_crit()
	var initial_damage := base_damage
	if is_crit:
		initial_damage = TurretStatsService.calculate_turret_crit_damage(base_damage)

	var dmg = initial_damage
	var current_target = target
	var hit_enemies = []
	var last_pos = turret.global_position

	# Chain loop
	for i in range(chain_count + 1):
		if not is_instance_valid(current_target):
			break

		# Hit current target (only first hit is crit, subsequent decay from crit damage)
		if current_target.has_method("take_damage"):
			var this_is_crit := (i == 0 and is_crit) # Only first hit displays as crit
			current_target.take_damage(dmg, this_is_crit)

		hit_enemies.append(current_target)

		# Visual arc
		effects.draw_lightning_arc(last_pos, current_target.global_position)
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
	return TargetSelection.select(pos, EnemyQuery.get_enemies(turret.get_tree()), range_limit, false, excluded)

func _on_fire_timer_timeout() -> void:
	"""Re-enable firing after cooldown."""
	can_fire = true

# Melee turret functions

func _setup_melee_hitbox() -> void:
	"""Setup collision area for melee turret."""
	melee_hitbox = Area2D.new()
	melee_hitbox.name = "MeleeHitbox"

	# Set collision layers: projectile layer (4) to hit enemy hurtboxes (32)
	melee_hitbox.collision_layer = 4
	melee_hitbox.collision_mask = 32

	# Create rectangular collision shape for the bat
	var collision_shape = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	var swing_radius = stats.get("range", 80.0)
	# Vertical orientation: thin in X, long in Y (bat points up)
	rect_shape.size = Vector2(swing_radius * 0.3, swing_radius)
	collision_shape.shape = rect_shape
	# Offset upward to match vertical bat sprite
	collision_shape.position = Vector2(0, -swing_radius / 2)

	melee_hitbox.add_child(collision_shape)
	turret.add_child(melee_hitbox)

	# Attach debug visualization script
	var debug_script = preload("res://scripts/components/melee_hitbox_debug.gd")
	melee_hitbox.set_script(debug_script)

	# Connect collision signal
	melee_hitbox.area_entered.connect(_on_melee_hit)

func _on_melee_hit(hurtbox: Area2D) -> void:
	"""Handle melee collision with enemy hurtbox."""
	if not hurtbox.is_in_group("enemy_hurtbox"):
		return

	var enemy = hurtbox.get_parent()
	if not enemy or not enemy.is_in_group("enemies"):
		return

	# Cooldown check (0.3 second cooldown per enemy)
	var enemy_id = enemy.get_instance_id()
	var current_time = combat_time
	if melee_hit_cooldowns.has(enemy_id):
		if current_time - melee_hit_cooldowns[enemy_id] < 0.3:
			return
	melee_hit_cooldowns[enemy_id] = current_time

	# Roll for crit
	var is_crit := TurretStatsService.roll_turret_crit()
	var base_damage := combat_stats.damage_or(8.0)
	var final_damage := base_damage
	if is_crit:
		final_damage = TurretStatsService.calculate_turret_crit_damage(base_damage)

	# Apply damage
	if enemy.has_method("take_damage"):
		enemy.take_damage(final_damage, is_crit)

	# Apply knockback
	var knockback_force = stats.get("knockback_force", 80.0)
	if knockback_force > 0 and enemy.has_method("apply_knockback"):
		var knockback_dir = turret.global_position.direction_to(enemy.global_position)
		enemy.apply_knockback(knockback_force, knockback_dir)

	Events.turret_fired.emit(turret) # For stats tracking

func _process_melee_rotation(delta: float) -> void:
	"""Continuously rotate melee weapon."""
	var rotation_rate = stats.get("rotation_rate", 360.0)
	melee_rotation += rotation_rate * delta

	if melee_rotation >= 360.0:
		melee_rotation -= 360.0

	# Apply rotation to hitbox
	if melee_hitbox:
		melee_hitbox.rotation_degrees = melee_rotation

	# Rotate only the bat weapon sprite (not the entire turret)
	var weapon_sprite = turret.get_node_or_null("MeleeBat")
	if weapon_sprite:
		weapon_sprite.rotation_degrees = melee_rotation

# Mine turret functions

func _fire_deployable() -> void:
	"""Deploy a mine within turret range."""
	if mine_scene == null:
		return

	# Check max mines limit
	var max_mines = int(stats.get("max_mines", 5))
	_clean_invalid_mines()

	if active_mines.size() >= max_mines:
		# At capacity, don't spawn
		return

	# Random position within range
	var deploy_range = stats.get("range", 150.0)
	var angle = GameRandom.gameplay.randf() * TAU
	var distance = GameRandom.gameplay.randf() * deploy_range
	var spawn_offset = Vector2(cos(angle), sin(angle)) * distance
	var spawn_pos = turret.global_position + spawn_offset

	# Spawn mine
	var mine = mine_scene.instantiate()
	var parent = turret.get_tree().current_scene if turret.get_tree().current_scene else turret.get_tree().root
	parent.add_child(mine)
	mine.global_position = spawn_pos

	# Setup mine with stats
	var damage = combat_stats.damage_or(15.0)
	var explosive_radius = stats.get("explosive_radius", 70.0)
	var proximity_radius = stats.get("proximity_radius", 40.0)
	var knockback = stats.get("knockback_force", 150.0)
	mine.setup(damage, explosive_radius, proximity_radius, knockback, turret)

	active_mines.append(mine)

func _clean_invalid_mines() -> void:
	"""Remove mines that have been destroyed."""
	active_mines = active_mines.filter(func(m): return is_instance_valid(m))

func _on_mine_exploded(mine: Node2D) -> void:
	"""Remove exploded mine from active mines."""
	var idx = active_mines.find(mine)
	if idx >= 0:
		active_mines.remove_at(idx)
