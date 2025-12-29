extends Node
class_name TurretVisuals

## Handles turret visual effects, sprites, and animations.
##
## Responsibilities:
## - Setup base sprite, animated sprite, or icon
## - Handle plasma turret spritesheet setup
## - Range indicator visualization
## - Status indicator UI (buffs/debuffs from items)
## - Pickup indicator (brighten when in player pickup range)
## - Spawn animation
## - Muzzle flash effect

# Dependencies (set via initialize)
var turret: Node2D = null
var turret_type: String = ""
var stats: Dictionary = {}

# Sprite nodes
var base_sprite: Sprite2D = null
var animated_sprite: AnimatedSprite2D = null
var weapon_sprite: Sprite2D = null
var icon_label: Label = null
var range_indicator: Node2D = null
var status_indicators: HBoxContainer = null

# State
var is_in_pickup_range: bool = false
var is_being_carried: bool = false

# Universal visual state (applies to all turrets)
var visual_node: CanvasItem = null  # The node we animate (sprite or animated_sprite)
var original_scale: Vector2 = Vector2.ONE
var original_offset: Vector2 = Vector2.ZERO
var original_position: Vector2 = Vector2.ZERO

# Animation tweens
var spawn_tween: Tween = null
var idle_tween: Tween = null
var effect_tween: Tween = null

func initialize(p_turret: Node2D, p_turret_type: String, p_stats: Dictionary) -> void:
	"""Initialize component with required references."""
	turret = p_turret
	turret_type = p_turret_type
	stats = p_stats
	assert(turret != null, "TurretVisuals: turret reference required")

	# Get sprite node references
	base_sprite = turret.get_node_or_null("BaseSprite")
	animated_sprite = turret.get_node_or_null("AnimatedSprite")
	weapon_sprite = turret.get_node_or_null("WeaponSprite")
	icon_label = turret.get_node_or_null("IconLabel")
	range_indicator = turret.get_node_or_null("RangeIndicator")
	status_indicators = turret.get_node_or_null("StatusIndicators")

	# Setup visuals based on turret type
	setup_visuals()

	# Setup range indicator
	if range_indicator:
		var color = TurretRegistry.get_color(turret_type)
		_update_range_visual()
		range_indicator.modulate = color
		range_indicator.modulate.a = 0.0 # Hidden by default

	# Listen for carry events
	Events.turret_picked_up.connect(_on_turret_picked_up)
	Events.turret_placed.connect(_on_turret_placed)
	Events.turret_dropped.connect(_on_turret_placed) # Same cleanup as placed

	# Listen for range toggle event
	Events.turret_range_toggled.connect(_on_range_toggled)

	# Apply current range visibility state
	if SettingsService.show_turret_ranges:
		show_range()

	# Spawn animation
	play_spawn_animation()

func setup_visuals() -> void:
	"""Setup turret visuals based on type."""
	match turret_type:
		"plasma":
			_setup_plasma_visuals()
		"normal":
			_setup_normal_visuals()
		"fire":
			_setup_fire_visuals()
		"shock":
			_setup_shock_visuals()
		"sniper":
			_setup_sniper_visuals()
		"tesla":
			_setup_tesla_visuals()
		_:
			_setup_icon_fallback()

	# Store visual state after type-specific setup
	_store_visual_state()


func _store_visual_state() -> void:
	"""Store the visual node's original transform state after setup."""
	# Determine which node is the primary visual
	if animated_sprite and animated_sprite.visible:
		visual_node = animated_sprite
	elif base_sprite and base_sprite.visible:
		visual_node = base_sprite
	elif icon_label and icon_label.visible:
		visual_node = icon_label
	else:
		visual_node = null

	if visual_node:
		original_scale = visual_node.scale
		original_position = visual_node.position
		if visual_node is Sprite2D:
			original_offset = visual_node.offset


func _setup_icon_fallback() -> void:
	"""Setup icon-based display for turrets without custom sprites."""
	var turret_config = TurretRegistry.get_type(turret_type)
	var icon = turret_config.get("icon", "🗼")

	if base_sprite:
		# Hide icon if using a custom sprite
		if icon_label:
			icon_label.visible = false
	elif animated_sprite:
		# Start idle animation
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")
		# Hide icon for animated turrets
		if icon_label:
			icon_label.visible = false
	elif icon_label:
		# Fallback to icon for other turret types
		icon_label.visible = true
		icon_label.text = icon
		icon_label.add_theme_font_size_override("font_size", 32)


