class_name DevPanel
extends CanvasLayer

## Developer overlay: feature flags, presets, cheats and live debug counts.
## Opens with F1 or Back + right-stick click, closes with the same input, B or Escape. Controller
## navigation uses the standard focus actions (d-pad / left stick, A to activate, B to close).
## While open it pauses the run; only reachable in dev builds (`FeatureFlagService.dev_panel_available`).
const SPAWN_TYPES: Array[String] = ["basic", "fast", "tank", "exploder", "charger"]
const TIME_SCALES: Array[float] = [0.25, 0.5, 1.0, 2.0, 4.0]
const PANEL_WIDTH: float = 620.0

var world: ArenaWorld
var is_open: bool = false
var root: Control
var list: VBoxContainer
var status_label: Label
var progression_label: Label
var overlay_label: Label
var flag_checks: Dictionary = {}
var flag_notes: Dictionary = {}
var god_check: CheckButton
var level_box: VBoxContainer
var add_turret_button: Button
var add_turret_index: int = 0
var _level_signature: String = ""
var spawn_button: Button
var jump_prev_button: Button
var jump_next_button: Button
var time_button: Button
var spawn_index: int = 0
var time_index: int = 2
var _paused_before: bool = false
var _built: bool = false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay_label = Label.new()
	overlay_label.position = Vector2(28, 130)
	overlay_label.add_theme_font_size_override("font_size", 15)
	overlay_label.add_theme_color_override("font_color", Color("e8f7a0"))
	overlay_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, .85))
	overlay_label.add_theme_constant_override("outline_size", 4)
	overlay_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay_label)
	FeatureFlagService.flag_changed.connect(_on_flag_changed)
	FeatureFlagService.pending_changed.connect(refresh)

func _on_flag_changed(_flag_id: String, _enabled: bool) -> void:
	refresh()

func _exit_tree() -> void:
	if FeatureFlagService.flag_changed.is_connected(_on_flag_changed):
		FeatureFlagService.flag_changed.disconnect(_on_flag_changed)
	if FeatureFlagService.pending_changed.is_connected(refresh):
		FeatureFlagService.pending_changed.disconnect(refresh)
	Engine.time_scale = 1.0
	if is_open and is_instance_valid(world):
		world.dev_menu_open = false

## Live counts shown without opening the panel (flag `debug_overlays`).
func _process(_delta: float) -> void:
	var show_overlay := FeatureFlagService.dev_panel_available() and FeatureFlagService.is_enabled(FeatureFlagService.DEBUG_OVERLAYS)
	overlay_label.visible = show_overlay
	if show_overlay and is_instance_valid(world) and is_instance_valid(world.player):
		overlay_label.text = overlay_text()
	if is_open and not _focus_inside():
		_focus_first()

func overlay_text() -> String:
	var lines := PackedStringArray()
	lines.append("DEBUG  %d fps  %.1f ms" % [Engine.get_frames_per_second(), 1000.0 * get_process_delta_time()])
	lines.append("%s  wave %d/%d" % [GameStateMachine.get_state_name(GameStateMachine.current_state), world.session.state.current_wave, world.wave_limit])
	lines.append("enemies %d  turrets %d  shots %d" % [world.enemies.size(), world.turrets.size(), _active_projectiles()])
	lines.append("scrap %d  kills %d" % [world.session.state.total_scrap, world.session.state.total_kills])
	if FeatureFlagService.has_pending():
		lines.append("pending: " + ", ".join(PackedStringArray(FeatureFlagService.get_pending().keys())))
	var enabled := PackedStringArray()
	for flag_id in FeatureFlagService.get_flag_ids(FeatureFlagService.SCOPE_EXPERIMENT):
		if FeatureFlagService.is_enabled(flag_id):
			enabled.append(flag_id)
	lines.append("experiments: " + (", ".join(enabled) if not enabled.is_empty() else "none"))
	return "\n".join(lines)

