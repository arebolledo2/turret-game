extends Area2D

@export var speed: float = 500.0
@export var damage: float = 10.0
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.RIGHT
var is_player_projectile: bool = true
var is_setup: bool = false
var is_crit: bool = false

# Extended stats for turret types
var pierce: int = 0 # Number of enemies to pass through (0 = single target)
var pierce_count: int = 0 # Enemies already hit
var aoe_radius: float = 0.0 # If > 0, explodes on hit
var damage_type: GameEnums.DamageType = GameEnums.DamageType.PHYSICAL
var dot_damage: float = 0.0
var dot_duration: float = 0.0
var dot_tick_rate: float = 1.0
var knockback_force: float = 0.0 # Knockback force for explosions
var hit_enemies: Array[Node2D] = [] # Track enemies hit (for pierce)

var _time_alive: float = 0.0

## Assigned by NodePool. Called instead of queue_free() at end of life.
var pool_release: Callable = Callable()

## Set between the despawn request and the deferred release, so a projectile
## that hits several hurtboxes in one physics frame only despawns once.
var _is_despawning: bool = false

@onready var _sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var _trail: Line2D = get_node_or_null("Trail")

func _ready() -> void:
	# Render above all gameplay entities
	z_index = 5

	# Connect area entered signal for hurtbox detection
	area_entered.connect(_on_hurtbox_entered)


## End of life. Returns to the pool when pooled, otherwise frees as before.
## Safe to call repeatedly and from inside a physics callback.
func _despawn() -> void:
	if _is_despawning:
		return
	_is_despawning = true

	# Stop interacting immediately, even though the release itself is deferred.
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	if pool_release.is_valid():
		pool_release.call_deferred(self)
	else:
		queue_free()


## Handed out of the pool: restore physics interaction. Collision layer and mask
## are set by setup()/setup_extended() immediately after.
func _pool_acquired() -> void:
	_is_despawning = false
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	if _trail:
		_trail.visible = false


## Returned to the pool. Every field set by setup() *or* setup_extended() must be
## reset here: setup() does not touch the extended stats, so without this a
## pierce/AoE/DoT projectile's properties would leak into a later basic one.
func _pool_released() -> void:
	_time_alive = 0.0
	_is_despawning = false

	direction = Vector2.RIGHT
	speed = 500.0
	damage = 10.0
	is_player_projectile = true
	is_setup = false
	is_crit = false

	pierce = 0
	pierce_count = 0
	aoe_radius = 0.0
	damage_type = GameEnums.DamageType.PHYSICAL
	dot_damage = 0.0
	dot_duration = 0.0
	dot_tick_rate = 1.0
	knockback_force = 0.0
	hit_enemies.clear()

	rotation = 0.0
	if _sprite:
		_sprite.rotation = 0.0
		_sprite.modulate = Color.WHITE
	if _trail:
		_trail.visible = false
		_trail.default_color = Color(1.0, 0.8, 0.25, 0.45)
		_trail.width = 5.0

	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

## Basic setup for simple projectiles (backwards compatible)
func setup(dir: Vector2, spd: float, dmg: float, from_player: bool, crit: bool = false) -> void:
	direction = dir.normalized()
	speed = spd
	damage = dmg
	is_player_projectile = from_player
	is_crit = crit
	is_setup = true
	_configure_flight_visuals()

	# Set collision - deferred to avoid physics query error
	_apply_collision_deferred()

## Extended setup for turret-typed projectiles
func setup_extended(stats: Dictionary, dir: Vector2, from_player: bool, dtype: GameEnums.DamageType, crit: bool = false) -> void:
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
	is_crit = crit
	is_setup = true
	_configure_flight_visuals()

	# Set collision
	_apply_collision_deferred()

## Apply collision layer/mask on the next idle frame, so we never mutate them
## while the physics server is mid-query.
func _apply_collision_deferred() -> void:
	set_deferred("collision_layer", GameConstants.COLLISION_LAYER_PROJECTILE)
	if is_player_projectile:
		set_deferred("collision_mask", GameConstants.COLLISION_MASK_ENEMY_AND_TUNNEL)
	else:
		set_deferred("collision_mask", GameConstants.COLLISION_MASK_PLAYER)


