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
const SAVED := 4
var saved_positions: Dictionary = {}
var new_markers: Dictionary = {}

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
	title = _label(top, "", 26, UiPalette.TEAL_HI)
	hint = _label(top, "", 18, UiPalette.INK)
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
	detail = _label(column, "", 25, UiPalette.INK)
	note = _label(column, "", 20, UiPalette.TEAL_HI)
	controls = _label(column, "", 18, UiPalette.MUTED)
	var layout_line := HBoxContainer.new()
	layout_line.add_theme_constant_override("separation", 10)
	column.add_child(layout_line)
	auto_button = _button(layout_line, "AUTO", toggle_auto, "power")
	auto_button.toggle_mode = true
	for index in LAYOUT_SHORT.size():
		layout_buttons.append(_layout_choice(layout_line, index))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout_line.add_child(gap)
	save_button = _button(layout_line, "SAVE", save_layout, "star")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)
	move_button = _button(row, "MOVE", interact, "motion")
	cancel_button = _button(row, "CANCEL", cancel_move, "back")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	deploy_button = _button(row, "DEPLOY", deploy, "deploy", true)
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
	var caption := _label(stack, LAYOUT_SHORT[index], 18, UiPalette.INK)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(button)
	return button

func _label(parent: Node, text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, .9))
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	return label

## Option buttons take controller focus only after D-pad down, so A still operates the cursor on the map.
func _button(parent: Node, text: String, action: Callable, icon_name: String = "turret", primary: bool = false) -> Button:
	var button := IconButton.new().setup(icon_name, text, primary)
	button.focus_mode = Control.FOCUS_ALL
	button.focus_entered.connect(_refresh)
	button.focus_exited.connect(_refresh)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

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

## Greedy, deterministic coverage layout; no gameplay RNG is consumed.
func arrange_turrets() -> void:
	if SettingsService.auto_prepare_mode == SAVED:
		_restore_layout()
		return
	if SettingsService.auto_prepare_mode == 3:
		_spread_layout()
		return
	var mode := SettingsService.auto_prepare_mode
	var placed: Array[Dictionary] = []
	var zones := world.spawn_zones.centres
	var restrict_zones := FeatureFlagService.is_enabled(FeatureFlagService.RESTRICT_SPAWN_PLACEMENT)
	var focus := world.core.position if is_instance_valid(world.core) else Vector3.ZERO
	var remaining := maxi(1, world.turrets.size() - zones.size())
	for index in world.turrets.size():
		var turret := world.turrets[index]
		var reach := _attack_reach(turret)
		var target := focus
		if index < zones.size():
			target = zones[index]
			if restrict_zones:
				var inward := WorldGeometry.planar(focus - zones[index]).normalized()
				if inward == Vector3.ZERO: inward = Vector3.RIGHT
				target += inward * (SpawnZones.RADIUS + TurretPlacement.EDGE_MARGIN + .3)
		elif world.convoy_mode and world.convoy_route:
			target = _route_position(float(index - zones.size() + 1) / (remaining + 1))
		elif mode != 2:
			var angle := TAU * float(index - zones.size()) / remaining
			target += Vector3(cos(angle), 0, sin(angle)) * (2.0 if mode == 0 else maxf(1.2, reach * .6) if mode == 1 else reach)
		var best := Vector3.INF
		var score := INF
		if world.valid_placement(target, turret):
			best = target
			score = _layout_score(target, target, reach, placed, mode)
		# Search the whole arena so crowded zones and terrain always have a fallback.
		for x in range(-40, 41):
			for z in range(-22, 23):
				var at := Vector3(x * .5, 0, z * .5)
				var cost := _layout_score(at, target, reach, placed, mode)
				if cost >= score: continue
				if not world.valid_placement(at, turret): continue
				best = at
				score = cost
		if mode == 2:
			# Exact tangencies fill the gaps a half-metre grid cannot resolve.
			for at in _coverage_candidates(target, reach, placed):
				var cost := _layout_score(at, target, reach, placed, mode)
				if cost < score and world.valid_placement(at, turret):
					best = at
					score = cost
			# Refine around obstacles and arena edges, where tangencies can be invalid.
			if best != Vector3.INF:
				for step: float in [.125, .03125]:
					for iteration in 8:
						var origin := best
						for direction in 8:
							var angle := TAU * direction / 8.0
							var at := origin + Vector3(cos(angle), 0, sin(angle)) * step
							var cost := _layout_score(at, target, reach, placed, mode)
							if cost < score and world.valid_placement(at, turret):
								best = at
								score = cost
						if best == origin: break
		if best == Vector3.INF:
			placed.append({"at": turret.position, "reach": reach})
			continue
		placed.append({"at": best, "reach": reach})
		if turret.position.distance_to(best) > .01:
			turret.position = best
			turret.reset_entrench()
			turret.invalidate_stats()
			turret.reset_physics_interpolation()
			world.telemetry.record_turret_move()