func _setup_shock_visuals() -> void:
	"""Setup shock turret visuals. Currently uses icon fallback."""
	_setup_icon_fallback()


func _setup_sniper_visuals() -> void:
	"""Setup sniper turret visuals. Currently uses icon fallback."""
	_setup_icon_fallback()


func _setup_tesla_visuals() -> void:
	"""Setup tesla turret visuals. Currently uses icon fallback."""
	_setup_icon_fallback()

func _setup_plasma_visuals() -> void:
	"""Setup plasma turret animation from spritesheet."""
	if not animated_sprite:
		return

	# Hide base static sprite
	if base_sprite:
		base_sprite.visible = false
	if icon_label:
		icon_label.visible = false

	animated_sprite.visible = true

	# Create SpriteFrames programmatically for the plasma turret
	var frames = SpriteFrames.new()
	var tex = load("res://assets/sprites/turret_plasma/plasma_turret_spritesheet.png")

	# 8 frames in the spritesheet
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 8.0)

	var frame_width = tex.get_width() / 8
	var frame_height = tex.get_height()

	for i in range(8):
		var atlas = AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * frame_width, 0, frame_width, frame_height)
		frames.add_frame("idle", atlas)

	animated_sprite.sprite_frames = frames
	animated_sprite.play("idle")

func _setup_normal_visuals() -> void:
	"""Setup normal turret animation from 16-frame horizontal spritesheet."""
	if not animated_sprite:
		return

	# Hide base static sprite
	if base_sprite:
		base_sprite.visible = false
	if icon_label:
		icon_label.visible = false

	animated_sprite.visible = true

	# Create SpriteFrames programmatically for the normal turret
	var frames = SpriteFrames.new()
	var tex = load("res://assets/sprites/turret_basic/turret_idle_spritesheet_4x4.png")

	# Configure animation (16 frames in a single row)
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 8.0) # 8 FPS

	# Calculate frame dimensions (16 columns, 1 row)
	var frame_width = tex.get_width() / 16
	var frame_height = tex.get_height()

	# Extract all 16 frames from horizontal strip
	for i in range(16):
		var atlas = AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * frame_width, 0, frame_width, frame_height)
		frames.add_frame("idle", atlas)

	animated_sprite.sprite_frames = frames
	animated_sprite.play("idle")

func update_stats(new_stats: Dictionary) -> void:
	"""Update stats cache and refresh visuals."""
	stats = new_stats
	if range_indicator:
		_update_range_visual()
	_update_status_indicators()

func _update_range_visual() -> void:
	"""Update range indicator visual to match current range stat."""
	if range_indicator and range_indicator.has_method("set_radius"):
		var current_range: float = stats.get("range", 250.0)
		# Parent turret node is always scale 1.0, no compensation needed
		range_indicator.set_radius(current_range)

