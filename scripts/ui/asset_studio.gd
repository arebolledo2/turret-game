class_name AssetStudioUI
extends ScalableUIPanel

const BASE_PANEL_WIDTH: float = 1400.0
const BASE_PANEL_HEIGHT: float = 820.0
const DEBOUNCE_SECONDS: float = 0.12

var n: Dictionary = {}
var _selected_kind: int = EntityAssetConfig.EntityKind.ENEMY
var _selected_asset_id: String = ""
var _current_config: EntityAssetConfig = null
var _base_config: EntityAssetConfig = null
var _base_profile: CollisionProfile = null
var _texture_inputs: Dictionary = {}
var _suppress: bool = false
var _editing_enabled: bool = false
var _last_field: String = ""
var _visual_version: int = 0
var _collision_version: int = 0


func setup(nodes: Dictionary, owner: Node) -> void:
	base_panel_size = Vector2(BASE_PANEL_WIDTH, BASE_PANEL_HEIGHT)
	super.setup(nodes, owner)
	n = nodes
	if container:
		container.process_mode = Node.PROCESS_MODE_ALWAYS

	_setup_dropdowns()
	_connect_signals()
	_refresh_presets()
	_refresh_assets(true)


func _scale_fonts(_scale: float) -> void:
	pass


func show() -> void:
	if container == null:
		return
	_refresh_presets()
	_refresh_assets(true)
	container.modulate.a = 0.0
	container.visible = true
	var tween := _owner.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(container, "modulate:a", 1.0, 0.12)


func hide() -> void:
	if container:
		container.visible = false


func _setup_dropdowns() -> void:
	var kind_dd: OptionButton = n.get("entity_kind_dropdown")
	if kind_dd:
		kind_dd.clear()
		kind_dd.add_item("Enemies", EntityAssetConfig.EntityKind.ENEMY)
		kind_dd.add_item("Turrets", EntityAssetConfig.EntityKind.TURRET)
		kind_dd.add_item("Player", EntityAssetConfig.EntityKind.PLAYER)

	var sprite_dd: OptionButton = n.get("sprite_kind_dropdown")
	if sprite_dd:
		sprite_dd.clear()
		sprite_dd.add_item("Static", AssetVisualConfig.SpriteKind.STATIC)
		sprite_dd.add_item("Directional Textures", AssetVisualConfig.SpriteKind.DIRECTIONAL_TEXTURES)
		sprite_dd.add_item("Animated", AssetVisualConfig.SpriteKind.ANIMATED)

	var orient_dd: OptionButton = n.get("orientation_mode_dropdown")
	if orient_dd:
		orient_dd.clear()
		orient_dd.add_item("Fixed", AssetVisualConfig.OrientationMode.FIXED)
		orient_dd.add_item("Flip X by Velocity", AssetVisualConfig.OrientationMode.FLIP_X_BY_VELOCITY)
		orient_dd.add_item("Texture Left/Right", AssetVisualConfig.OrientationMode.TEXTURE_LEFT_RIGHT)
		orient_dd.add_item("Texture 8-Direction", AssetVisualConfig.OrientationMode.TEXTURE_8_DIR)
		orient_dd.add_item("Animated Left/Right", AssetVisualConfig.OrientationMode.ANIMATED_LEFT_RIGHT)

	var physics_dd: OptionButton = n.get("physics_shape_dropdown")
	if physics_dd:
		physics_dd.clear()
		physics_dd.add_item("Circle", CollisionProfile.ShapeType.CIRCLE)
		physics_dd.add_item("Rectangle", CollisionProfile.ShapeType.RECTANGLE)
		physics_dd.add_item("Capsule", CollisionProfile.ShapeType.CAPSULE)

	var hurt_dd: OptionButton = n.get("hurtbox_shape_dropdown")
	if hurt_dd:
		hurt_dd.clear()
		hurt_dd.add_item("Circle", CollisionProfile.ShapeType.CIRCLE)
		hurt_dd.add_item("Rectangle", CollisionProfile.ShapeType.RECTANGLE)
		hurt_dd.add_item("Capsule", CollisionProfile.ShapeType.CAPSULE)


