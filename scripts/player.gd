extends CharacterBody2D

# Stats from Services (can be overridden in editor)
@export var max_health: float = 100.0
@export var speed: float = 300.0
@export var pickup_radius: float = 50.0
@export var invincibility_time: float = 0.5

var current_health: float
var is_invincible: bool = false
var is_dead: bool = false
var invincibility_timer: Timer
var animation_timer: Timer
var heal_timer: Timer
var current_frame: int = 0


# Projectile scene (will be set up)
var projectile_scene: PackedScene

@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_timer: Timer = $AnimationTimer

# Components
@onready var turret_handler: PlayerTurretHandler = $Components/PlayerTurretHandler
@onready var movement: PlayerMovement = $Components/PlayerMovement
@onready var combat: PlayerCombat = $Components/PlayerCombat
@onready var visuals: PlayerVisuals = $Components/PlayerVisuals
@onready var collision_manager: CollisionManager = $CollisionManager

func _ready() -> void:
	# Initialize from services
	max_health = PlayerStatsService.get_player_max_health(DifficultyService.get_difficulty_config()["player_health_mult"])
	speed = PlayerStatsService.get_player_speed()
	pickup_radius = PlayerStatsService.get_pickup_radius()
	invincibility_time = GameConstants.PLAYER_INVINCIBILITY_TIME

	current_health = max_health
	add_to_group("player")

	# Setup invincibility timer
	invincibility_timer = Timer.new()
	invincibility_timer.one_shot = true
	invincibility_timer.timeout.connect(_on_invincibility_timeout)
	add_child(invincibility_timer)
	
	# Setup animation timer
	anim_timer.timeout.connect(_on_animation_timer_timeout)

	# Setup heal timer for health regeneration
	heal_timer = Timer.new()
	heal_timer.one_shot = false
	heal_timer.timeout.connect(_on_heal_timer_timeout)
	add_child(heal_timer)

	# Connect to debug toggle event
	Events.hitbox_debug_toggled.connect(_on_debug_toggled)
	
	# Connect to game mode entity spawning
	Events.defense_target_spawned.connect(_on_defense_target_spawned)
	Events.asset_preset_changed.connect(_on_asset_preset_changed)
	Events.asset_config_changed.connect(_on_asset_config_changed)

	# Initialize components
	turret_handler.initialize(self)
	movement.initialize(self)
	combat.initialize(self, weapon_pivot)
	visuals.initialize(self, movement, sprite)
	_apply_asset_config()

	# Setup audio listener for spatial sounds
	var listener = AudioListener2D.new()
	add_child(listener)
	listener.make_current()

func _on_debug_toggled(type: int, _enabled: bool) -> void:
	if type == GameEnums.HitboxType.PHYSICS:
		queue_redraw()

func _on_defense_target_spawned(_target: Node2D, pos: Vector2) -> void:
	if GameModeService.is_escort_mode_active():
		# Spawn next to payload with a slight offset
		global_position = pos + GameConstants.PLAYER_ESCORT_SPAWN_OFFSET
		DebugService.log(DebugService.ENTITY, "Player: Teleported to escort start position: ", global_position)

func _draw() -> void:
	if not SettingsService.debug_hitbox_flags[GameEnums.HitboxType.PHYSICS]:
		return
	
	if has_node("CollisionShape2D"):
		var col_shape = $CollisionShape2D
		if col_shape.shape:
			var shape = col_shape.shape
			var offset = col_shape.position
			var color = Color(1.0, 1.0, 1.0, 0.4) # White for physics
			var outline_color = Color(1.0, 1.0, 1.0, 0.8)

			if shape is CircleShape2D:
				draw_circle(offset, shape.radius, color)
				draw_arc(offset, shape.radius, 0, TAU, 32, outline_color, 1.0)
			elif shape is RectangleShape2D:
				var rect = Rect2(offset - shape.size / 2.0, shape.size)
				draw_rect(rect, color, true)
				draw_rect(rect, outline_color, false, 1.0)

