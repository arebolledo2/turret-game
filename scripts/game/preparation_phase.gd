class_name PreparationPhase
extends Node3D

## Untimed direct turret placement. Each wave starts from a consistent central staging position.
var world: ArenaWorld
var active := false
var cursor := Vector3.ZERO
var view_focus := Vector3.ZERO
var selected: TurretActor
var moving := false
var move_origin := Vector3.ZERO
var cursor_dial: MeshInstance3D
var range_dial: MeshInstance3D
var layer: CanvasLayer
var title: Label
var detail: Label
var hint: Label
var move_button: Button
var cancel_button: Button
var layout_button: Button
var auto_button: Button
var deploy_button: Button
var save_button: Button
var note: Label
var badges: Dictionary = {}
var controls: Label
var layout_buttons: Array[Button] = []
var layout_row: Array[Button] = []
var action_row: Array[Button] = []
const LAYOUT_NAMES := ["TIGHT", "BALANCED", "AREA COVERAGE", "MAX SPREAD", "SAVED"]
const LAYOUT_SHORT := ["TIGHT", "BALANCED", "AREA", "SPREAD", "SAVED"]
const LAYOUT_KINDS := ["tight", "balanced", "area", "spread", "saved"]
const LAYOUT_NOTES := [
	"Tight: turrets bunch up near the core.",
	"Balanced: turrets ring the core with overlapping reach.",
	"Area: turret reach just touches, covering the most ground.",
	"Spread: turrets sit as far apart as the arena allows.",
	"Saved: your remembered turret positions. Press SAVE to remember the current ones.",
]
const SAVED := TurretLayoutSolver.SAVED
var saved_positions: Dictionary = {}
var new_markers: Dictionary = {}
var solver: TurretLayoutSolver

func reset_layout() -> void:
	saved_positions.clear()
	_clear_new_markers()

func _clear_new_markers() -> void:
	for marker in new_markers.values():
		if is_instance_valid(marker): marker.queue_free()
	new_markers.clear()

func save_layout() -> void:
	if not active or world.paused or moving or not _layout_valid(): return
	_snapshot_layout()
	SettingsService.auto_prepare_mode = SAVED
	FeatureFlagService.set_enabled(FeatureFlagService.AUTO_DEPLOY, true)
	SettingsService.save_preferences()
	_clear_new_markers()
	_refresh()

func _snapshot_layout() -> void:
	saved_positions.clear()
	for turret in world.turrets: saved_positions[turret.turret_id] = turret.position

func _mark_new(turret: TurretActor) -> void:
	if new_markers.has(turret.turret_id): return
	var label := Label3D.new()
	label.text = "NEW"
	label.font_size = 48
	label.pixel_size = .008
	label.modulate = Color("ffc55c")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
	new_markers[turret.turret_id] = label


func _ready() -> void:
	GameStateMachine.state_changed.connect(func(_old: int, phase: int) -> void:
		if active and phase != GameStateMachine.GameState.PREPARATION: end())

func begin() -> void:
	end()
	active = true
	world.placement.drop_carried()
	_reset_hero_start()
	world.player.hide()
	if FeatureFlagService.is_enabled(FeatureFlagService.AUTO_DEPLOY): arrange_turrets()
	cursor = world.player.position
	if not world.turrets.is_empty():
		selected = world.turrets[0]
		cursor = selected.position
	view_focus = Vector3.ZERO
	world.camera_rig.set_zoom(GameConstants.CAMERA_ZOOM_MIN)
	world.camera_rig.snap()
	if not is_instance_valid(cursor_dial):
		cursor_dial = GroundDial.create(self, .6, UiPalette.TEAL_HI)
		range_dial = GroundDial.create(self, 1.0, Color(.35, .85, .83, .45), true)
	if world.show_hud and not layer: _build_ui()
	var focus := get_viewport().gui_get_focus_owner()
	if focus: focus.release_focus()
	_refresh()