func _connect_signals() -> void:
	var back_btn: Button = n.get("back_button")
	if back_btn and _owner and _owner.has_method("_on_asset_studio_back_pressed"):
		back_btn.pressed.connect(_owner._on_asset_studio_back_pressed)

	(n.get("presets_dropdown") as OptionButton).item_selected.connect(_on_preset_selected)
	(n.get("new_preset_button") as Button).pressed.connect(_on_new_preset)
	(n.get("clone_preset_button") as Button).pressed.connect(_on_clone_preset)
	(n.get("delete_preset_button") as Button).pressed.connect(_on_delete_preset)
	(n.get("clone_cta_button") as Button).pressed.connect(_on_clone_preset)

	(n.get("entity_kind_dropdown") as OptionButton).item_selected.connect(_on_kind_selected)
	(n.get("asset_list") as ItemList).item_selected.connect(_on_asset_selected)

	(n.get("sprite_kind_dropdown") as OptionButton).item_selected.connect(_on_visual_changed)
	(n.get("orientation_mode_dropdown") as OptionButton).item_selected.connect(_on_orientation_changed)
	(n.get("sprite_frames_input") as LineEdit).text_changed.connect(_on_visual_changed)
	(n.get("animation_speed_spin") as SpinBox).value_changed.connect(_on_visual_changed)
	(n.get("scale_x_spin") as SpinBox).value_changed.connect(_on_visual_changed)
	(n.get("scale_y_spin") as SpinBox).value_changed.connect(_on_visual_changed)
	(n.get("offset_x_spin") as SpinBox).value_changed.connect(_on_visual_changed)
	(n.get("offset_y_spin") as SpinBox).value_changed.connect(_on_visual_changed)
	(n.get("modulate_picker") as ColorPickerButton).color_changed.connect(_on_visual_changed)
	(n.get("anchor_bottom_check") as CheckButton).toggled.connect(_on_visual_changed)
	(n.get("idle_bounce_enabled_check") as CheckButton).toggled.connect(_on_visual_changed)
	(n.get("idle_bounce_min_y_spin") as SpinBox).value_changed.connect(_on_visual_changed)
	(n.get("idle_bounce_cycle_spin") as SpinBox).value_changed.connect(_on_visual_changed)
	(n.get("animation_map_left_input") as LineEdit).text_changed.connect(_on_visual_changed)
	(n.get("animation_map_right_input") as LineEdit).text_changed.connect(_on_visual_changed)
	(n.get("sprite_kind_dropdown") as OptionButton).focus_entered.connect(_set_last_field.bind("visual.sprite_kind"))
	(n.get("orientation_mode_dropdown") as OptionButton).focus_entered.connect(_set_last_field.bind("visual.orientation_mode"))
	(n.get("sprite_frames_input") as LineEdit).focus_entered.connect(_set_last_field.bind("visual.sprite_frames_path"))
	(n.get("animation_speed_spin") as SpinBox).focus_entered.connect(_set_last_field.bind("visual.animation_speed_fps"))
	(n.get("scale_x_spin") as SpinBox).focus_entered.connect(_set_last_field.bind("visual.scale"))
	(n.get("scale_y_spin") as SpinBox).focus_entered.connect(_set_last_field.bind("visual.scale"))
	(n.get("offset_x_spin") as SpinBox).focus_entered.connect(_set_last_field.bind("visual.position_offset"))
	(n.get("offset_y_spin") as SpinBox).focus_entered.connect(_set_last_field.bind("visual.position_offset"))
	(n.get("modulate_picker") as ColorPickerButton).focus_entered.connect(_set_last_field.bind("visual.modulate"))
	(n.get("anchor_bottom_check") as CheckButton).focus_entered.connect(_set_last_field.bind("visual.anchor_bottom"))
	(n.get("idle_bounce_enabled_check") as CheckButton).focus_entered.connect(_set_last_field.bind("visual.idle_bounce_enabled"))
	(n.get("idle_bounce_min_y_spin") as SpinBox).focus_entered.connect(_set_last_field.bind("visual.idle_bounce_min_y_scale"))
	(n.get("idle_bounce_cycle_spin") as SpinBox).focus_entered.connect(_set_last_field.bind("visual.idle_bounce_cycle_seconds"))
	(n.get("animation_map_left_input") as LineEdit).focus_entered.connect(_set_last_field.bind("visual.animation_map.left"))
	(n.get("animation_map_right_input") as LineEdit).focus_entered.connect(_set_last_field.bind("visual.animation_map.right"))

	(n.get("collision_enabled_check") as CheckButton).toggled.connect(_on_collision_changed)
	(n.get("physics_shape_dropdown") as OptionButton).item_selected.connect(_on_collision_changed)
	(n.get("physics_size_x_spin") as SpinBox).value_changed.connect(_on_collision_changed)
	(n.get("physics_size_y_spin") as SpinBox).value_changed.connect(_on_collision_changed)
	(n.get("hurtbox_shape_dropdown") as OptionButton).item_selected.connect(_on_collision_changed)
	(n.get("hurtbox_size_x_spin") as SpinBox).value_changed.connect(_on_collision_changed)
	(n.get("hurtbox_size_y_spin") as SpinBox).value_changed.connect(_on_collision_changed)
	(n.get("deals_contact_damage_check") as CheckButton).toggled.connect(_on_collision_changed)
	(n.get("damage_cooldown_spin") as SpinBox).value_changed.connect(_on_collision_changed)
	(n.get("collision_enabled_check") as CheckButton).focus_entered.connect(_set_last_field.bind("collision.enabled"))
	(n.get("physics_shape_dropdown") as OptionButton).focus_entered.connect(_set_last_field.bind("collision_profile.physics_shape_type"))
	(n.get("physics_size_x_spin") as SpinBox).focus_entered.connect(_set_last_field.bind("collision_profile.physics_size"))
	(n.get("physics_size_y_spin") as SpinBox).focus_entered.connect(_set_last_field.bind("collision_profile.physics_size"))
	(n.get("hurtbox_shape_dropdown") as OptionButton).focus_entered.connect(_set_last_field.bind("collision_profile.hurtbox_shape_type"))
	(n.get("hurtbox_size_x_spin") as SpinBox).focus_entered.connect(_set_last_field.bind("collision_profile.hurtbox_size"))
	(n.get("hurtbox_size_y_spin") as SpinBox).focus_entered.connect(_set_last_field.bind("collision_profile.hurtbox_size"))
	(n.get("deals_contact_damage_check") as CheckButton).focus_entered.connect(_set_last_field.bind("collision_profile.deals_contact_damage"))
	(n.get("damage_cooldown_spin") as SpinBox).focus_entered.connect(_set_last_field.bind("collision_profile.damage_cooldown"))

	(n.get("reset_field_button") as Button).pressed.connect(_on_reset_field)
	(n.get("reset_asset_button") as Button).pressed.connect(_on_reset_asset)
	(n.get("revert_preset_button") as Button).pressed.connect(_on_revert_preset)

	(n.get("texture_picker") as AssetStudioTexturePicker).texture_selected.connect(_on_texture_selected)