func _route_position(fraction: float) -> Vector3:
	var points := world.convoy_route.doors
	var length := 0.0
	for i in range(1, points.size()): length += points[i - 1].distance_to(points[i])
	var distance := fraction * length
	for i in range(1, points.size()):
		var leg := points[i - 1].distance_to(points[i])
		if distance <= leg: return points[i - 1].lerp(points[i], distance / maxf(.001, leg))
		distance -= leg
	return points[-1]

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

func _attack_reach(turret: TurretActor) -> float:
	var stats := turret._current_view(0.0)
	var mode := TurretRegistry.get_fire_mode(turret.turret_type)
	return stats.range_metres * (stats.area_size if mode in [TurretRegistry.FIRE_PULSE, TurretRegistry.FIRE_FLAME] else 1.0)

func _layout_score(at: Vector3, target: Vector3, reach: float, placed: Array[Dictionary], mode: int) -> float:
	var score := at.distance_squared_to(target)
	if mode == 0: return score
	# Only turret attack coverage counts; the core contributes no coverage radius.
	for other in placed:
		var separation := (reach + float(other.reach)) * (1.0 if mode == 2 else .6)
		var overlap := maxf(0, separation - at.distance_to(other.at))
		score += overlap * overlap * (10000.0 if mode == 2 else 20.0)
	return score

## Candidate centres tangent to one or two already placed attack circles.
func _coverage_candidates(target: Vector3, reach: float, placed: Array[Dictionary]) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for i in placed.size():
		var centre: Vector3 = placed[i].at
		var radius := reach + float(placed[i].reach)
		var toward := WorldGeometry.planar(target - centre).normalized()
		if toward == Vector3.ZERO: toward = Vector3.RIGHT
		result.append(centre + toward * radius)
		for j in range(i):
			var other: Vector3 = placed[j].at
			var other_radius := reach + float(placed[j].reach)
			var distance := centre.distance_to(other)
			if distance < .001 or distance > radius + other_radius or distance < absf(radius - other_radius): continue
			var along := (radius * radius - other_radius * other_radius + distance * distance) / (2.0 * distance)
			var height := sqrt(maxf(0.0, radius * radius - along * along))
			var axis := (other - centre) / distance
			var perpendicular := Vector3(-axis.z, 0, axis.x)
			result.append(centre + axis * along + perpendicular * height)
			result.append(centre + axis * along - perpendicular * height)
	return result

## Restore stable IDs first, then stage new acquisitions near the centre.
func _restore_layout() -> void:
	var originals: Dictionary = {}
	for turret in world.turrets:
		originals[turret.turret_id] = turret.position
		# Temporarily remove old positions from planar collision checks.
		turret.position = Vector3(1000 + turret.turret_id * 2, 0, 1000)
	var ordered := world.turrets.duplicate()
	ordered.sort_custom(func(a: TurretActor, b: TurretActor) -> bool:
		return saved_positions.has(a.turret_id) and not saved_positions.has(b.turret_id))
	for turret: TurretActor in ordered:
		var target: Vector3 = saved_positions.get(turret.turret_id, Vector3.ZERO)
		var best := _nearest_valid(target, turret)
		if best == Vector3.INF: best = originals[turret.turret_id]
		_set_layout_position(turret, best, originals[turret.turret_id])
		if not saved_positions.has(turret.turret_id): _mark_new(turret)

func _nearest_valid(target: Vector3, turret: TurretActor) -> Vector3:
	if world.valid_placement(target, turret): return target
	var best := Vector3.INF
	var score := INF
	for at in _layout_grid():
		var cost := at.distance_squared_to(target)
		if cost < score and world.valid_placement(at, turret):
			best = at
			score = cost
	return best

