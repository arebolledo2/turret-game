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

	# Listen for range toggle event
	Events.turret_range_toggled.connect(_on_range_toggled)

	# Apply current range visibility state
	if Globals.show_turret_ranges:
		show_range()

	# Spawn animation
	play_spawn_animation()

func setup_visuals() -> void:
	"""Setup turret visuals based on type."""
	var turret_config = TurretRegistry.get_type(turret_type)
	var icon = turret_config.get("icon", "🗼")

	# Plasma turret specialized visuals
	if turret_type == "plasma" and animated_sprite:
		_setup_plasma_visuals()
		return

	# Normal turret specialized visuals
	if turret_type == "normal" and animated_sprite:
		_setup_normal_visuals()
		return

	# Fire turret specialized visuals
	if turret_type == "fire":
		_setup_fire_visuals()
		return


	# Set base visuals
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
		# Compensate for node scale since range indicator is a child
		# but gameplay distance checks use global coordinates
		var visual_radius = current_range
		if turret.scale.x != 0:
			visual_radius = current_range / turret.scale.x
		range_indicator.set_radius(visual_radius)

func _update_status_indicators() -> void:
	"""Update visual status indicators showing active buffs/debuffs."""
	if not status_indicators:
		return

	# Clear existing indicators
	for child in status_indicators.get_children():
		child.queue_free()

	var turret_manager = Globals.turret_manager
	if not turret_manager:
		return

	var active_effects: Array[Dictionary] = []

	# Signal Amplifier
	if ItemRegistry.has_special_effect("signal_amplifier") and Globals.item_counts.get("signal_amplifier", 0) > 0:
		var nearby = turret_manager.get_turrets_within_radius(turret.global_position, 200.0)
		var is_buff = nearby.size() > 0
		active_effects.append({
			"icon": "📡",
			"is_buff": is_buff
		})

	# Isolation Protocol
	if ItemRegistry.has_special_effect("isolation_protocol") and Globals.item_counts.get("isolation_protocol", 0) > 0:
		var nearby = turret_manager.get_turrets_within_radius(turret.global_position, 250.0)
		var is_buff = nearby.size() == 0
		active_effects.append({
			"icon": "🛡️",
			"is_buff": is_buff
		})

	# Feedback Loop
	if ItemRegistry.has_special_effect("feedback_loop") and Globals.item_counts.get("feedback_loop", 0) > 0:
		var nearby = turret_manager.get_turrets_within_radius(turret.global_position, 180.0)
		var count = nearby.size()
		active_effects.append({
			"icon": "🔄",
			"is_buff": count > 0,
			"count": count if count > 0 else null
		})

	# Personal Space (always active as a buff)
	if ItemRegistry.has_special_effect("personal_space") and Globals.item_counts.get("personal_space", 0) > 0:
		active_effects.append({
			"icon": "⭕",
			"is_buff": true
		})

	# Chain Reaction (show if buffed)
	if ItemRegistry.has_special_effect("chain_reaction") and Globals.item_counts.get("chain_reaction", 0) > 0:
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
	var sprite_node: CanvasItem = animated_sprite if animated_sprite else base_sprite
	if sprite_node:
		var original_color = sprite_node.modulate
		sprite_node.modulate = Color.WHITE
		var tween = turret.create_tween()
		tween.tween_property(sprite_node, "modulate", original_color, 0.1)

func play_spawn_animation() -> void:
	"""Animate turret spawning in."""
	turret.scale = Vector2.ZERO
	var tween = turret.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(turret, "scale", Vector2(1.5, 1.5), 0.3)

	# Update range visual as scale changes to keep it accurate
	tween.parallel().tween_method(func(_v): _update_range_visual(), 0.0, 1.0, 0.3)

func show_pickup_indicator() -> void:
	"""Show visual indicator that turret is in pickup range."""
	is_in_pickup_range = true
	# Brighten the turret sprites to indicate it's in pickup range
	var sprite_node: CanvasItem = base_sprite if base_sprite else animated_sprite
	if sprite_node:
		sprite_node.modulate = Color.WHITE.lightened(0.4)
	if weapon_sprite:
		weapon_sprite.modulate = Color.WHITE.lightened(0.4)

func hide_pickup_indicator() -> void:
	"""Hide visual indicator that turret is in pickup range."""
	is_in_pickup_range = false
	# Reset sprites to normal brightness
	var sprite_node: CanvasItem = base_sprite if base_sprite else animated_sprite
	if sprite_node:
		sprite_node.modulate = Color.WHITE
	if weapon_sprite:
		weapon_sprite.modulate = Color.WHITE

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