## Centre the hero without placing them inside the stationary core.
func _reset_hero_start() -> void:
	var at := Vector3.ZERO
	if is_instance_valid(world.core):
		var clearance := maxf(GameConstants.CORE_START_OFFSET, world.core.radius + world.player.hurtbox_radius() + .25)
		if WorldGeometry.planar(world.core.position).length() < clearance:
			var away := WorldGeometry.planar(-world.core.position).normalized()
			if away == Vector3.ZERO: away = Vector3.BACK
			at = WorldGeometry.planar(world.core.position) + away * clearance
	world.player.position = at
	world.player.velocity = Vector3.ZERO
	world.player.knockback_velocity = Vector3.ZERO
	world.player.reset_physics_interpolation()

func end() -> void:
	cancel_move()
	active = false
	_clear_new_markers()
	selected = null
	if is_instance_valid(world.player): world.player.show()
	if is_instance_valid(cursor_dial): cursor_dial.hide()
	if is_instance_valid(range_dial): range_dial.hide()
	if layer: layer.hide()

func _input(event: InputEvent) -> void:
	# Cursor commands must precede GUI focus navigation (especially after leaving Shop).
	if event is InputEventJoypadButton and handle_input(event):
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if not active: return
	if GameStateMachine.current_state != GameStateMachine.GameState.PREPARATION:
		end()
		return
	if layer: layer.visible = not world.paused
	if world.paused: return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var stick := Input.get_vector("gamepad_left", "gamepad_right", "gamepad_up", "gamepad_down")
	if stick.length_squared() > direction.length_squared(): direction = stick
	if direction.length_squared() > .01:
		set_cursor(cursor + Vector3(direction.x, 0, direction.y) * delta * 7.0)
		view_focus = cursor
	_refresh()

func set_cursor(at: Vector3) -> void:
	cursor = WorldGeometry.clamp_position(WorldGeometry.planar(at), TurretPlacement.EDGE_MARGIN)
	if moving and is_instance_valid(selected):
		selected.position = cursor
		selected.reset_physics_interpolation()
	elif not moving:
		selected = nearest(cursor)

func nearest(at: Vector3) -> TurretActor:
	var best: TurretActor
	var distance := 1.0
	for turret in world.turrets:
		var candidate := WorldGeometry.planar(turret.position - at).length()
		if candidate < distance:
			distance = candidate
			best = turret
	return best

func cycle(direction: int) -> void:
	if moving or world.turrets.is_empty(): return
	var index := world.turrets.find(selected)
	selected = world.turrets[posmod(index + direction, world.turrets.size())]
	cursor = selected.position
	view_focus = cursor
	_refresh()

func interact() -> bool:
	if not active or world.paused or not is_instance_valid(selected): return false
	if moving:
		if not world.valid_placement(cursor, selected):
			_refresh()
			return false
		selected.position = cursor
		if cursor.distance_to(move_origin) > .01:
			selected.reset_entrench()
			selected.invalidate_stats()
			world.telemetry.record_turret_move()
		selected.reset_physics_interpolation()
		moving = false
	else:
		move_origin = selected.position
		cursor = move_origin
		moving = true
	_refresh()
	return true

func cancel_move() -> void:
	if moving and is_instance_valid(selected):
		selected.position = move_origin
		selected.reset_physics_interpolation()
		cursor = move_origin
	moving = false

func deploy() -> bool:
	if not active or world.paused or moving: return false
	if not _layout_valid(): return false
	if SettingsService.auto_prepare_mode == SAVED: _snapshot_layout()
	if not GameStateMachine.transition_to(GameStateMachine.GameState.WAVE_ANNOUNCEMENT): return false
	end()
	world.camera_rig.snap()
	world.camera_rig.set_zoom(GameConstants.CAMERA_DEFAULT_ZOOM)
	world.audio.play_cue("wave", world.player.position)
	return true