func _refresh_presets() -> void:
	var dd: OptionButton = n.get("presets_dropdown")
	if dd == null:
		return
	_suppress = true
	dd.clear()
	for preset_name in AssetConfigService.list_presets():
		dd.add_item(preset_name)
	var active := AssetConfigService.get_active_preset()
	for i in range(dd.item_count):
		if dd.get_item_text(i) == active:
			dd.select(i)
			break
	_suppress = false
	_update_editability()


func _refresh_assets(select_first: bool) -> void:
	var kind_dd: OptionButton = n.get("entity_kind_dropdown")
	for i in range(kind_dd.item_count):
		if kind_dd.get_item_id(i) == _selected_kind:
			kind_dd.select(i)
			break

	var list: ItemList = n.get("asset_list")
	var old_id := _selected_asset_id
	list.clear()
	var ids := AssetConfigService.list_asset_ids(_selected_kind)
	var selected_index := -1
	for i in range(ids.size()):
		var asset_id := str(ids[i])
		var cfg := AssetConfigService.get_asset_config(_selected_kind, asset_id)
		var label := asset_id
		if cfg and not cfg.display_name.is_empty():
			label = "%s (%s)" % [cfg.display_name, asset_id]
		list.add_item(label)
		list.set_item_metadata(i, asset_id)
		if asset_id == old_id:
			selected_index = i

	if selected_index < 0 and select_first and list.item_count > 0:
		selected_index = 0

	if selected_index >= 0:
		list.select(selected_index)
		_selected_asset_id = str(list.get_item_metadata(selected_index))
	else:
		_selected_asset_id = ""

	_load_config()


