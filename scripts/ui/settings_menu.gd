class_name SettingsMenuUI
extends ScalableUIPanel

## Handles settings menu display and interactions

var show_damage_check: CheckButton
var physics_hitboxes_check: CheckButton
var player_hurtbox_check: CheckButton
var enemy_hurtbox_check: CheckButton
var player_attack_check: CheckButton
var isometric_debug_check: CheckButton
var add_item_dropdown: OptionButton
var add_item_button: Button
var back_button: Button

# Base values at 1080p
const BASE_PANEL_WIDTH: float = 400.0
const BASE_PANEL_HEIGHT: float = 350.0 # Increased height for new option
const BASE_BUTTON_HEIGHT: float = 40.0


func setup(nodes: Dictionary, owner: Node) -> void:
	print("DEBUG: SettingsMenuUI setup called. Nodes: ", nodes.keys())
	show_damage_check = nodes.get("show_damage_check")
	physics_hitboxes_check = nodes.get("physics_hitboxes_check")
	player_hurtbox_check = nodes.get("player_hurtbox_check")
	enemy_hurtbox_check = nodes.get("enemy_hurtbox_check")
	player_attack_check = nodes.get("player_attack_check")
	isometric_debug_check = nodes.get("isometric_debug_check")
	back_button = nodes.get("back_button")
	add_item_dropdown = nodes.get("add_item_dropdown")
	add_item_button = nodes.get("add_item_button")
	
	back_button = nodes.get("back_button")
	
	if container:
		container.process_mode = Node.PROCESS_MODE_ALWAYS # Ensure settings menu works when paused

	# Set base size
	base_panel_size = Vector2(BASE_PANEL_WIDTH, BASE_PANEL_HEIGHT)

	# Call parent setup
	super.setup(nodes, owner)

	# Initialize checkbox states
	if show_damage_check:
		show_damage_check.button_pressed = Globals.show_damage_numbers
		
	if isometric_debug_check:
		print("DEBUG: Connecting isometric_debug_check")
		isometric_debug_check.button_pressed = Globals.isometric_debug_enabled
		if not isometric_debug_check.toggled.is_connected(on_isometric_debug_toggled):
			isometric_debug_check.toggled.connect(on_isometric_debug_toggled)
	else:
		print("ERROR: isometric_debug_check node NOT FOUND in SettingsMenuUI")

	if physics_hitboxes_check:
		physics_hitboxes_check.button_pressed = Globals.debug_hitbox_flags[GameEnums.HitboxType.PHYSICS]

	if player_hurtbox_check:
		player_hurtbox_check.button_pressed = Globals.debug_hitbox_flags[GameEnums.HitboxType.PLAYER_HURTBOX]

	if enemy_hurtbox_check:
		enemy_hurtbox_check.button_pressed = Globals.debug_hitbox_flags[GameEnums.HitboxType.ENEMY_HURTBOX]

	if player_attack_check:
		player_attack_check.button_pressed = Globals.debug_hitbox_flags[GameEnums.HitboxType.PLAYER_ATTACK]

	# Setup debug item dropdown
	if add_item_dropdown and add_item_button:
		_populate_item_dropdown()
		if not add_item_button.pressed.is_connected(_on_add_item_pressed):
			add_item_button.pressed.connect(_on_add_item_pressed)


func _scale_fonts(scale: float) -> void:
	# Scale button
	if back_button:
		back_button.custom_minimum_size.y = UIScaler.scale(BASE_BUTTON_HEIGHT)


func show() -> void:
	print("DEBUG: SettingsMenuUI show() called")
	if container:
		container.modulate.a = 0.0
		container.visible = true
		var tween = _owner.create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(container, "modulate:a", 1.0, 0.15)
		if show_damage_check:
			show_damage_check.grab_focus()


func hide() -> void:
	if container:
		container.visible = false


func on_show_damage_toggled(toggled_on: bool) -> void:
	Globals.show_damage_numbers = toggled_on


func on_isometric_debug_toggled(toggled_on: bool) -> void:
	print("DEBUG: on_isometric_debug_toggled triggered. Value: ", toggled_on)
	Globals.isometric_debug_enabled = toggled_on
	Events.isometric_debug_toggled.emit(toggled_on)


func on_hitbox_type_toggled(type: int, toggled_on: bool) -> void:
	Globals.debug_hitbox_flags[type] = toggled_on
	Events.hitbox_debug_toggled.emit(type, toggled_on)


# Legacy function kept for transition if needed, but not used by new UI
func on_show_hitboxes_toggled(toggled_on: bool) -> void:
	# Toggle all for convenience if this is called
	for type in GameEnums.HitboxType.values():
		on_hitbox_type_toggled(type, toggled_on)


# =============================================================================
# DEBUG ITEM DROPDOWN
# =============================================================================
func _populate_item_dropdown() -> void:
	"""Populate the dropdown with all available items, grouped by rarity."""
	add_item_dropdown.clear()
	var all_items = ItemRegistry.get_all_item_ids()
	
	# Group by rarity for easier navigation (COMMON to LEGENDARY = 0 to 4)
	for rarity in range(5):
		for item_id in all_items:
			if ItemRegistry.get_rarity(item_id) == rarity:
				var item = ItemRegistry.get_item(item_id)
				var item_name = item.name if item else item_id
				var rarity_name = ItemRegistry.RARITY_NAMES[rarity]
				add_item_dropdown.add_item("[%s] %s" % [rarity_name, item_name])
				add_item_dropdown.set_item_metadata(add_item_dropdown.item_count - 1, item_id)


func _on_add_item_pressed() -> void:
	"""Add the selected item to the player (free, for debugging)."""
	var idx = add_item_dropdown.selected
	if idx < 0:
		return
	
	var item_id = add_item_dropdown.get_item_metadata(idx)
	if item_id == null or item_id.is_empty():
		return
	
	# Use shop_manager to apply item (reuses all existing item application logic)
	var shop_manager = Globals.shop_manager
	if shop_manager and shop_manager.has_method("apply_item"):
		shop_manager.apply_item(item_id)
		print("DEBUG: Added item for free: ", item_id)
	else:
		push_error("Could not find shop_manager to apply item")