## Called before normal arena shortcuts. Mouse UI clicks are consumed by their buttons first.
func handle_input(event: InputEvent) -> bool:
	if not active or world.paused: return false
	if event is InputEventMouseMotion:
		if event.relative.length_squared() > 1.0: _aim_mouse(event.position)
		return false
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if world.playfield and not world.playfield.rect.has_point(event.position): return false
			_aim_mouse(event.position)
			interact()
			return true
		if event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_move()
			return true
	if event is InputEventKey and event.pressed and not event.echo:
		if menu_focused() and event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]: return false
		match event.physical_keycode:
			KEY_SPACE, KEY_E: interact()
			KEY_ENTER, KEY_KP_ENTER: deploy()
			KEY_R: cycle_layout()
			KEY_F: toggle_auto()
			KEY_L: save_layout()
			KEY_BACKSPACE: cancel_move()
			KEY_BRACKETLEFT: cycle(-1)
			KEY_BRACKETRIGHT: cycle(1)
			_: return false
		return true
	if event is InputEventJoypadButton and event.pressed:
		var in_menu := menu_focused()
		# D-pad: left/right pick a turret on the map; down opens the option bar; up leaves it.
		match event.button_index:
			JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT:
				if in_menu: return false
				cycle(-1 if event.button_index == JOY_BUTTON_DPAD_LEFT else 1)
				return true
			JOY_BUTTON_DPAD_DOWN:
				if in_menu: return false
				focus_menu()
				return true
			JOY_BUTTON_DPAD_UP:
				if not in_menu: return false
				if get_viewport().gui_get_focus_owner() in layout_row: leave_menu()
				else: return false
				return true
		# While an option is focused A presses it (GUI handles ui_accept); B steps back to the map.
		if in_menu and event.button_index == JOY_BUTTON_A: return false
		if in_menu and event.button_index == JOY_BUTTON_B:
			leave_menu()
			return true
		match event.button_index:
			JOY_BUTTON_A: interact()
			JOY_BUTTON_B: cancel_move()
			JOY_BUTTON_RIGHT_STICK: cycle_layout()
			JOY_BUTTON_Y: toggle_auto()
			JOY_BUTTON_LEFT_STICK: save_layout()
			JOY_BUTTON_X: deploy()
			JOY_BUTTON_LEFT_SHOULDER: cycle(-1)
			JOY_BUTTON_RIGHT_SHOULDER: cycle(1)
			_: return false
		return true
	return false

func _aim_mouse(screen: Vector2) -> void:
	if world.playfield:
		if not world.playfield.rect.has_point(screen): return
		screen = world.playfield.to_viewport(screen)
	var origin := world.camera.project_ray_origin(screen)
	var ray := world.camera.project_ray_normal(screen)
	var point: Variant = Plane(Vector3.UP, 0).intersects_ray(origin, ray)
	if point != null: set_cursor(point)

func _refresh() -> void:
	for turret in world.turrets:
		if new_markers.has(turret.turret_id): new_markers[turret.turret_id].position = turret.position + Vector3(0, 1.3, 0)
	var has_selection := is_instance_valid(selected)
	var valid := not moving or world.valid_placement(cursor, selected)
	cursor_dial.visible = active
	cursor_dial.position = cursor + Vector3(0, .05, 0)
	GroundDial.recolor(cursor_dial, UiPalette.TEAL_HI if valid else Color("ff7272"))
	GroundDial.update(cursor_dial, 1.0 if has_selection else .0, not valid)
	range_dial.visible = active and has_selection
	if has_selection:
		var reach := selected.resolve_attack_view().range_metres
		GroundDial.resize(range_dial, reach)
		range_dial.position = selected.position + Vector3(0, .04, 0)
		GroundDial.update(range_dial, 1.0, false, 16)
		if detail: detail.text = "%s #%d  |  Range %.2f m" % [TurretRegistry.get_short_name(selected.turret_type), selected.turret_id, reach]
	elif detail:
		detail.text = "Select a turret to reposition it"
	if not layer: return
	layer.visible = active and not world.paused
	title.text = "PREPARE WAVE %02d" % GameStateService.current_wave
	hint.text = "Clear the core, other turrets and blocked ground." if not valid else ("Choose a position, then place. Cancel returns it to its original spot." if moving else "Take your time. The wave starts only when you Deploy.")
	move_button.text = "PLACE" if moving else "MOVE"
	move_button.disabled = not has_selection or not valid
	cancel_button.disabled = not moving
	save_button.disabled = moving or not _layout_valid()
	deploy_button.disabled = moving or not _layout_valid()
	var auto_on := FeatureFlagService.is_enabled(FeatureFlagService.AUTO_DEPLOY)
	auto_button.text = "AUTO " + ("ON" if auto_on else "OFF")
	auto_button.set_pressed_no_signal(auto_on)
	for i in layout_buttons.size():
		layout_buttons[i].set_pressed_no_signal(i == SettingsService.auto_prepare_mode and auto_on)
		layout_buttons[i].disabled = moving or (i == SAVED and saved_positions.is_empty())
	for button in layout_row + action_row: button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
	for button: Button in badges: badges[button].modulate.a = .35 if button.disabled else 1.0
	var focus := get_viewport().gui_get_focus_owner()
	if focus is Button and (focus in layout_row or focus in action_row) and focus.disabled:
		(move_button if not move_button.disabled else deploy_button).grab_focus()
	var layout_index := layout_buttons.find(focus)
	note.text = LAYOUT_NOTES[layout_index if layout_index >= 0 else SettingsService.auto_prepare_mode]
	if layout_index < 0 and not auto_on: note.text = "Auto is off: turrets stay where you put them."
	controls.text = "D-pad: move between options    A: choose    B / D-pad up: back to the map    X: deploy" if menu_focused() else "Left stick: aim    D-pad left/right or LB/RB: pick turret    A: move / place    D-pad down: layouts and options    X: deploy"
	if not moving and not _layout_valid(): hint.text = "Move turrets out of spawn zones, or use Auto Deploy."