## Values are read from the run, not the next-run flag or type-wide shop averages.
func progression_text() -> String:
	var active := world.session.state.turret_progression_enabled
	var lines := PackedStringArray(["This run: %s | additional frames acquired: %d" % [
		"ON" if active else "OFF", world.session.state.additional_turrets_acquired]])
	lines.append("Evolution forms and choices are pending Phase 2.")
	for turret in world.turrets:
		var growth := turret.progression
		var stats := turret._current_view(0.0)
		lines.append("#%d %s%s | Lv %d | XP %d/%d (%d total)" % [turret.turret_id,
			turret.turret_type, " [carried]" if turret.carried else "", growth.level,
			growth.xp, TurretProgression.cost_to_next(growth.level), growth.total_xp])
		lines.append("Damage %.2f | level bonus +%.0f%% | pending %s" % [stats.damage,
			(growth.damage_multiplier() - 1.0) * 100.0, str(growth.pending_evolutions)])
	var ledger := world.salvage.last_settlement
	if not ledger.is_empty():
		lines.append("Last settlement (wave %d): %d scrap -> %d XP, %d fallback cash" % [
			ledger["wave"], ledger["raw_scrap"], ledger["xp_awarded"], ledger["fallback_cash"]])
	return "\n".join(lines)

func _active_projectiles() -> int:
	var count := 0
	for projectile in world.projectiles:
		if projectile.active:
			count += 1
	return count

func _input(event: InputEvent) -> void:
	if not FeatureFlagService.dev_panel_available():
		return
	var toggle := false
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F1:
		toggle = true
	elif event is InputEventJoypadButton and event.pressed:
		var chord_partner := JOY_BUTTON_BACK if event.button_index == JOY_BUTTON_RIGHT_STICK else JOY_BUTTON_RIGHT_STICK
		toggle = event.button_index in [JOY_BUTTON_BACK, JOY_BUTTON_RIGHT_STICK] and Input.is_joy_button_pressed(event.device, chord_partner)
	if toggle:
		set_open(not is_open)
		get_viewport().set_input_as_handled()
		return
	if is_open:
		var back: bool = event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)
		if back:
			set_open(false)
		# Pause, carry and restart keys must not reach the arena while the panel owns input.
		# Navigation and activation are left for the GUI, which consumes them itself.
		var swallow := back
		if event is InputEventKey and event.pressed:
			swallow = swallow or event.physical_keycode in [KEY_ESCAPE, KEY_E, KEY_R]
		elif event is InputEventJoypadButton and event.pressed:
			swallow = swallow or event.button_index == JOY_BUTTON_START
		if swallow:
			get_viewport().set_input_as_handled()

func set_open(value: bool) -> void:
	if value == is_open or not is_instance_valid(world):
		return
	if value:
		if not _built:
			_build()
		_paused_before = world.paused
		world.paused = true
		world.dev_menu_open = true
		refresh()
	else:
		world.paused = _paused_before
		world.dev_menu_open = false
		var focus := get_viewport().gui_get_focus_owner()
		if focus and _contains(root, focus):
			focus.release_focus()
	is_open = value
	root.visible = value
	if value:
		_focus_first()

func _contains(ancestor: Node, node: Node) -> bool:
	return ancestor == node or ancestor.is_ancestor_of(node)

func _focus_inside() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus != null and _contains(root, focus)

func _focus_first() -> void:
	for control in list.find_children("*", "BaseButton", true, false):
		if (control as BaseButton).is_visible_in_tree():
			(control as BaseButton).grab_focus()
			return

# =============================================================================
# UI
# =============================================================================
func _build() -> void:
	_built = true
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, .55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -PANEL_WIDTH
	panel.offset_top = 16
	panel.offset_bottom = -16
	panel.offset_right = -16
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0b1a22")
	style.border_color = Color("e8f7a0")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	UiBuilder.label(column, "DEV PANEL", 26, Color("e8f7a0"), true, true)
	UiBuilder.label(column, "D-pad / stick: move   A: activate   B / F1: close   Run is paused while open", 14, Color("9db8bd"), true, true)
	status_label = UiBuilder.label(column, "", 15, Color("f4d298"), true, true)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	_section("TURRET PROGRESSION / PHASE 1")
	progression_label = UiBuilder.label(list, "", 16, Color("d2edeb"), true, true)
	_build_presets()
	_build_flags()
	_build_cheats()
	_button(column, "CLOSE", func() -> void: set_open(false))
	root.visible = false

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _check(parent: Node, text: String, action: Callable) -> CheckButton:
	var button := CheckButton.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.add_theme_font_size_override("font_size", 18)
	button.toggled.connect(action)
	parent.add_child(button)
	return button