func _update_status_indicators() -> void:
	"""Update visual status indicators showing active buffs/debuffs."""
	if not status_indicators:
		return

	# Clear existing indicators
	for child in status_indicators.get_children():
		status_indicators.remove_child(child)
		child.queue_free()

	var turret_manager = get_node_or_null("/root/Main/TurretManager")
	if not turret_manager:
		return

	var active_effects: Array[Dictionary] = []

	# Signal Amplifier
	if ItemRegistry.has_special_effect("signal_amplifier") and ItemTrackingService.item_counts.get("signal_amplifier", 0) > 0:
		var nearby = turret_manager.get_turrets_within_radius(turret.global_position, 200.0)
		var is_buff = nearby.size() > 0
		active_effects.append({
			"icon": "📡",
			"is_buff": is_buff
		})

	# Isolation Protocol
	if ItemRegistry.has_special_effect("isolation_protocol") and ItemTrackingService.item_counts.get("isolation_protocol", 0) > 0:
		var nearby = turret_manager.get_turrets_within_radius(turret.global_position, 250.0)
		var is_buff = nearby.size() == 0
		active_effects.append({
			"icon": "🛡️",
			"is_buff": is_buff
		})

	# Feedback Loop
	if ItemRegistry.has_special_effect("feedback_loop") and ItemTrackingService.item_counts.get("feedback_loop", 0) > 0:
		var nearby = turret_manager.get_turrets_within_radius(turret.global_position, 180.0)
		var count = nearby.size()
		active_effects.append({
			"icon": "🔄",
			"is_buff": count > 0,
			"count": count if count > 0 else null
		})

	# Personal Space (always active as a buff)
	if ItemRegistry.has_special_effect("personal_space") and ItemTrackingService.item_counts.get("personal_space", 0) > 0:
		active_effects.append({
			"icon": "⭕",
			"is_buff": true
		})

	# Chain Reaction (show if buffed)
	if ItemRegistry.has_special_effect("chain_reaction") and ItemTrackingService.item_counts.get("chain_reaction", 0) > 0:
		var turret_id: int = turret.get_instance_id()
		var buffs: Array = BuffSystem.active_buffs.get(turret_id, [])
		for buff in buffs:
			if buff.stat == "fire_rate":
				active_effects.append({
					"icon": "⚡",
					"is_buff": true,
					"count": buff.stack_count
				})
				break

	# Create visual indicators
	for effect in active_effects:
		var panel = PanelContainer.new()
		var label = Label.new()
		label.text = effect.icon
		label.add_theme_font_size_override("font_size", 16)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		# Color based on buff/debuff
		if effect.is_buff:
			panel.modulate = Color(0.2, 1.0, 0.2, 0.9) # Green for buffs
		else:
			panel.modulate = Color(1.0, 0.2, 0.2, 0.9) # Red for debuffs

		# Add count if present
		if effect.has("count") and effect.count != null:
			label.text = effect.icon + "x" + str(effect.count)

		panel.add_child(label)
		status_indicators.add_child(panel)

func flash_muzzle() -> void:
	"""Flash the sprite when firing."""
	var sprite_node: CanvasItem = null
	if animated_sprite:
		sprite_node = animated_sprite
	else:
		sprite_node = base_sprite
	if sprite_node:
		var original_color = sprite_node.modulate
		sprite_node.modulate = Color.WHITE
		var tween = turret.create_tween()
		tween.tween_property(sprite_node, "modulate", original_color, 0.1)

func play_spawn_animation() -> void:
	"""Animate turret spawning in."""
	if not visual_node:
		return

	# Store target scale and zero the visual
	var target_scale = original_scale
	visual_node.scale = Vector2.ZERO

	# Kill any existing spawn tween
	if spawn_tween and spawn_tween.is_valid():
		spawn_tween.kill()

	spawn_tween = turret.create_tween()
	spawn_tween.set_ease(Tween.EASE_OUT)
	spawn_tween.set_trans(Tween.TRANS_BACK)
	# Overshoot then settle to original scale
	spawn_tween.tween_property(visual_node, "scale", target_scale * 1.2, 0.2)
	spawn_tween.tween_property(visual_node, "scale", target_scale, 0.15)

	# Start idle animation after spawn completes
	spawn_tween.tween_callback(_start_idle_animation)


func play_stat_boost_effect() -> void:
	"""Brief visual effect indicating stat boost."""
	if not visual_node:
		return

	# Kill any existing effect tween
	if effect_tween and effect_tween.is_valid():
		effect_tween.kill()

	effect_tween = turret.create_tween()
	effect_tween.set_ease(Tween.EASE_OUT)
	effect_tween.set_trans(Tween.TRANS_ELASTIC)
	effect_tween.tween_property(visual_node, "scale", original_scale * 1.2, 0.15)
	effect_tween.tween_property(visual_node, "scale", original_scale, 0.15)

func show_pickup_indicator() -> void:
	"""Show visual indicator that turret is in pickup range."""
	is_in_pickup_range = true
	# Brighten the turret sprites to indicate it's in pickup range
	var sprite_node: CanvasItem = null
	if base_sprite:
		sprite_node = base_sprite
	else:
		sprite_node = animated_sprite
		
	if sprite_node:
		sprite_node.modulate = Color.WHITE.lightened(0.4)
	if weapon_sprite:
		weapon_sprite.modulate = Color.WHITE.lightened(0.4)

func hide_pickup_indicator() -> void:
	"""Hide visual indicator that turret is in pickup range."""
	is_in_pickup_range = false
	# Reset sprites to normal brightness
	var sprite_node: CanvasItem = null
	if base_sprite:
		sprite_node = base_sprite
	else:
		sprite_node = animated_sprite
		
	if sprite_node:
		sprite_node.modulate = Color.WHITE
	if weapon_sprite:
		weapon_sprite.modulate = Color.WHITE

