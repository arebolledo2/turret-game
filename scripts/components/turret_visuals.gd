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
var asset_config: EntityAssetConfig = null
var visual_config: AssetVisualConfig = null
var base_visual_modulate: Color = Color.WHITE

# Sprite nodes
var base_sprite: Sprite2D = null
var glow_sprite: Sprite2D = null
var animated_sprite: AnimatedSprite2D = null
var weapon_sprite: Sprite2D = null
var icon_label: Label = null
var range_indicator: Node2D = null
var status_indicators: HBoxContainer = null

# State
var is_in_pickup_range: bool = false
var is_being_carried: bool = false

# Universal visual state (applies to all turrets)
var visual_node: CanvasItem = null # The node we animate (sprite or animated_sprite)
var original_scale: Vector2 = Vector2.ONE
var original_offset: Vector2 = Vector2.ZERO
var original_position: Vector2 = Vector2.ZERO

# Animation tweens
var spawn_tween: Tween = null
var idle_tween: Tween = null
var effect_tween: Tween = null
var muzzle_tween: Tween = null
var recoil_tween: Tween = null

func initialize(p_turret: Node2D, p_turret_type: String, p_stats: Dictionary) -> void:
	"""Initialize component with required references."""
	turret = p_turret
	turret_type = p_turret_type
	stats = p_stats
	assert(turret != null, "TurretVisuals: turret reference required")

	# Get sprite node references
	base_sprite = turret.get_node_or_null("BaseSprite")
	glow_sprite = turret.get_node_or_null("Glow")
	animated_sprite = turret.get_node_or_null("AnimatedSprite")
	weapon_sprite = turret.get_node_or_null("WeaponSprite")
	icon_label = turret.get_node_or_null("IconLabel")
	range_indicator = turret.get_node_or_null("RangeIndicator")
	status_indicators = turret.get_node_or_null("StatusIndicators")

	# Resolve initial config
	apply_asset_config(AssetConfigService.get_turret_config(turret_type))

	# Setup visuals based on turret type
	setup_visuals()

	# Setup range indicator
	if range_indicator:
		var color = _get_visual_color()
		_update_range_visual()
		range_indicator.modulate = color
		range_indicator.modulate.a = 0.0 # Hidden by default

	# Listen for carry events
	Events.turret_picked_up.connect(_on_turret_picked_up)
	Events.turret_placed.connect(_on_turret_placed)
	Events.turret_dropped.connect(_on_turret_placed) # Same cleanup as placed

	# Listen for range toggle event
	Events.turret_range_toggled.connect(_on_range_toggled)
	Events.asset_preset_changed.connect(_on_asset_preset_changed)
	Events.asset_config_changed.connect(_on_asset_config_changed)

	# Apply current range visibility state
	if SettingsService.show_turret_ranges:
		show_range()

	# Spawn animation
	play_spawn_animation()

func setup_visuals() -> void:
	"""Setup turret visuals based on type."""
	if visual_config != null:
		_setup_from_visual_config()
		_store_visual_state()
		_update_glow_color()
		return

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
		"melee":
			_setup_melee_visuals()
		"mine":
			_setup_mine_visuals()
		_:
			_setup_icon_fallback()

	# Store visual state after type-specific setup
	_store_visual_state()
	_update_glow_color()


func _update_glow_color() -> void:
	"""Keep the local light accent aligned with the turret's identity color."""
	if not glow_sprite:
		return

	var glow_color := TurretRegistry.get_color(turret_type)
	if visual_config and visual_config.modulate != Color.WHITE:
		glow_color = visual_config.modulate
	glow_color.a = 0.16
	glow_sprite.modulate = glow_color


func apply_asset_config(new_config: EntityAssetConfig) -> void:
	asset_config = new_config
	if asset_config and asset_config.visual:
		visual_config = asset_config.visual
	else:
		visual_config = null