func _physics_process(delta: float) -> void:
	# Don't process if game hasn't started
	if not GameStateService.is_game_active:
		return

	velocity = movement.process(delta)
	move_and_slide()

	# Round position to prevent sub-pixel rendering jitter
	global_position = global_position.round()

	# Clamp to arena bounds after rounding
	var clamped_pos := ArenaBoundsService.clamp_to_arena(global_position, 20.0)
	if not global_position.is_equal_approx(clamped_pos):
		global_position = clamped_pos
		velocity = Vector2.ZERO # Stop movement when hitting boundary

	# Turret pickup/placement system
	turret_handler.process(delta)
	
	# Turret range toggle (Tab / Y button)
	if Input.is_action_just_pressed("toggle_range"):
		SettingsService.show_turret_ranges = not SettingsService.show_turret_ranges
		Events.turret_range_toggled.emit(SettingsService.show_turret_ranges)

	# Combat systems
	combat.process(delta)

	# Visual orientation/state from asset config
	visuals.process(delta)
	
	# Handle invincibility visual
	if is_invincible:
		sprite.modulate.a = 0.5 if fmod(Time.get_ticks_msec(), GameConstants.INVINCIBILITY_FLASH_INTERVAL_MS) < GameConstants.INVINCIBILITY_FLASH_THRESHOLD_MS else 1.0
	else:
		sprite.modulate.a = 1.0

	# Health regeneration
	update_heal_timer()

# Temporary facades for tests (will be removed later)
var facing_direction: int:
	get:
		return movement.facing_direction if movement else 0
	set(value):
		if movement:
			movement.facing_direction = value

var is_moving: bool:
	get:
		return movement.is_moving if movement else false

func get_direction_from_vector(dir: Vector2) -> int:
	return movement.get_direction_from_vector(dir)

var can_fire: bool:
	get:
		return combat.can_fire if combat else true

var closest_enemy: Node2D:
	get:
		return combat.closest_enemy if combat else null

var carried_turret: Node2D:
	get:
		return turret_handler.carried_turret if turret_handler else null
	set(value):
		if turret_handler:
			turret_handler.carried_turret = value

var nearby_turret: Node2D:
	get:
		return turret_handler.nearby_turret if turret_handler else null
	set(value):
		if turret_handler:
			turret_handler.nearby_turret = value

func pickup_turret(turret: Node2D) -> void:
	turret_handler.pickup_turret(turret)

func find_nearby_turret() -> void:
	turret_handler.find_nearby_turret()

func place_turret() -> void:
	turret_handler.place_turret()

func update_carried_turret_position() -> void:
	turret_handler.update_carried_turret_position()

func drop_carried_turret() -> void:
	turret_handler.force_drop()

func clamp_to_arena() -> void:
	# Keep player within arena bounds (delegates to ArenaBoundsService for isometric support)
	global_position = ArenaBoundsService.clamp_to_arena(global_position, 20.0)

func take_damage(amount: float, is_crit: bool = false) -> void:
	if is_invincible or is_dead:
		return

	# Roll for evasion
	var evasion_chance := PlayerStatsService.get_evasion_chance()
	if evasion_chance > 0 and randf() < evasion_chance:
		DebugService.log(DebugService.COMBAT, "Player EVADED damage!")
		_show_evasion_effect()
		return

	# Apply damage reduction
	var reduction_mult := PlayerStatsService.get_damage_reduction()
	var final_damage := amount * reduction_mult

	current_health -= final_damage
	is_invincible = true
	invincibility_timer.wait_time = invincibility_time
	invincibility_timer.start()

	# Visual feedback - flash red
	sprite.modulate = GameConstants.PLAYER_DAMAGE_FLASH_COLOR
	if visuals:
		visuals.play_damage_reaction(is_crit)

	# Defensive pulse - knockback nearby enemies
	apply_defensive_pulse()

	# Screen shake (if camera exists)
	var camera = get_node_or_null("Camera2D")
	if camera and camera.has_method("shake"):
		camera.shake(0.2, 5)

	# Emit signal
	Events.player_damaged.emit(current_health, max_health)

	# Visual damage numbers
	Events.damage_dealt.emit(global_position, final_damage, is_crit, null)

	if current_health <= 0:
		die()


func _show_evasion_effect() -> void:
	"""Show visual feedback for successful evasion."""
	# Flash white/blue for dodge
	var original_modulate = sprite.modulate
	sprite.modulate = GameConstants.PLAYER_EVASION_FLASH_COLOR
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", original_modulate, 0.2)