func _load_config() -> void:
	if _selected_asset_id.is_empty():
		_current_config = null
		_base_config = null
		_base_profile = null
		_update_preview()
		return

	_current_config = AssetConfigService.get_asset_config(_selected_kind, _selected_asset_id)
	_base_config = _current_config.duplicate(true) if _current_config else null
	_base_profile = _load_profile(_current_config)
	if _current_config == null or _current_config.visual == null:
		return

	_suppress = true
	_select_option_id(n.get("sprite_kind_dropdown"), int(_current_config.visual.sprite_kind))
	_select_option_id(n.get("orientation_mode_dropdown"), int(_current_config.visual.orientation_mode))
	(n.get("sprite_frames_input") as LineEdit).text = _current_config.visual.sprite_frames_path
	(n.get("animation_speed_spin") as SpinBox).value = _current_config.visual.animation_speed_fps
	(n.get("scale_x_spin") as SpinBox).value = _current_config.visual.scale.x
	(n.get("scale_y_spin") as SpinBox).value = _current_config.visual.scale.y
	(n.get("offset_x_spin") as SpinBox).value = _current_config.visual.position_offset.x
	(n.get("offset_y_spin") as SpinBox).value = _current_config.visual.position_offset.y
	(n.get("modulate_picker") as ColorPickerButton).color = _current_config.visual.modulate
	(n.get("anchor_bottom_check") as CheckButton).button_pressed = _current_config.visual.anchor_bottom
	(n.get("idle_bounce_enabled_check") as CheckButton).button_pressed = _current_config.visual.idle_bounce_enabled
	(n.get("idle_bounce_min_y_spin") as SpinBox).value = _current_config.visual.idle_bounce_min_y_scale
	(n.get("idle_bounce_cycle_spin") as SpinBox).value = _current_config.visual.idle_bounce_cycle_seconds
	(n.get("animation_map_left_input") as LineEdit).text = str(_current_config.visual.animation_map.get("left", ""))
	(n.get("animation_map_right_input") as LineEdit).text = str(_current_config.visual.animation_map.get("right", ""))
	_rebuild_texture_slots(_current_config.visual.texture_paths)
	_sync_collision_controls(_current_config)
	_suppress = false
	_update_editability()
	_update_preview()