func _layout_grid() -> Array[Vector3]:
	var result: Array[Vector3] = []
	var extent := WorldGeometry.HALF_ARENA - Vector2.ONE * TurretPlacement.EDGE_MARGIN
	for x in range(int(ceil(extent.x * 2)) + 1):
		for z in range(int(ceil(extent.y * 2)) + 1):
			result.append(Vector3(minf(-extent.x + x, extent.x), 0, minf(-extent.y + z, extent.y)))
	return result

func _set_layout_position(turret: TurretActor, at: Vector3, original: Vector3) -> void:
	turret.position = at
	if at.distance_to(original) > .01:
		turret.reset_entrench()
		turret.invalidate_stats()
		world.telemetry.record_turret_move()
	turret.reset_physics_interpolation()

## Balance wall clearance against half the distance to the nearest turret.
## Start with evenly sized cells so four turrets occupy quadrant centres.
func _spread_layout() -> void:
	if world.turrets.is_empty(): return
	var originals: Dictionary = {}
	var targets: Array[Vector3] = []
	var count := world.turrets.size()
	var columns := 1
	var best_shape := INF
	for candidate in range(1, count + 1):
		var rows := ceili(float(count) / candidate)
		var aspect := WorldGeometry.HALF_ARENA.x * rows / (WorldGeometry.HALF_ARENA.y * candidate)
		var shape := absf(log(aspect)) + (candidate * rows - count) * 1.0
		if shape < best_shape:
			best_shape = shape
			columns = candidate
	var rows := ceili(float(count) / columns)
	for turret in world.turrets:
		originals[turret.turret_id] = turret.position
		turret.position = Vector3(1000 + turret.turret_id * 2, 0, 1000)
	for index in count:
		var row := index / columns
		var in_row := mini(columns, count - row * columns)
		var target := Vector3(
			((index % columns + .5) / in_row * 2.0 - 1.0) * WorldGeometry.HALF_ARENA.x,
			0, ((row + .5) / rows * 2.0 - 1.0) * WorldGeometry.HALF_ARENA.y)
		targets.append(target)
		var turret := world.turrets[index]
		var at := _nearest_valid(target, turret)
		turret.position = at if at != Vector3.INF else originals[turret.turret_id]
	var candidates := _layout_grid()
	for iteration in 4:
		for index in count:
			var turret := world.turrets[index]
			var best := turret.position
			var score := _spread_score(best, turret, targets[index])
			for at in candidates:
				var clearance := _spread_score(at, turret, targets[index])
				if _better_spread(at, clearance, best, score, targets[index]) and world.valid_placement(at, turret):
					best = at
					score = clearance
			for step: float in [.25, .0625]:
				for refinement in 8:
					var origin := best
					for direction in 8:
						var angle := TAU * direction / 8.0
						var at := origin + Vector3(cos(angle), 0, sin(angle)) * step
						var clearance := _spread_score(at, turret, targets[index])
						if _better_spread(at, clearance, best, score, targets[index]) and world.valid_placement(at, turret):
							best = at
							score = clearance
					if best == origin: break
			turret.position = best
	for turret in world.turrets: _set_layout_position(turret, turret.position, originals[turret.turret_id])

func _better_spread(at: Vector3, score: float, best: Vector3, best_score: float, target: Vector3) -> bool:
	return score > best_score + .001 or (absf(score - best_score) <= .001 and at.distance_squared_to(target) < best.distance_squared_to(target) - .001)

func _spread_score(at: Vector3, turret: TurretActor, target: Vector3) -> float:
	# Prefer evenly distributed cells over a staggered circle-packing arrangement.
	var scale := minf(WorldGeometry.HALF_ARENA.x, WorldGeometry.HALF_ARENA.y)
	return _spread_clearance(at, turret) - at.distance_squared_to(target) * .75 / scale

func _spread_clearance(at: Vector3, excluded: TurretActor) -> float:
	var wall := minf(WorldGeometry.HALF_ARENA.x - absf(at.x), WorldGeometry.HALF_ARENA.y - absf(at.z))
	# Equal personal space: each turret contributes half the gap between neighbours.
	return minf(wall, sqrt(_nearest_distance(at, excluded)) * .5)

func _nearest_distance(at: Vector3, excluded: TurretActor) -> float:
	var distance := INF
	for turret in world.turrets:
		if turret != excluded: distance = minf(distance, at.distance_squared_to(turret.position))
	return distance