func _configure_flight_visuals() -> void:
	"""Aim the pooled projectile and configure a lightweight colored trail."""
	rotation = direction.angle()
	if not _trail:
		return

	var trail_color := _get_projectile_color()
	trail_color.a = 0.8 if is_crit else 0.5
	_trail.default_color = trail_color
	_trail.width = 7.0 if is_crit else 5.0
	_trail.visible = true


func _get_projectile_color() -> Color:
	match damage_type:
		GameEnums.DamageType.PLASMA:
			return Color("AA44DD")
		GameEnums.DamageType.FIRE:
			return Color("FF6633")
		GameEnums.DamageType.ELECTRIC:
			return Color("44DDDD")
		_:
			return Color("FFCC55") if is_player_projectile else Color("FF5566")

func _physics_process(delta: float) -> void:
	# Auto-destroy after lifetime
	_time_alive += delta
	if _time_alive >= lifetime:
		_despawn()
		return

	var start_position := global_position
	var end_position := start_position + direction * speed * delta
	_move_with_swept_collision(start_position, end_position)

	# Rotate sprite counter-clockwise at 2 rotations per second
	# 2 rotations/sec = 720 degrees/sec = -4π radians/sec (negative for counter-clockwise)
	if _sprite:
		_sprite.rotation -= TAU * GameConstants.PROJECTILE_SPIN_RATE * delta


func _move_with_swept_collision(start_position: Vector2, end_position: Vector2) -> void:
	"""Move across the full frame while checking the path for hurtboxes."""
	if not is_inside_tree() or get_world_2d() == null:
		global_position = end_position
		return

	var sweep_direction := direction.normalized()
	if sweep_direction == Vector2.ZERO:
		global_position = end_position
		return

	var space_state := get_world_2d().direct_space_state
	var query_mask := GameConstants.COLLISION_MASK_ENEMY_AND_TUNNEL if is_player_projectile else GameConstants.COLLISION_MASK_PLAYER
	var excluded_rids: Array[RID] = [get_rid()]
	var sweep_start := start_position
	var epsilon_squared := GameConstants.PROJECTILE_SWEEP_EPSILON * GameConstants.PROJECTILE_SWEEP_EPSILON

	for _hit_index in range(GameConstants.PROJECTILE_MAX_SWEEP_HITS):
		if sweep_start.distance_squared_to(end_position) <= epsilon_squared:
			global_position = end_position
			return

		var query := PhysicsRayQueryParameters2D.create(sweep_start, end_position, query_mask)
		query.collide_with_areas = true
		query.collide_with_bodies = false
		query.exclude = excluded_rids
		var hit := space_state.intersect_ray(query)
		if hit.is_empty():
			global_position = end_position
			return

		var collider := hit.get("collider") as Area2D
		var hit_position: Vector2 = hit.get("position", sweep_start)
		if collider == null:
			sweep_start = hit_position + sweep_direction * GameConstants.PROJECTILE_SWEEP_EPSILON
			continue

		var collider_rid := collider.get_rid()
		if collider_rid not in excluded_rids:
			excluded_rids.append(collider_rid)

		# Only the same targets handled by the area_entered callback should
		# consume a swept hit. Other areas on the mask are simply passed over.
		if not _is_swept_collision_target(collider):
			sweep_start = hit_position + sweep_direction * GameConstants.PROJECTILE_SWEEP_EPSILON
			continue

		global_position = hit_position
		_on_hurtbox_entered(collider)
		if _is_despawning:
			return

		# Pierce projectiles continue through the remainder of this frame. The
		# collider is excluded above so a large step cannot get stuck inside it.
		sweep_start = hit_position + sweep_direction * GameConstants.PROJECTILE_SWEEP_EPSILON

	global_position = end_position


func _is_swept_collision_target(collider: Area2D) -> bool:
	if is_player_projectile and collider.is_in_group("enemy_hurtbox"):
		return true
	if not is_player_projectile and collider.is_in_group("player_hurtbox"):
		return true

	var parent := collider.get_parent()
	return parent != null and parent.is_in_group("tunnel_doors")