func _on_invincibility_timeout() -> void:
	is_invincible = false
	if visuals:
		sprite.modulate = visuals.get_base_modulate()
	else:
		sprite.modulate = Color.WHITE

func _on_animation_timer_timeout() -> void:
	# Cycle through walk animation frames (0-15 for 4x4 grid)
	sprite.frame = (sprite.frame + 1) % GameConstants.PLAYER_ANIMATION_FRAME_COUNT

func die() -> void:
	if is_dead:
		return
	is_dead = true

	# Drop carried turret before death
	drop_carried_turret()

	Events.player_died.emit()
	# Don't queue_free - let GameManager handle game over

func heal(amount: float) -> void:
	current_health = min(current_health + amount, max_health)
	Events.player_damaged.emit(current_health, max_health)

func reset_health() -> void:
	current_health = max_health
	Events.player_damaged.emit(current_health, max_health)

func get_health_percent() -> float:
	return current_health / max_health


## Update heal timer based on current health regen
func update_heal_timer() -> void:
	var interval := PlayerStatsService.get_heal_interval()
	
	# No regen or at full health - stop timer
	if interval < 0 or current_health >= max_health:
		if not heal_timer.is_stopped():
			heal_timer.stop()
		return
	
	# Start or update timer
	if heal_timer.is_stopped():
		heal_timer.wait_time = interval
		heal_timer.start()
	elif not is_equal_approx(heal_timer.wait_time, interval):
		# Regen value changed, update timer
		heal_timer.wait_time = interval


func _on_heal_timer_timeout() -> void:
	if current_health < max_health:
		heal(GameConstants.PLAYER_HEAL_AMOUNT)
	
	# Check if we should stop (now at full health)
	if current_health >= max_health:
		heal_timer.stop()


# =============================================================================
# DEFENSIVE PULSE SYSTEM
# =============================================================================

func apply_defensive_pulse() -> void:
	"""Knockback enemies when player takes damage."""
	var enemies = get_tree().get_nodes_in_group("enemies")
	var pulse_radius: float = GameConstants.PLAYER_DEFENSIVE_PULSE_RADIUS
	var pulse_force: float = GameConstants.PLAYER_DEFENSIVE_PULSE_KNOCKBACK_FORCE

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var distance := global_position.distance_to(enemy.global_position)
		if distance <= pulse_radius:
			if enemy.has_method("apply_knockback"):
				var knockback_dir := global_position.direction_to(enemy.global_position)
				enemy.apply_knockback(pulse_force, knockback_dir)

	# Visual feedback - pulse ring
	spawn_defensive_pulse_visual()

func spawn_defensive_pulse_visual() -> void:
	"""Create visual effect for defensive pulse."""
	var viz = Polygon2D.new()
	var points = PackedVector2Array()
	var segments = GameConstants.VISUAL_POLYGON_SEGMENTS
	for i in range(segments):
		var angle = i * TAU / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * GameConstants.PLAYER_DEFENSIVE_PULSE_RADIUS)
	viz.polygon = points
	viz.color = GameConstants.DEFENSIVE_PULSE_COLOR
	viz.color.a = 0.5
	viz.global_position = global_position

	get_tree().current_scene.add_child(viz)

	var tween = viz.create_tween()
	tween.set_parallel(true)
	tween.tween_property(viz, "scale", Vector2.ONE * 1.4, 0.3)
	tween.tween_property(viz, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(viz.queue_free)


func _apply_asset_config() -> void:
	var config := AssetConfigService.get_player_config()
	if config == null:
		return

	if visuals:
		visuals.apply_asset_config(config)

	if collision_manager and config.collision and config.collision.enabled:
		var profile_path := config.collision.collision_profile_path
		if not profile_path.is_empty() and ResourceLoader.exists(profile_path):
			var profile := load(profile_path)
			if profile:
				collision_manager.apply_profile(profile)


func _on_asset_preset_changed(_preset_name: String) -> void:
	_apply_asset_config()


func _on_asset_config_changed(entity_kind: int, asset_id: String) -> void:
	if entity_kind == EntityAssetConfig.EntityKind.PLAYER and asset_id == "main":
		_apply_asset_config()
