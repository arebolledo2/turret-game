class_name TurretShowcase
extends CanvasLayer

## Main-menu gallery: every stocked base turret and every implemented form on a turntable.
## Entries are derived from the shop catalog and the form table, so new turrets appear without edits here.

signal closed

const SPIN_SPEED := 0.6
const DRAG_SPEED := 0.01

var entries: Array[Dictionary] = []
var list: ItemList
var viewport: SubViewport
var viewport_container: SubViewportContainer
var title_label: Label
var kind_label: Label
var description_label: Label
var back_button: Button
var stage: Node3D
var pivot: Node3D
var camera: Camera3D
var actor: TurretActor
var fire: TurretShowcaseFire
var selected := -1
var dragging := false

func _ready() -> void:
	layer = 2
	entries = build_entries()
	_build_ui()
	_build_stage()
	if not entries.is_empty():
		list.select(0)
		show_entry(0)

## One row per stocked base turret, followed by its implemented upgrade and finals.
static func build_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for base: String in ShopCatalog.ids("turret"):
		result.append({"base": base, "form": "", "stage": 0, "name": str(TurretRegistry.TYPES[base]["name"]), "description": str(TurretRegistry.TYPES[base]["description"]), "kind": "BASE"})
		for form_stage in 2:
			for form: String in TurretEvolution.options(base, form_stage):
				if TurretEvolution.is_implemented(form):
					result.append({"base": base, "form": form, "stage": form_stage + 1, "name": TurretEvolution.form_name(form), "description": TurretEvolution.description(form), "kind": "UPGRADE" if form_stage == 0 else "FINAL"})
	return result

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
	var heading := UiBuilder.label(left, "TURRETS", 48, UiPalette.INK)
	heading.theme_type_variation = &"Header1"
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_theme_font_size_override("font_size", 24)
	list.accessibility_name = "Turret list"
	for entry in entries:
		var indent := "" if entry["kind"] == "BASE" else "      "
		list.add_item(indent + str(entry["name"]))
	list.item_selected.connect(show_entry)
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
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport_container.add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0, 0, 0, 0)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("a9d6dd")
	settings.ambient_light_energy = .75
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	stage.add_child(environment)
	for spec: Array in [[Vector3(-40, -30, 0), 1.6, Color("ffe4b0")], [Vector3(-20, 140, 0), 1.0, Color("75dacc")]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = spec[0]
		light.light_energy = spec[1]
		light.light_color = spec[2]
		stage.add_child(light)
	pivot = Node3D.new()
	stage.add_child(pivot)
	fire = TurretShowcaseFire.new()
	stage.add_child(fire)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	stage.add_child(camera)

## Replaces the model on the turntable with entry `index`.
func show_entry(index: int) -> void:
	if index < 0 or index >= entries.size():
		return
	selected = index
	var entry := entries[index]
	_clear_actor()
	actor = TurretActor.new()
	actor.turret_type = entry["base"]
	actor.progression.evolution_form = entry["form"]
	actor.progression.evolution_stage = entry["stage"]
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	pivot.rotation = Vector3.ZERO
	pivot.add_child(actor)
	var bounds := model_bounds()
	var center := bounds.get_center()
	# Spin around the vertical axis through the model's centre.
	actor.position = Vector3(-center.x, 0, -center.z)
	bounds.position -= Vector3(center.x, 0, center.z)
	fire.setup(actor, bounds)
	camera.size = maxf(bounds.size.length() * 1.15, .5)
	var target := Vector3(0, center.y, 0)
	camera.position = target + Vector3(-2, 1.7, -2.6).normalized() * 6.0
	camera.look_at(target)
	camera.current = true
	title_label.text = str(entry["name"]).to_upper()
	kind_label.text = "%s  /  %s" % [str(TurretRegistry.TYPES[entry["base"]]["name"]).to_upper(), entry["kind"]] if entry["kind"] != "BASE" else "BASE TURRET"
	description_label.text = str(entry["description"])

## Combined box of the current model's meshes in the actor's parent space.
func model_bounds() -> AABB:
	var bounds := AABB()
	var first := true
	if actor == null or actor.model == null:
		return AABB(Vector3(-.5, 0, -.5), Vector3.ONE)
	for mesh: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if first:
		return AABB(Vector3(-.5, 0, -.5), Vector3.ONE)
	return bounds

func _clear_actor() -> void:
	if is_instance_valid(fire):
		fire.clear()
	if is_instance_valid(actor):
		pivot.remove_child(actor)
		actor.free()
	actor = null

func _process(delta: float) -> void:
	if not dragging and is_instance_valid(pivot):
		pivot.rotation.y += SPIN_SPEED * delta
	if is_instance_valid(fire):
		fire.advance(delta)

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

func _exit_tree() -> void:
	_clear_actor()