func _on_turret_picked_up(p_turret: Node2D) -> void:
	"""Handle turret picked up event."""
	if p_turret != turret:
		return
	is_being_carried = true

	# Stop any idle animation
	if idle_tween and idle_tween.is_valid():
		idle_tween.kill()

	# Reset visual state for carrying
	if visual_node:
		visual_node.scale = original_scale
		visual_node.position = original_position
		if visual_node is Sprite2D:
			visual_node.offset = Vector2.ZERO  # Neutral offset while carrying

func _on_turret_placed(p_turret: Node2D, _pos: Vector2 = Vector2.ZERO) -> void:
	"""Handle turret placed/dropped event."""
	if p_turret != turret:
		return
	is_being_carried = false

	# Restore visual state
	if visual_node:
		if visual_node is Sprite2D:
			visual_node.offset = original_offset
		visual_node.scale = original_scale
		visual_node.position = Vector2.ZERO if original_offset != Vector2.ZERO else original_position

	_start_idle_animation()

func _on_range_toggled(show_ranges: bool) -> void:
	"""Handle range toggle event."""
	if show_ranges:
		show_range()
	else:
		hide_range()

func show_range() -> void:
	"""Show range indicator."""
	if range_indicator:
		range_indicator.modulate.a = 0.3

func hide_range() -> void:
	"""Hide range indicator."""
	if range_indicator:
		range_indicator.modulate.a = 0.0


func _setup_fire_visuals() -> void:
	"""Setup fire turret visuals with custom sprite."""
	if not base_sprite:
		return

	# Hide alternatives
	if animated_sprite:
		animated_sprite.visible = false
	if icon_label:
		icon_label.visible = false

	base_sprite.visible = true
	base_sprite.texture = load("res://assets/sprites/turrets/turret_flame.png")
	base_sprite.scale = Vector2(0.125, 0.125)
	base_sprite.modulate = Color.WHITE

	# Store original position (from scene) before modifying
	original_position = base_sprite.position

	# On ground, move position to origin so bottom-anchoring offset works correctly
	base_sprite.position = Vector2.ZERO

	# Set offset to anchor at bottom center
	# This makes scaling happen from the bottom instead of center
	var tex = base_sprite.texture
	if tex:
		base_sprite.offset = Vector2(0, -tex.get_height() / 2.0)


func _start_idle_animation() -> void:
	"""Start idle animation if turret type supports it."""
	if not visual_node or is_being_carried:
		return

	# Currently only fire turret has idle animation
	if turret_type != "fire":
		return

	_start_idle_bounce()


func _start_idle_bounce() -> void:
	"""Start a subtle idle bounce animation using algorithmic tweening (vertical only, bottom anchored)."""
	if not visual_node or is_being_carried:
		return

	# Clean up any existing tween
	if idle_tween and idle_tween.is_valid():
		idle_tween.kill()

	# Create new tween with random phase offset
	idle_tween = turret.create_tween()
	idle_tween.set_loops()
	idle_tween.set_ease(Tween.EASE_IN_OUT)
	idle_tween.set_trans(Tween.TRANS_SINE)

	# Random starting phase to prevent synchronized bouncing
	var random_phase = randf() * 0.6

	# Subtle bounce: only scale Y axis between 95% and 105% of base scale
	var scale_x = original_scale.x  # Keep horizontal scale constant
	var scale_y_base = original_scale.y
	var scale_y_down = scale_y_base * 0.95
	var scale_y_up = scale_y_base * 1.05

	# The sprite offset is set to anchor at bottom, so scaling Y will naturally
	# grow upward from the bottom without position adjustments
	# Duration is 0.6 seconds per half-cycle for a gentle, slow bounce
	if random_phase > 0.3:
		idle_tween.tween_property(visual_node, "scale", Vector2(scale_x, scale_y_down), 0.6)
		idle_tween.tween_property(visual_node, "scale", Vector2(scale_x, scale_y_up), 0.6)
	else:
		idle_tween.tween_property(visual_node, "scale", Vector2(scale_x, scale_y_up), 0.6)
		idle_tween.tween_property(visual_node, "scale", Vector2(scale_x, scale_y_down), 0.6)