func menu_focused() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus is Button and (focus in layout_row or focus in action_row)

## Hand the controller over to the option bar, starting on the active layout.
func focus_menu() -> void:
	if not active or world.paused or not layer: return
	var start := layout_buttons[SettingsService.auto_prepare_mode]
	if start.disabled or not FeatureFlagService.is_enabled(FeatureFlagService.AUTO_DEPLOY): start = move_button if not move_button.disabled else deploy_button
	start.grab_focus()
	_refresh()

func leave_menu() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus: focus.release_focus()
	_refresh()

func set_layout(mode: int) -> void:
	if not active or world.paused or (mode == SAVED and saved_positions.is_empty()): return
	cancel_move()
	SettingsService.auto_prepare_mode = mode
	FeatureFlagService.set_enabled(FeatureFlagService.AUTO_DEPLOY, true)
	SettingsService.save_preferences()
	arrange_turrets()
	if is_instance_valid(selected):
		cursor = selected.position
		view_focus = cursor
	_refresh()

func _build_ui() -> void:
	layer = CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 28
	panel.offset_right = -28
	panel.offset_top = 4
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	root.add_child(panel)
	var top := VBoxContainer.new()
	panel.add_child(top)
	title = UiBuilder.outlined_label(top, "", 26, UiPalette.TEAL_HI)
	hint = UiBuilder.outlined_label(top, "", 18, UiPalette.INK)
	var footer := PanelContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 28
	footer.offset_right = -28
	footer.offset_top = -330
	footer.offset_bottom = -24
	footer.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	root.add_child(footer)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	footer.add_child(column)
	detail = UiBuilder.outlined_label(column, "", 25, UiPalette.INK)
	note = UiBuilder.outlined_label(column, "", 20, UiPalette.TEAL_HI)
	controls = UiBuilder.outlined_label(column, "", 18, UiPalette.MUTED)
	var layout_line := HBoxContainer.new()
	layout_line.add_theme_constant_override("separation", 10)
	column.add_child(layout_line)
	auto_button = _button(layout_line, "AUTO", toggle_auto, "power", false, "Y")
	auto_button.toggle_mode = true
	for index in LAYOUT_SHORT.size():
		layout_buttons.append(_layout_choice(layout_line, index))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout_line.add_child(gap)
	var cycle_hint := HBoxContainer.new()
	cycle_hint.add_theme_constant_override("separation", 8)
	cycle_hint.alignment = BoxContainer.ALIGNMENT_END
	cycle_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cycle_hint.add_child(_glyph("RS"))
	UiBuilder.outlined_label(cycle_hint, "next layout", 18, UiPalette.MUTED)
	gap.add_child(cycle_hint)
	cycle_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	save_button = _button(layout_line, "SAVE", save_layout, "star", false, "LS")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)
	move_button = _button(row, "MOVE", interact, "motion", false, "A")
	cancel_button = _button(row, "CANCEL", cancel_move, "back", false, "B")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	deploy_button = _button(row, "DEPLOY", deploy, "deploy", true, "X")
	layout_row.assign([auto_button] + layout_buttons + [save_button])
	action_row.assign([move_button, cancel_button, deploy_button])
	# Rows stop at their edges; up from the layouts hands control back to the map.
	for button in layout_row: button.focus_neighbor_top = button.get_path_to(button)
	for button in action_row: button.focus_neighbor_bottom = button.get_path_to(button)
	for rowset in [layout_row, action_row]:
		rowset[0].focus_neighbor_left = rowset[0].get_path_to(rowset[0])
		rowset[-1].focus_neighbor_right = rowset[-1].get_path_to(rowset[-1])