func _on_hurtbox_entered(hurtbox: Area2D) -> void:
	DebugService.log(DebugService.COMBAT, "Projectile: Collision with area: ", hurtbox, " name: ", hurtbox.name)
	DebugService.log(DebugService.COMBAT, "Projectile: Is enemy_hurtbox: ", hurtbox.is_in_group("enemy_hurtbox"))
	DebugService.log(DebugService.COMBAT, "Projectile: Is tunnel_door: ", hurtbox.is_in_group("tunnel_doors"))
	DebugService.log(DebugService.COMBAT, "Projectile: Is player_hurtbox: ", hurtbox.is_in_group("player_hurtbox"))

	# Handle enemy projectiles hitting player
	if not is_player_projectile and hurtbox.is_in_group("player_hurtbox"):
		DebugService.log(DebugService.COMBAT, "Projectile: Enemy projectile hit player!")
		var player = hurtbox.get_parent()
		if player and player.has_method("take_damage"):
			player.take_damage(damage)
			_despawn()
		return

	# Check if this is a tunnel door - handle specially
	var parent = hurtbox.get_parent()
	if parent and parent.is_in_group("tunnel_doors"):
		DebugService.log(DebugService.COMBAT, "Projectile: Hit tunnel door!")
		if parent.has_method("take_damage"):
			parent.take_damage(damage)
			_despawn()
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
		_despawn()
		return
	
	# Apply direct damage (with Executioner's Mark bonus)
	if enemy.has_method("take_damage"):
		var final_damage := _calculate_damage_with_executioner(damage, enemy)
		enemy.take_damage(final_damage, is_crit)
	
	# Apply DoT if applicable
	if dot_damage > 0 and dot_duration > 0 and enemy.has_method("apply_status_effect"):
		enemy.apply_status_effect(damage_type, dot_damage, dot_duration, dot_tick_rate)
	
	# Handle pierce
	pierce_count += 1
	if pierce_count > pierce:
		_despawn()

## Execute AoE explosion - damages all enemies in radius
func _do_aoe_explosion() -> void:
	var enemies := EnemyQuery.get_enemies(get_tree())
	var explosion_pos = global_position
	var radius_sq := aoe_radius * aoe_radius

	Events.aoe_explosion.emit(explosion_pos, aoe_radius, damage)

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		if explosion_pos.distance_squared_to(enemy.global_position) <= radius_sq:
			if enemy.has_method("take_damage"):
				var aoe_damage := _calculate_damage_with_executioner(damage, enemy)
				enemy.take_damage(aoe_damage, is_crit)

			# Apply DoT to all enemies in AoE
			if dot_damage > 0 and dot_duration > 0 and enemy.has_method("apply_status_effect"):
				enemy.apply_status_effect(damage_type, dot_damage, dot_duration, dot_tick_rate)

			# Apply knockback
			if knockback_force > 0 and enemy.has_method("apply_knockback"):
				var knockback_dir := explosion_pos.direction_to(enemy.global_position)
				enemy.apply_knockback(knockback_force, knockback_dir)

	# Visual feedback for explosion (spawn effect or flash)
	_spawn_explosion_effect()

## Calculate damage with Executioner's Mark bonus (+50% to enemies below 25% HP)
func _calculate_damage_with_executioner(base_damage: float, enemy: Node2D) -> float:
	# Check if player owns the Executioner's Mark item
	if ItemTrackingService.item_counts.get("executioners_mark", 0) <= 0:
		return base_damage

	var health_percent := 1.0
	if enemy.has_method("get_health_percent"):
		health_percent = enemy.get_health_percent()
	elif "current_health" in enemy and "max_health" in enemy and enemy.max_health > 0:
		health_percent = enemy.current_health / enemy.max_health

	if health_percent < GameConstants.EXECUTIONER_MARK_HEALTH_THRESHOLD:
		return base_damage * GameConstants.EXECUTIONER_MARK_DAMAGE_MULT
	return base_damage


## Spawn a visual explosion effect
func _spawn_explosion_effect() -> void:
	# Create a circle polygon similar to shock turret pulse
	var viz = Polygon2D.new()
	
	# Create circle polygon with the aoe_radius
	var points = PackedVector2Array()
	var segments = GameConstants.VISUAL_POLYGON_SEGMENTS
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