func _setup_from_visual_config() -> void:
	var fallback_path := "res://assets/sprites/turrets/turret_basic.png"
	match turret_type:
		"sniper":
			fallback_path = "res://assets/sprites/turrets/turret_sniper.png"
		"fire":
			fallback_path = "res://assets/sprites/turrets/turret_fire.png"
		"plasma":
			fallback_path = "res://assets/sprites/turrets/turret_plasma_static.png"
		"shock":
			fallback_path = "res://assets/sprites/turrets/turret_shock.png"
		"tesla":
			fallback_path = "res://assets/sprites/turrets/turret_tesla.png"
		"normal", "mine", "melee":
			fallback_path = "res://assets/sprites/turrets/turret_basic.png"

	var wants_animation := visual_config.sprite_kind == AssetVisualConfig.SpriteKind.ANIMATED \
		or visual_config.orientation_mode == AssetVisualConfig.OrientationMode.ANIMATED_LEFT_RIGHT
	if wants_animation and not _setup_animated_visual():
		_setup_static_visual(_resolve_primary_texture_path(fallback_path))
	elif not wants_animation:
		_setup_static_visual(_resolve_primary_texture_path(fallback_path))

	if turret_type == "melee":
		_setup_melee_weapon()


func _resolve_primary_texture_path(fallback_path: String) -> String:
	if visual_config == null:
		return fallback_path
	if visual_config.texture_paths.has("default"):
		var path := str(visual_config.texture_paths.get("default", ""))
		if ResourceLoader.exists(path):
			return path
	if visual_config.texture_paths.has("right"):
		var right_path := str(visual_config.texture_paths.get("right", ""))
		if ResourceLoader.exists(right_path):
			return right_path
	return fallback_path


func _setup_static_visual(texture_path: String) -> void:
	if not base_sprite:
		return

	_clear_dynamic_weapon()

	if animated_sprite:
		animated_sprite.visible = false
	if icon_label:
		icon_label.visible = false

	base_sprite.visible = true
	base_sprite.texture = load(texture_path)

	var scale := Vector2(0.125, 0.125)
	var modulate := Color.WHITE
	var position_offset := Vector2.ZERO
	var anchor_bottom := true
	if visual_config:
		scale = visual_config.scale
		modulate = visual_config.modulate
		position_offset = visual_config.position_offset
		anchor_bottom = visual_config.anchor_bottom

	base_sprite.scale = scale
	base_sprite.modulate = modulate
	base_visual_modulate = modulate

	original_position = base_sprite.position
	base_sprite.position = position_offset

	if anchor_bottom and base_sprite.texture:
		base_sprite.offset = Vector2(0, -base_sprite.texture.get_height() / 2.0)
	else:
		base_sprite.offset = Vector2.ZERO


func _setup_animated_visual() -> bool:
	"""Configure the scene's AnimatedSprite2D when the asset requests it."""
	if not animated_sprite:
		return false

	var frames := animated_sprite.sprite_frames
	if visual_config and not visual_config.sprite_frames_path.is_empty() and ResourceLoader.exists(visual_config.sprite_frames_path):
		var candidate = load(visual_config.sprite_frames_path)
		if candidate is SpriteFrames:
			frames = candidate
			animated_sprite.sprite_frames = frames

	if frames == null or frames.get_animation_names().is_empty():
		return false

	_clear_dynamic_weapon()
	if base_sprite:
		base_sprite.visible = false
	animated_sprite.visible = true
	if icon_label:
		icon_label.visible = false

	var scale := Vector2(0.125, 0.125)
	var modulate := Color.WHITE
	var position_offset := Vector2.ZERO
	if visual_config:
		scale = visual_config.scale
		modulate = visual_config.modulate
		position_offset = visual_config.position_offset

	animated_sprite.scale = scale
	animated_sprite.modulate = modulate
	animated_sprite.position = position_offset
	base_visual_modulate = modulate
	original_position = animated_sprite.position
	if visual_config.animation_speed_fps > 0.0:
		animated_sprite.speed_scale = visual_config.animation_speed_fps / 12.0

	var animation_name := str(visual_config.animation_map.get("default", ""))
	if visual_config.orientation_mode == AssetVisualConfig.OrientationMode.ANIMATED_LEFT_RIGHT:
		animation_name = str(visual_config.animation_map.get("right", animation_name))
	if animation_name.is_empty() or not frames.has_animation(animation_name):
		animation_name = frames.get_animation_names()[0]
	animated_sprite.play(animation_name)
	return true