## A toggle button showing a LayoutIcon over the layout's short name.
func _layout_choice(parent: Node, index: int) -> Button:
	var button := IconButton.new().setup("turret", "", false)
	button.icon = null
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(132, 104)
	button.pressed.connect(set_layout.bind(index))
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 4)
	button.add_child(stack)
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var picture := LayoutIcon.new().setup(LAYOUT_KINDS[index], 56.0)
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(picture)
	var caption := UiBuilder.outlined_label(stack, LAYOUT_SHORT[index], 18, UiPalette.INK)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(button)
	return button

## Option buttons take controller focus only after D-pad down, so A still operates the cursor on the map.
func _button(parent: Node, text: String, action: Callable, icon_name: String = "turret", primary: bool = false, glyph: String = "") -> Button:
	var button := IconButton.new().setup(icon_name, text, primary)
	button.focus_mode = Control.FOCUS_ALL
	button.focus_entered.connect(_refresh)
	button.focus_exited.connect(_refresh)
	button.pressed.connect(action)
	parent.add_child(button)
	if not glyph.is_empty():
		# Reserve room so the centred label never runs under the controller glyph.
		button.custom_minimum_size.x = 210
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var badge := _glyph(glyph)
		button.add_child(badge)
		badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		badge.offset_left = -44
		badge.offset_right = -14
		badge.offset_top = -15
		badge.offset_bottom = 15
		badges[button] = badge
	return button

## A small controller-button chip: coloured circle for A/B/X/Y, pill for stick clicks.
func _glyph(text: String) -> Control:
	var tint: Color = {"A": Color("5fc47a"), "B": Color("e0605a"), "X": Color("5b9be0"), "Y": Color("e6c24f")}.get(text, UiPalette.MUTED)
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.custom_minimum_size = Vector2(30, 30)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.bg_color = Color(tint, .22)
	box.border_color = tint
	box.set_border_width_all(2)
	box.set_corner_radius_all(15)
	box.content_margin_left = 6
	box.content_margin_right = 6
	chip.add_theme_stylebox_override("panel", box)
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", tint.lightened(.35))
	chip.add_child(label)
	return chip

func toggle_auto() -> void:
	if not active or world.paused: return
	cancel_move()
	var enabled := not FeatureFlagService.is_enabled(FeatureFlagService.AUTO_DEPLOY)
	FeatureFlagService.set_enabled(FeatureFlagService.AUTO_DEPLOY, enabled)
	SettingsService.save_preferences()
	if enabled: arrange_turrets()
	if is_instance_valid(selected):
		cursor = selected.position
		view_focus = cursor
	_refresh()

func _layout_valid() -> bool:
	if not FeatureFlagService.is_enabled(FeatureFlagService.RESTRICT_SPAWN_PLACEMENT): return true
	for turret in world.turrets:
		if world.placement.spawn_zone_blocked(turret.position): return false
	return true

func arrange_turrets() -> void:
	if not solver: solver = TurretLayoutSolver.new(world)
	for turret in solver.arrange(SettingsService.auto_prepare_mode, saved_positions):
		_mark_new(turret)


func cycle_layout() -> void:
	if not active or world.paused: return
	cancel_move()
	SettingsService.auto_prepare_mode = (SettingsService.auto_prepare_mode + 1) % LAYOUT_NAMES.size()
	SettingsService.save_preferences()
	if FeatureFlagService.is_enabled(FeatureFlagService.AUTO_DEPLOY): arrange_turrets()
	if is_instance_valid(selected):
		cursor = selected.position
		view_focus = cursor
	_refresh()