func _sync_collision_controls(cfg: EntityAssetConfig) -> void:
	var is_turret := _selected_kind == EntityAssetConfig.EntityKind.TURRET
	(n.get("turret_collision_deferred_label") as Label).visible = is_turret

	(n.get("collision_enabled_check") as CheckButton).button_pressed = cfg.collision.enabled if cfg and cfg.collision else false
	var profile := _load_profile(cfg)
	if profile == null:
		profile = CollisionProfile.new()
	_select_option_id(n.get("physics_shape_dropdown"), int(profile.physics_shape_type))
	(n.get("physics_size_x_spin") as SpinBox).value = profile.physics_size.x
	(n.get("physics_size_y_spin") as SpinBox).value = profile.physics_size.y
	_select_option_id(n.get("hurtbox_shape_dropdown"), int(profile.hurtbox_shape_type))
	(n.get("hurtbox_size_x_spin") as SpinBox).value = profile.hurtbox_size.x
	(n.get("hurtbox_size_y_spin") as SpinBox).value = profile.hurtbox_size.y
	(n.get("deals_contact_damage_check") as CheckButton).button_pressed = profile.deals_contact_damage
	(n.get("damage_cooldown_spin") as SpinBox).value = profile.damage_cooldown
	(n.get("collision_profile_path_label") as Label).text = "Profile: %s" % (cfg.collision.collision_profile_path if cfg and cfg.collision else "(none)")


func _rebuild_texture_slots(paths: Dictionary) -> void:
	var container_vb: VBoxContainer = n.get("texture_slots_container")
	for child in container_vb.get_children():
		container_vb.remove_child(child)
		child.queue_free()
	_texture_inputs.clear()

	var slots := _texture_slots_for_mode()
	for slot_key in slots:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = slot_key
		label.custom_minimum_size = Vector2(120.0, 0.0)
		var input := LineEdit.new()
		input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		input.text = str(paths.get(slot_key, ""))
		input.placeholder_text = "res://assets/..."
		input.text_changed.connect(_on_slot_text_changed.bind(slot_key))
		var browse := Button.new()
		browse.text = "Browse"
		browse.pressed.connect(_on_browse_slot.bind(slot_key))
		row.add_child(label)
		row.add_child(input)
		row.add_child(browse)
		container_vb.add_child(row)
		_texture_inputs[slot_key] = input


func _texture_slots_for_mode() -> Array[String]:
	var mode_id := _selected_option_id(n.get("orientation_mode_dropdown"), AssetVisualConfig.OrientationMode.FIXED)
	var slots: Array[String] = []
	match mode_id:
		AssetVisualConfig.OrientationMode.FIXED, AssetVisualConfig.OrientationMode.FLIP_X_BY_VELOCITY:
			slots = ["default"]
		AssetVisualConfig.OrientationMode.TEXTURE_LEFT_RIGHT, AssetVisualConfig.OrientationMode.ANIMATED_LEFT_RIGHT:
			slots = ["left", "right"]
		AssetVisualConfig.OrientationMode.TEXTURE_8_DIR:
			slots = ["north", "north_east", "east", "south_east", "south", "south_west", "west", "north_west"]
		_:
			slots = ["default"]
	if _selected_kind == EntityAssetConfig.EntityKind.TURRET and _selected_asset_id == "melee":
		slots.append("weapon")
	return slots


func _on_slot_text_changed(_text: String, slot_key: String) -> void:
	_last_field = "visual.texture_paths.%s" % slot_key
	_on_visual_changed()


func _on_browse_slot(slot_key: String) -> void:
	var picker: AssetStudioTexturePicker = n.get("texture_picker")
	var input := _texture_inputs.get(slot_key) as LineEdit
	picker.open_for_slot(slot_key, input.text if input else "")


func _on_texture_selected(slot_key: String, path: String) -> void:
	var input := _texture_inputs.get(slot_key) as LineEdit
	if input:
		input.text = path
		_last_field = "visual.texture_paths.%s" % slot_key
		_on_visual_changed()


func _on_preset_selected(index: int) -> void:
	if _suppress:
		return
	var dd: OptionButton = n.get("presets_dropdown")
	AssetConfigService.set_active_preset(dd.get_item_text(index))
	_refresh_presets()
	_refresh_assets(true)