func _clear_dynamic_weapon() -> void:
	if weapon_sprite and is_instance_valid(weapon_sprite):
		weapon_sprite.queue_free()
	weapon_sprite = null


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
		icon_label.add_theme_font_size_override("font_size", FontSizes.get_scaled(FontSizes.ICON_MEDIUM))
	base_visual_modulate = Color.WHITE


func _setup_shock_visuals() -> void:
	"""Setup shock turret visuals with custom sprite."""
	_setup_static_visual(_resolve_primary_texture_path("res://assets/sprites/turrets/turret_shock.png"))


func _setup_sniper_visuals() -> void:
	"""Setup sniper turret visuals with custom sprite."""
	_setup_static_visual(_resolve_primary_texture_path("res://assets/sprites/turrets/turret_sniper.png"))


func _setup_tesla_visuals() -> void:
	"""Setup tesla turret visuals with custom sprite."""
	_setup_static_visual(_resolve_primary_texture_path("res://assets/sprites/turrets/turret_tesla.png"))

func _setup_plasma_visuals() -> void:
	"""Setup plasma turret visuals with custom sprite."""
	_setup_static_visual(_resolve_primary_texture_path("res://assets/sprites/turrets/turret_plasma_static.png"))

func _setup_normal_visuals() -> void:
	"""Setup normal/basic turret visuals with custom sprite."""
	_setup_static_visual(_resolve_primary_texture_path("res://assets/sprites/turrets/turret_basic.png"))

func _setup_fire_visuals() -> void:
	"""Setup fire turret visuals with custom sprite."""
	_setup_static_visual(_resolve_primary_texture_path("res://assets/sprites/turrets/turret_fire.png"))

func update_stats(new_stats: Dictionary) -> void:
	"""Update stats cache and refresh visuals."""
	stats = new_stats
	if range_indicator:
		_update_range_visual()
		range_indicator.modulate = _get_visual_color()
		range_indicator.modulate.a = 0.0 if not SettingsService.show_turret_ranges else 0.3
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
		label.add_theme_font_size_override("font_size", FontSizes.get_scaled(FontSizes.BODY_SMALL))
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
	"""Flash and lightly recoil the turret when firing."""
	var sprite_node: CanvasItem = null
	if animated_sprite:
		sprite_node = animated_sprite
	else:
		sprite_node = base_sprite
	if sprite_node:
		if muzzle_tween and muzzle_tween.is_valid():
			muzzle_tween.kill()

		var resting_color := base_visual_modulate
		if is_in_pickup_range:
			resting_color = resting_color.lightened(0.4)

		sprite_node.modulate = Color.WHITE
		muzzle_tween = turret.create_tween()
		muzzle_tween.tween_property(sprite_node, "modulate", resting_color, 0.08)

	# The static turret art is bottom-anchored, so a short downward kick reads as
	# recoil without fighting the idle bounce's scale animation.
	if visual_node is Node2D:
		if recoil_tween and recoil_tween.is_valid():
			recoil_tween.kill()

		var node_2d := visual_node as Node2D
		node_2d.position = original_position + Vector2(0.0, 2.0)
		recoil_tween = turret.create_tween()
		recoil_tween.set_ease(Tween.EASE_OUT)
		recoil_tween.set_trans(Tween.TRANS_QUAD)
		recoil_tween.tween_property(node_2d, "position", original_position, 0.08)

func play_spawn_animation() -> void:
	"""Animate turret spawning in."""
	if not visual_node:
		return
	if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION):
		visual_node.scale = original_scale
		_start_idle_animation()
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
	if not visual_node or FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION):
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
		sprite_node.modulate = base_visual_modulate.lightened(0.4)
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
		sprite_node.modulate = base_visual_modulate
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
			visual_node.offset = Vector2.ZERO # Neutral offset while carrying

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


func _get_visual_color() -> Color:
	if visual_config:
		return visual_config.modulate
	return TurretRegistry.get_color(turret_type)


