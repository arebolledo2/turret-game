class_name FloorShowcase
extends CanvasLayer

## Main-menu gallery: every arena floor theme on a slowly turning patch of the real floor material, with a turret for scale.
## Entries come from `WorldGeometry.FLOOR_THEMES`, so a new theme appears without edits here.

signal closed

const SPIN_SPEED := 0.12
const DRAG_SPEED := 0.005
const PATCH_METRES := 40.0

var themes: Array[String] = []
var list: ItemList
var viewport: SubViewport
var viewport_container: SubViewportContainer
var title_label: Label
var kind_label: Label
var description_label: Label
var back_button: Button
var stage: Node3D
var pivot: Node3D
var floor_visual: MeshInstance3D
var camera: Camera3D
var turret: TurretActor
var selected := -1
var dragging := false

func _ready() -> void:
	layer = 2
	for theme in WorldGeometry.FLOOR_THEMES:
		themes.append(theme)
	_build_ui()
	_build_stage()
	list.select(0)
	show_theme(0)

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("08151e")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 32)
	margin.add_child(row)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 420
	left.add_theme_constant_override("separation", 14)
	row.add_child(left)
	var heading := UiBuilder.label(left, "FLOORS", 48, UiPalette.INK)
	heading.theme_type_variation = &"Header1"
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_theme_font_size_override("font_size", 24)
	list.accessibility_name = "Floor list"
	for theme in themes:
		list.add_item(FloorThemes.display_name(theme))
	list.item_selected.connect(show_theme)
	left.add_child(list)
	back_button = IconButton.new().setup("back", "BACK", false, 30)
	back_button.custom_minimum_size.y = 62
	back_button.pressed.connect(close)
	left.add_child(back_button)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 14)
	row.add_child(right)
	viewport_container = SubViewportContainer.new()
	viewport_container.stretch = true
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.gui_input.connect(_on_view_input)
	right.add_child(viewport_container)
	kind_label = UiBuilder.label(right, "", 22, UiPalette.TEAL_HI)
	title_label = UiBuilder.label(right, "", 54, UiPalette.INK)
	title_label.theme_type_variation = &"Header1"
	description_label = UiBuilder.label(right, "", 24, UiPalette.MUTED, true, true)
	description_label.custom_minimum_size.y = 96

func _build_stage() -> void:
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport_container.add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("08151e")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("a9d6dd")
	settings.ambient_light_energy = .55
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.glow_enabled = true
	environment.environment = settings
	stage.add_child(environment)
	# A warm key from the front-left, plus the cool counter light the arena uses, so the relief and seam lights read.
	for spec: Array in [[Vector3(-52, -35, 0), 1.5, Color("ffe4b0")], [Vector3(-25, 140, 0), .9, Color("75dacc")]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = spec[0]
		light.light_energy = spec[1]
		light.light_color = spec[2]
		stage.add_child(light)
	pivot = Node3D.new()
	stage.add_child(pivot)
	var plane := PlaneMesh.new()
	plane.size = Vector2(PATCH_METRES, PATCH_METRES)
	floor_visual = MeshInstance3D.new()
	floor_visual.mesh = plane
	pivot.add_child(floor_visual)
	turret = TurretActor.new()
	turret.turret_type = "plasma"
	turret.process_mode = Node.PROCESS_MODE_DISABLED
	stage.add_child(turret)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 9.0
	camera.position = Vector3(0, 14, 10)
	stage.add_child(camera)
	camera.look_at(Vector3(0, 0, -0.5))
	camera.current = true

## Shows theme `index` on the turning patch.
func show_theme(index: int) -> void:
	if index < 0 or index >= themes.size():
		return
	selected = index
	var theme := themes[index]
	floor_visual.material_override = WorldGeometry.floor_material(Vector2(PATCH_METRES, PATCH_METRES), theme, false)
	var layout := FloorThemes.layout_name(theme)
	kind_label.text = "ARENA  /  %s" % layout.to_upper() if layout != "" else "FLOOR THEME"
	title_label.text = FloorThemes.display_name(theme).to_upper()
	description_label.text = FloorThemes.note(theme)

func _process(delta: float) -> void:
	if not dragging and is_instance_valid(pivot):
		pivot.rotation.y += SPIN_SPEED * delta

func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
	elif event is InputEventMouseMotion and dragging:
		pivot.rotation.y += event.relative.x * DRAG_SPEED

func open() -> void:
	visible = true
	set_process(true)
	list.grab_focus()

func close() -> void:
	visible = false
	set_process(false)
	closed.emit()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	var back: bool = event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)
	if back:
		close()
		get_viewport().set_input_as_handled()