func _on_new_preset() -> void:
	var input: LineEdit = n.get("preset_name_input")
	var name := input.text.strip_edges()
	if name.is_empty():
		name = "preset_%s" % Time.get_unix_time_from_system()
	AssetConfigService.create_user_preset(name, "default")
	AssetConfigService.set_active_preset(name)
	_refresh_presets()
	_refresh_assets(true)


func _on_clone_preset() -> void:
	var input: LineEdit = n.get("preset_name_input")
	var name := input.text.strip_edges()
	if name.is_empty():
		name = "%s_clone" % AssetConfigService.get_active_preset()
	AssetConfigService.create_user_preset(name, AssetConfigService.get_active_preset())
	AssetConfigService.set_active_preset(name)
	_refresh_presets()
	_refresh_assets(true)


func _on_delete_preset() -> void:
	var active := AssetConfigService.get_active_preset()
	if AssetConfigService.get_preset_origin(active) != "user":
		return
	AssetConfigService.delete_user_preset(active)
	_refresh_presets()
	_refresh_assets(true)


func _on_kind_selected(index: int) -> void:
	_selected_kind = (n.get("entity_kind_dropdown") as OptionButton).get_item_id(index)
	_selected_asset_id = ""
	_refresh_assets(true)


func _on_asset_selected(index: int) -> void:
	_selected_asset_id = str((n.get("asset_list") as ItemList).get_item_metadata(index))
	_load_config()


func _on_orientation_changed(_index: int) -> void:
	if _suppress:
		return
	_rebuild_texture_slots(_collect_texture_paths())
	_on_visual_changed()


func _on_visual_changed(_v: Variant = null) -> void:
	if _suppress or not _can_edit():
		return
	_visual_version += 1
	var version := _visual_version
	var timer := _owner.get_tree().create_timer(DEBOUNCE_SECONDS, true)
	timer.timeout.connect(func() -> void:
		if version != _visual_version:
			return
		_apply_visual_patch()
	)


func _on_collision_changed(_v: Variant = null) -> void:
	if _suppress or not _can_edit() or _selected_kind == EntityAssetConfig.EntityKind.TURRET:
		return
	_collision_version += 1
	var version := _collision_version
	var timer := _owner.get_tree().create_timer(DEBOUNCE_SECONDS, true)
	timer.timeout.connect(func() -> void:
		if version != _collision_version:
			return
		_apply_collision_patch()
	)


func _apply_visual_patch() -> void:
	var animation_map := {}
	var left := (n.get("animation_map_left_input") as LineEdit).text.strip_edges()
	var right := (n.get("animation_map_right_input") as LineEdit).text.strip_edges()
	if not left.is_empty():
		animation_map["left"] = left
	if not right.is_empty():
		animation_map["right"] = right

	AssetConfigService.upsert_override(_selected_kind, _selected_asset_id, {
		"visual.sprite_kind": _selected_option_id(n.get("sprite_kind_dropdown"), AssetVisualConfig.SpriteKind.STATIC),
		"visual.orientation_mode": _selected_option_id(n.get("orientation_mode_dropdown"), AssetVisualConfig.OrientationMode.FIXED),
		"visual.texture_paths": _collect_texture_paths(),
		"visual.sprite_frames_path": (n.get("sprite_frames_input") as LineEdit).text.strip_edges(),
		"visual.animation_map": animation_map,
		"visual.animation_speed_fps": float((n.get("animation_speed_spin") as SpinBox).value),
		"visual.scale": Vector2(float((n.get("scale_x_spin") as SpinBox).value), float((n.get("scale_y_spin") as SpinBox).value)),
		"visual.modulate": (n.get("modulate_picker") as ColorPickerButton).color,
		"visual.position_offset": Vector2(float((n.get("offset_x_spin") as SpinBox).value), float((n.get("offset_y_spin") as SpinBox).value)),
		"visual.anchor_bottom": (n.get("anchor_bottom_check") as CheckButton).button_pressed,
		"visual.idle_bounce_enabled": (n.get("idle_bounce_enabled_check") as CheckButton).button_pressed,
		"visual.idle_bounce_min_y_scale": float((n.get("idle_bounce_min_y_spin") as SpinBox).value),
		"visual.idle_bounce_cycle_seconds": float((n.get("idle_bounce_cycle_spin") as SpinBox).value),
	})
	_reload_config_preview_only()