func _on_asset_preset_changed(_preset_name: String) -> void:
	apply_asset_config(AssetConfigService.get_turret_config(turret_type))
	setup_visuals()
	if range_indicator:
		range_indicator.modulate = _get_visual_color()
		range_indicator.modulate.a = 0.0 if not SettingsService.show_turret_ranges else 0.3


func _on_asset_config_changed(entity_kind: int, asset_id: String) -> void:
	if entity_kind == EntityAssetConfig.EntityKind.TURRET and asset_id == turret_type:
		_on_asset_preset_changed(AssetConfigService.get_active_preset())


func _stop_idle_animation() -> void:
	if idle_tween and idle_tween.is_valid():
		idle_tween.kill()
	idle_tween = null
	if visual_node:
		visual_node.scale = original_scale


func _start_idle_animation() -> void:
	"""Start idle animation if turret type supports it."""
	if not visual_node or is_being_carried or FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION):
		_stop_idle_animation()
		return

	if visual_config and visual_config.idle_bounce_enabled:
		_start_idle_bounce()
		return

	# Config is authoritative. Legacy fallback previously re-enabled this
	# animation after an explicit false value, making the flag impossible to
	# turn off reliably.
	_stop_idle_animation()


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

	var min_scale := 0.95
	var cycle := 0.6
	if visual_config:
		min_scale = clampf(visual_config.idle_bounce_min_y_scale, 0.1, 1.0)
		cycle = maxf(0.05, visual_config.idle_bounce_cycle_seconds)

	# Subtle bounce: only scale Y axis between configured min and base scale
	var scale_x = original_scale.x # Keep horizontal scale constant
	var scale_y_base = original_scale.y
	var scale_y_down = scale_y_base * min_scale
	var scale_y_up = scale_y_base * 1.0

	# The sprite offset is set to anchor at bottom, so scaling Y will naturally
	# grow upward from the bottom without position adjustments
	# Duration is configurable per half-cycle
	if random_phase > 0.3:
		idle_tween.tween_property(visual_node, "scale", Vector2(scale_x, scale_y_down), cycle)
		idle_tween.tween_property(visual_node, "scale", Vector2(scale_x, scale_y_up), cycle)
	else:
		idle_tween.tween_property(visual_node, "scale", Vector2(scale_x, scale_y_up), cycle)
		idle_tween.tween_property(visual_node, "scale", Vector2(scale_x, scale_y_down), cycle)


func _setup_melee_visuals() -> void:
	"""Setup melee turret visuals with static base and spinning bat."""
	# Setup base sprite (static turret)
	_setup_normal_visuals()

	_setup_melee_weapon()


func _setup_melee_weapon() -> void:
	"""Attach melee weapon sprite from config (fallback to legacy path)."""
	_clear_dynamic_weapon()

	# Create spinning bat weapon sprite on top
	if turret:
		weapon_sprite = Sprite2D.new()
		weapon_sprite.name = "MeleeBat"
		var weapon_path := "res://assets/sprites/melee_bat.png"
		if visual_config and visual_config.texture_paths.has("weapon"):
			var candidate := str(visual_config.texture_paths.get("weapon", ""))
			if ResourceLoader.exists(candidate):
				weapon_path = candidate
		var bat_texture = load(weapon_path)
		weapon_sprite.texture = bat_texture
		weapon_sprite.scale = Vector2(0.1, 0.1) # Scale down the bat
		weapon_sprite.z_index = 1 # Draw above base sprite

		# The sprite is vertical (pointing up) in the asset
		# Use offset to position the pivot at the handle (bottom of the bat)
		# Then rotation will swing it from the handle
		if bat_texture:
			var texture_height = bat_texture.get_height()
			var scaled_length = texture_height * 0.1
			# Offset upward so the handle stays at turret center
			# and the blade extends up (and will rotate around the handle)
			weapon_sprite.offset.y = -scaled_length / 2.0

		turret.add_child(weapon_sprite)


func _setup_mine_visuals() -> void:
	"""Setup mine turret visuals using basic turret sprite."""
	_setup_normal_visuals()
