class_name TurretDetailsModal
extends Control

## Turret details over the shop: a dimmed backdrop and a panel holding the TurretInspector (roster,
## illustration, stats, evolution track and SELL). Opened from a squad card; B, Escape, the CLOSE button
## or a click on the backdrop closes it.
signal closed

var inspector: TurretInspector
var close_button: IconButton

func _init(world: ArenaWorld) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.01, 0.03, 0.05, .82)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close())
	add_child(backdrop)
	var center := MarginContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right"]:
		center.add_theme_constant_override("margin_" + side, 110)
	for side: String in ["top", "bottom"]:
		center.add_theme_constant_override("margin_" + side, 70)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ChamferStyle.make(UiPalette.PANEL_SOLID, UiPalette.TEAL, 18.0, 32.0, 24.0))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	UiBuilder.label(header, "TURRET DETAILS", 30, UiPalette.INK, false, true)
	close_button = IconButton.new().setup("back", "CLOSE")
	close_button.custom_minimum_size.x = 200
	close_button.pressed.connect(close)
	header.add_child(close_button)
	inspector = TurretInspector.new()
	inspector.world = world
	inspector.size_flags_vertical = SIZE_EXPAND_FILL
	inspector.navigation_exit = close_button
	column.add_child(inspector)

func open(turret_id: int) -> void:
	visible = true
	inspector.refresh()
	if turret_id != 0:
		inspector.select(turret_id)
	var roster := inspector.visible_buttons()
	# The shop stays behind the modal; every move from Close stays inside it.
	close_button.focus_neighbor_left = close_button.get_path_to(roster[0] if not roster.is_empty() else close_button)
	close_button.focus_neighbor_bottom = close_button.focus_neighbor_left
	close_button.focus_neighbor_top = close_button.get_path_to(close_button)
	close_button.focus_neighbor_right = close_button.get_path_to(close_button)
	for button in roster:
		if button.button_pressed:
			button.grab_focus()
			return
	close_button.grab_focus()

func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()