func _apply_collision_patch() -> void:
	if not (n.get("collision_enabled_check") as CheckButton).button_pressed:
		AssetConfigService.upsert_override(_selected_kind, _selected_asset_id, {"collision.enabled": false})
		_reload_config_preview_only()
		return

	var path := AssetConfigService.upsert_collision_profile_override(_selected_kind, _selected_asset_id, {
		"physics_shape_type": _selected_option_id(n.get("physics_shape_dropdown"), CollisionProfile.ShapeType.CIRCLE),
		"physics_size": Vector2(float((n.get("physics_size_x_spin") as SpinBox).value), float((n.get("physics_size_y_spin") as SpinBox).value)),
		"hurtbox_shape_type": _selected_option_id(n.get("hurtbox_shape_dropdown"), CollisionProfile.ShapeType.CIRCLE),
		"hurtbox_size": Vector2(float((n.get("hurtbox_size_x_spin") as SpinBox).value), float((n.get("hurtbox_size_y_spin") as SpinBox).value)),
		"deals_contact_damage": (n.get("deals_contact_damage_check") as CheckButton).button_pressed,
		"damage_cooldown": float((n.get("damage_cooldown_spin") as SpinBox).value),
	})
	if path.is_empty():
		_sync_collision_controls(_current_config)
		return
	AssetConfigService.upsert_override(_selected_kind, _selected_asset_id, {"collision.enabled": true, "collision.live_apply": true})
	_reload_config_preview_only()


func _reload_config_preview_only() -> void:
	_current_config = AssetConfigService.get_asset_config(_selected_kind, _selected_asset_id)
	_update_preview()
	if _current_config and _current_config.collision:
		(n.get("collision_profile_path_label") as Label).text = "Profile: %s" % _current_config.collision.collision_profile_path


func _collect_texture_paths() -> Dictionary:
	var result := {}
	for slot_key in _texture_inputs.keys():
		var input := _texture_inputs[slot_key] as LineEdit
		if input == null:
			continue
		var value := input.text.strip_edges()
		if value.is_empty():
			continue
		result[slot_key] = value
	return result


func _on_reset_field() -> void:
	if not _can_edit() or _last_field.is_empty():
		return
	if _last_field.begins_with("visual."):
		var value = _base_visual_value(_last_field)
		if value != null:
			AssetConfigService.upsert_override(_selected_kind, _selected_asset_id, {_last_field: value})
			_load_config()
		return
	if _last_field.begins_with("collision_profile.") and _base_profile:
		var key := _last_field.trim_prefix("collision_profile.")
		var patch := {}
		match key:
			"physics_shape_type": patch[key] = _base_profile.physics_shape_type
			"physics_size": patch[key] = _base_profile.physics_size
			"hurtbox_shape_type": patch[key] = _base_profile.hurtbox_shape_type
			"hurtbox_size": patch[key] = _base_profile.hurtbox_size
			"deals_contact_damage": patch[key] = _base_profile.deals_contact_damage
			"damage_cooldown": patch[key] = _base_profile.damage_cooldown
		if not patch.is_empty():
			AssetConfigService.upsert_collision_profile_override(_selected_kind, _selected_asset_id, patch)
			_load_config()


