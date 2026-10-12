class_name PreparationPhase
extends Node3D

## Untimed direct turret placement. The hero remains at its combat position, hidden and inactive.
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
var deploy_button: Button

func _ready() -> void:
	GameStateMachine.state_changed.connect(func(_old: int, phase: int) -> void:
		if active and phase != GameStateMachine.GameState.PREPARATION: end())

func begin() -> void:
	end()
	active = true
	world.placement.drop_carried()
	world.player.hide()
	cursor = world.player.position
	if not world.turrets.is_empty():
		selected = world.turrets[0]
		cursor = selected.position
	view_focus = cursor
	if not is_instance_valid(cursor_dial):
		cursor_dial = GroundDial.create(self, .6, UiPalette.TEAL_HI)
		range_dial = GroundDial.create(self, 1.0, Color(.35, .85, .83, .45), true)
	if world.show_hud and not layer: _build_ui()
	var focus := get_viewport().gui_get_focus_owner()
	if focus: focus.release_focus()
	_refresh()

func end() -> void:
	cancel_move()
	active = false
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
	if not GameStateMachine.transition_to(GameStateMachine.GameState.WAVE_ANNOUNCEMENT): return false
	end()
	world.camera_rig.snap()
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
		match event.physical_keycode:
			KEY_SPACE, KEY_E: interact()
			KEY_ENTER, KEY_KP_ENTER: deploy()
			KEY_BACKSPACE: cancel_move()
			KEY_BRACKETLEFT: cycle(-1)
			KEY_BRACKETRIGHT: cycle(1)
			_: return false
		return true
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_A: interact()
			JOY_BUTTON_B: cancel_move()
			JOY_BUTTON_X: deploy()
			JOY_BUTTON_LEFT_SHOULDER: cycle(-1)
			JOY_BUTTON_RIGHT_SHOULDER: cycle(1)
			_: return false
		return true
	return false

func _aim_mouse(screen: Vector2) -> void:
	if world.playfield:
		if not world.playfield.rect.has_point(screen): return
		screen -= world.playfield.rect.position
	var origin := world.camera.project_ray_origin(screen)
	var ray := world.camera.project_ray_normal(screen)
	var point: Variant = Plane(Vector3.UP, 0).intersects_ray(origin, ray)
	if point != null: set_cursor(point)

func _refresh() -> void:
	var has_selection := is_instance_valid(selected)
	var valid := not moving or world.valid_placement(cursor, selected)
	cursor_dial.visible = active
	cursor_dial.position = cursor + Vector3(0, .05, 0)
	GroundDial.recolor(cursor_dial, UiPalette.TEAL_HI if valid else Color("ff7272"))
	GroundDial.update(cursor_dial, 1.0 if has_selection else .0, not valid)
	range_dial.visible = active and has_selection
	if has_selection:
		var stats := selected.resolve_attack_stats()
		var reach := float(stats.get("range", 0)) * WorldGeometry.METRES_PER_PIXEL
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
	move_button.text = "PLACE  A / Space" if moving else "MOVE  A / Space"
	move_button.disabled = not has_selection or not valid
	cancel_button.disabled = not moving
	deploy_button.disabled = moving

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
	title = _label(top, "", 26, UiPalette.TEAL_HI)
	hint = _label(top, "", 18, UiPalette.INK)
	var footer := PanelContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 28
	footer.offset_right = -28
	footer.offset_top = -180
	footer.offset_bottom = -24
	footer.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	root.add_child(footer)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	footer.add_child(column)
	detail = _label(column, "", 25, UiPalette.INK)
	_label(column, "Aim: mouse / left stick / WASD    Cycle turrets: LB / RB or [ / ]    Zoom: triggers / wheel", 18, UiPalette.MUTED)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)
	move_button = _button(row, "MOVE  A / Space", interact)
	cancel_button = _button(row, "CANCEL  B / Right click", cancel_move)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	deploy_button = _button(row, "DEPLOY  X / Enter", deploy, true)

func _label(parent: Node, text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, .9))
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable, primary: bool = false) -> Button:
	var button := IconButton.new().setup("deploy" if primary else "turret", text, primary)
	button.focus_mode = Control.FOCUS_NONE # A operates the cursor, never an accidentally focused Deploy button.
	button.pressed.connect(action)
	parent.add_child(button)
	return button