func _section(title: String) -> void:
	UiBuilder.label(list, title, 17, Color("71d3d3"), true, true)

func _build_presets() -> void:
	_section("FLAG PRESETS")
	for preset_id in FeatureFlagService.get_preset_ids():
		var preset: Dictionary = FeatureFlagService.PRESETS[preset_id]
		_button(list, "%s  -  %s" % [preset["label"], preset["description"]], func() -> void: apply_preset(preset_id))

func _build_flags() -> void:
	for scope in [FeatureFlagService.SCOPE_DEV, FeatureFlagService.SCOPE_EXPERIMENT, FeatureFlagService.SCOPE_USER]:
		var ids := FeatureFlagService.get_flag_ids(scope)
		_section("%s FLAGS%s" % [scope.to_upper(), "" if not ids.is_empty() else "  (none yet)"])
		for flag_id in ids:
			var definition := FeatureFlagService.get_definition(flag_id)
			var check := _check(list, str(definition["name"]), func(pressed: bool) -> void: toggle_flag(flag_id, pressed))
			flag_checks[flag_id] = check
			flag_notes[flag_id] = UiBuilder.label(list, "", 13, Color("9db8bd"), true, true)

func _build_cheats() -> void:
	_section("RUN")
	_button(list, "+50 scrap", func() -> void: _report(world.dev.add_scrap(50), "+50 scrap"))
	_button(list, "+500 scrap", func() -> void: _report(world.dev.add_scrap(500), "+500 scrap"))
	_button(list, "Restore hull", func() -> void: _report(world.dev.restore_hull(), "Hull restored"))
	god_check = _check(list, "God mode (player ignores damage)", func(pressed: bool) -> void: world.god_mode = pressed)
	jump_prev_button = _button(list, "", func() -> void: jump_waves(-1))
	jump_next_button = _button(list, "", func() -> void: jump_waves(1))
	_button(list, "Deploy now (skip shop)", func() -> void: _close_then(world.dev.skip_shop(), "Deploying"))
	_button(list, "Restart run", func() -> void: _close_then(restart_run(), "Restarted"))
	_section("ADD TURRET")
	add_turret_button = _button(list, "", func() -> void:
		var type_id := _add_turret_type()
		_report(world.dev.add_turret(type_id) > 0, "Added %s" % type_id))
	_button(list, "Next turret type", func() -> void:
		add_turret_index += 1
		refresh())
	_section("TURRET LEVELS (progression must be on for this run)")
	level_box = VBoxContainer.new()
	level_box.add_theme_constant_override("separation", 4)
	list.add_child(level_box)
	_section("ENEMIES")
	spawn_button = _button(list, "", func() -> void: _report(world.dev.spawn_enemy(SPAWN_TYPES[spawn_index], 5), "Spawned 5"))
	_button(list, "Next enemy type", func() -> void:
		spawn_index = (spawn_index + 1) % SPAWN_TYPES.size()
		refresh())
	_button(list, "Kill all enemies", func() -> void: _report(world.dev.kill_all_enemies(), "Killed"))
	_section("TIME")
	time_button = _button(list, "", func() -> void:
		time_index = (time_index + 1) % TIME_SCALES.size()
		Engine.time_scale = TIME_SCALES[time_index]
		refresh())

# =============================================================================
# Actions (also called directly by tests)
# =============================================================================
func toggle_flag(flag_id: String, enabled: bool) -> String:
	var result := FeatureFlagService.request_enabled(flag_id, enabled)
	if is_instance_valid(status_label):
		match result:
			FeatureFlagService.QUEUED: status_label.text = "%s will turn %s at the next wave." % [flag_id, "on" if enabled else "off"]
			FeatureFlagService.REJECTED: status_label.text = "%s cannot change (missing requirement)." % flag_id
			_: status_label.text = "%s is now %s." % [flag_id, "on" if enabled else "off"]
		if flag_id == FeatureFlagService.TURRET_PROGRESSION and result == FeatureFlagService.APPLIED:
			status_label.text = "Progression set %s for the next run. Restart to apply." % ("ON" if enabled else "OFF")
	refresh()
	return result