func _base_visual_value(path: String) -> Variant:
	if _base_config == null or _base_config.visual == null:
		return null
	var v := _base_config.visual
	match path:
		"visual.sprite_kind": return v.sprite_kind
		"visual.orientation_mode": return v.orientation_mode
		"visual.sprite_frames_path": return v.sprite_frames_path
		"visual.animation_speed_fps": return v.animation_speed_fps
		"visual.scale": return v.scale
		"visual.modulate": return v.modulate
		"visual.position_offset": return v.position_offset
		"visual.anchor_bottom": return v.anchor_bottom
		"visual.idle_bounce_enabled": return v.idle_bounce_enabled
		"visual.idle_bounce_min_y_scale": return v.idle_bounce_min_y_scale
		"visual.idle_bounce_cycle_seconds": return v.idle_bounce_cycle_seconds
		"visual.animation_map.left": return str(v.animation_map.get("left", ""))
		"visual.animation_map.right": return str(v.animation_map.get("right", ""))
		_:
			if path.begins_with("visual.texture_paths."):
				return str(v.texture_paths.get(path.trim_prefix("visual.texture_paths."), ""))
	return null


func _on_reset_asset() -> void:
	if not _can_edit():
		return
	AssetConfigService.clear_override(_selected_kind, _selected_asset_id)
	_load_config()


func _on_revert_preset() -> void:
	var active := AssetConfigService.get_active_preset()
	if AssetConfigService.get_preset_origin(active) != "user":
		return
	var base := AssetConfigService.get_user_preset_base(active)
	AssetConfigService.delete_user_preset(active)
	AssetConfigService.create_user_preset(active, base)
	AssetConfigService.set_active_preset(active)
	_refresh_presets()
	_refresh_assets(true)


func _update_editability() -> void:
	_editing_enabled = AssetConfigService.get_preset_origin(AssetConfigService.get_active_preset()) == "user"
	(n.get("clone_cta_button") as Button).visible = not _editing_enabled
	(n.get("delete_preset_button") as Button).disabled = not _editing_enabled
	(n.get("revert_preset_button") as Button).disabled = not _editing_enabled
	(n.get("read_only_label") as Label).text = "Editing enabled" if _editing_enabled else "Built-in preset is read-only. Clone it to edit."
	_disable_tree(n.get("visual_tab"), not _editing_enabled)
	var disable_collision := not _editing_enabled or _selected_kind == EntityAssetConfig.EntityKind.TURRET
	_disable_tree(n.get("collision_tab"), disable_collision)


func _disable_tree(root: Node, disabled: bool) -> void:
	if root == null:
		return
	for child in root.get_children():
		if child is BaseButton:
			(child as BaseButton).disabled = disabled
		elif child is OptionButton:
			(child as OptionButton).disabled = disabled
		elif child is LineEdit:
			(child as LineEdit).editable = not disabled
		elif child is SpinBox:
			(child as SpinBox).editable = not disabled
		elif child is ColorPickerButton:
			(child as ColorPickerButton).disabled = disabled
		_disable_tree(child, disabled)


func _can_edit() -> bool:
	return _editing_enabled and not _selected_asset_id.is_empty()


func _update_preview() -> void:
	var p: AssetStudioPreview = n.get("preview")
	if p:
		p.set_preview_config(_selected_kind, _selected_asset_id, _current_config)


func _load_profile(cfg: EntityAssetConfig) -> CollisionProfile:
	if cfg == null or cfg.collision == null:
		return null
	var path := cfg.collision.collision_profile_path
	if path.is_empty():
		return null
	if path.begins_with("user://"):
		if not FileAccess.file_exists(path):
			return null
	elif not ResourceLoader.exists(path):
		return null
	var res = ResourceLoader.load(path)
	if res is CollisionProfile:
		return res
	return null


func _select_option_id(option: OptionButton, wanted_id: int) -> void:
	if option == null:
		return
	for i in range(option.item_count):
		if option.get_item_id(i) == wanted_id:
			option.select(i)
			return
	if option.item_count > 0:
		option.select(0)


func _selected_option_id(option: OptionButton, fallback: int) -> int:
	if option == null or option.selected < 0:
		return fallback
	return option.get_item_id(option.selected)


func _set_last_field(field_key: String) -> void:
	_last_field = field_key
