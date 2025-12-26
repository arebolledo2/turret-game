extends CharacterBody2D

# Stats (configured from Globals)
var max_health: float = 60.0
var current_health: float
var xp_value: int = 100
var gold_value: int = 25
var wave: int = 1

# Scatter config (for destruction)
var scatter_count: int = 5
var scatter_radius: float = 80.0

# State
var is_dying: bool = false

# Visuals
var base_color: Color = Color.WHITE # Preserve original sprite colors

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar
@onready var glow: Sprite2D = $GlowEffect
@onready var icon_label: Label = $IconLabel

func _ready() -> void:
	add_to_group("tech_drops")
	add_to_group("enemies") # So turrets can target them

	# Load constants from Globals
	scatter_count = Globals.TECH_DROP_SCATTER_COUNT
	scatter_radius = Globals.TECH_DROP_SCATTER_RADIUS
	xp_value = Globals.TECH_DROP_XP_REWARD
	gold_value = Globals.TECH_DROP_GOLD_REWARD

	# Setup visuals
	if sprite:
		sprite.modulate = base_color

	if icon_label:
		icon_label.visible = false


	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

	# Play spawn animation
	play_spawn_animation()

	# Start pulsing glow
	if glow:
		start_glow_pulse()

func _physics_process(delta: float) -> void:
	# Tech drop doesn't move, but keep physics active for collision
	velocity = Vector2.ZERO
	move_and_slide()

func initialize(spawn_wave: int) -> void:
	"""Initialize tech drop with wave-scaled health."""
	wave = spawn_wave

	# Use tank enemy HP as baseline and apply wave scaling
	var scaled_stats = Globals.get_enemy_stats_for_wave("tank", wave)
	max_health = scaled_stats["health"] * 0.5 # 50% of tank HP
	current_health = max_health

	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

func take_damage(amount: float) -> void:
	"""Handle damage from projectiles."""
	if is_dying:
		return

	current_health -= amount

	if health_bar:
		health_bar.value = current_health

	# Visual feedback
	Events.damage_dealt.emit(global_position, amount)
	flash_damage()

	if current_health <= 0:
		die_from_destruction()

func die_from_destruction() -> void:
	"""Tech drop was destroyed by turrets - scatter rewards."""
	if is_dying:
		return
	is_dying = true

	# Scatter XP/gold drops
	scatter_rewards()

	# Roll for item drop
	_try_drop_item()

	# Emit signal
	Events.tech_drop_destroyed.emit(self, global_position)

	# Play destruction effect
	play_destruction_effect()

	queue_free()


func _try_drop_item() -> void:
	"""Roll for a random item drop based on luck."""
	var item_id := LootService.roll_for_item_drop(wave)
	if not item_id.is_empty():
		LootService.add_found_item(item_id)
		Events.loot_item_found.emit(item_id)

func scatter_rewards() -> void:
	"""Emit xp_dropped signals to spawn XP pickups in scattered positions."""
	var xp_per_drop = xp_value / scatter_count

	for i in scatter_count:
		# Calculate random position within scatter radius
		var angle = randf() * TAU
		var distance = randf() * scatter_radius
		var offset = Vector2(cos(angle), sin(angle)) * distance
		var drop_pos = global_position + offset

		# Emit signal - DropSpawner will create the actual pickup
		Events.xp_dropped.emit(drop_pos, xp_per_drop)

func despawn() -> void:
	"""Wave ended - fade out with no rewards."""
	if is_dying:
		return
	is_dying = true

	# No rewards
	Events.tech_drop_despawned.emit(self)

	# Gentle fade
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

func flash_damage() -> void:
	"""Flash white when taking damage."""
	if sprite:
		sprite.modulate = Color.WHITE
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", base_color, 0.1)

func play_spawn_animation() -> void:
	"""Scale up from zero with bounce."""
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2.ONE, 0.3)

func play_destruction_effect() -> void:
	"""Explosion effect on destruction."""
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE * 2.0, 0.2)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.2)

func start_glow_pulse() -> void:
	"""Pulsing glow effect."""
	if not glow:
		return

	glow.modulate = base_color
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(glow, "modulate:a", 0.8, 1.0)
	tween.tween_property(glow, "modulate:a", 0.3, 1.0)