func apply_preset(preset_id: String) -> void:
	if world.session.state.is_game_active:
		# Experiments are applied between waves so systems never change under a live wave.
		var queued := 0
		for flag_id in FeatureFlagService.get_flag_ids(FeatureFlagService.SCOPE_EXPERIMENT):
			var wanted := bool(FeatureFlagService.PRESETS[preset_id]["experiments"])
			if FeatureFlagService.request_enabled(flag_id, wanted) == FeatureFlagService.QUEUED:
				queued += 1
		if is_instance_valid(status_label):
			status_label.text = "Preset %s: %d change(s) queued for the next wave." % [preset_id, queued]
	else:
		FeatureFlagService.apply_preset(preset_id)
	refresh()

func jump_waves(offset: int) -> void:
	_close_then(world.dev.jump_to_wave(world.session.state.current_wave + offset), "Jumped")

func restart_run() -> bool:
	world.start_run()
	return true

## One row per owned turret; rebuilt only when the roster changes so focus is not lost.
func _add_turret_type() -> String:
	var types := ShopCatalog.ids("turret")
	return types[add_turret_index % types.size()] if not types.is_empty() else ""

func _refresh_level_buttons() -> void:
	if not is_instance_valid(world):
		return
	var ids := PackedStringArray()
	for turret in world.turrets:
		ids.append("%d:%s" % [turret.turret_id, turret.turret_type])
	var signature := ",".join(ids)
	if signature == _level_signature:
		return
	_level_signature = signature
	for child in level_box.get_children():
		level_box.remove_child(child)
		child.queue_free()
	for turret in world.turrets:
		var id: int = turret.turret_id
		var row := HBoxContainer.new()
		level_box.add_child(row)
		var name_label := UiBuilder.label(row, "#%d %s" % [id, turret.turret_type], 16, Color("d2edeb"), true, true)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_button(row, "+1 level", func() -> void: _report(world.dev.level_up_turret(id), "Turret #%d +1 level" % id))
		_button(row, "To milestone", func() -> void: _report(world.dev.level_up_to_milestone(id), "Turret #%d to milestone" % id))

func _close_then(ok: bool, text: String) -> void:
	_report(ok, text)
	if ok:
		set_open(false)

func _report(result: Variant, text: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = text if result == null or bool(result) or (result is int and result > 0) else "Not available right now."
	refresh()

func refresh() -> void:
	if not _built:
		return
	_refresh_level_buttons()
	for flag_id: String in flag_checks:
		var check: CheckButton = flag_checks[flag_id]
		check.set_pressed_no_signal(FeatureFlagService.get_effective(flag_id))
		var definition := FeatureFlagService.get_definition(flag_id)
		var note := str(definition["description"])
		if not bool(definition["live_safe"]):
			note += "  (applies next wave)"
		if FeatureFlagService.get_pending().has(flag_id):
			note = "QUEUED %s - %s" % ["ON" if FeatureFlagService.get_effective(flag_id) else "OFF", note]
		(flag_notes[flag_id] as Label).text = note
	if is_instance_valid(world):
		progression_label.text = progression_text()
		god_check.set_pressed_no_signal(world.god_mode)
		var wave := world.session.state.current_wave
		jump_prev_button.text = "Jump to wave %d (opens its shop)" % clampi(wave - 1, 1, world.wave_limit)
		jump_next_button.text = "Jump to wave %d (opens its shop)" % clampi(wave + 1, 1, world.wave_limit)
	add_turret_button.text = "Add free turret: %s" % _add_turret_type()
	spawn_button.text = "Spawn 5 x %s" % SPAWN_TYPES[spawn_index]
	time_button.text = "Time scale: %sx (tap to cycle)" % str(TIME_SCALES[time_index])
