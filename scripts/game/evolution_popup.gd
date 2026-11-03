class_name EvolutionPopup
extends CanvasLayer

## Shown right after a wave's recap, before the shop: every turret (and the hero) that reached a milestone picks its
## evolution here, one at a time, and the pick is required. A turret or hero owed both the level-5 and level-10 evolution is
## shown twice in a row. Cards are built once per step, never rebuilt per frame.
signal finished

var world: ArenaWorld
var active: bool = false
## TurretActor entries, and `null` for the hero.
var queue: Array = []
var root: Control
var buttons: Array[Button] = []
var was_paused: bool = false

## Starts the popup if anything is ready; returns whether it did.
func begin() -> bool:
	cancel()
	if not world.session.state.turret_progression_enabled:
		return false
	if not _options(null).is_empty():
		queue.append(null)
	for turret in world.turrets:
		if not turret.available_evolutions().is_empty():
			queue.append(turret)
	if queue.is_empty():
		return false
	active = true
	layer = 8
	_show_step()
	return true

func _options(entry: Variant) -> Array[String]:
	if entry == null:
		return PlayerStatsService.state.hero_progression.evolution_options()
	if is_instance_valid(entry):
		return (entry as TurretActor).available_evolutions()
	return []

func _show_step() -> void:
	_clear_ui()
	while not queue.is_empty() and _options(queue[0]).is_empty():
		queue.pop_front()
	if queue.is_empty():
		complete()
		return
	var entry: Variant = queue[0]
	var options := _options(entry)
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, .6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(centre)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ChamferStyle.make(UiPalette.PANEL, UiPalette.TEAL, 12, 24, 18))
	centre.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var heading := _label(column, _heading(entry), 32)
	heading.modulate = UiPalette.TEAL_HI
	_label(column, "Choose an evolution. Free; keeps XP and position.", 20)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	column.add_child(row)
	buttons.clear()
	for form_id in options:
		row.add_child(_card(entry, form_id))
	for i in buttons.size():
		buttons[i].focus_neighbor_left = buttons[maxi(i - 1, 0)].get_path()
		buttons[i].focus_neighbor_right = buttons[mini(i + 1, buttons.size() - 1)].get_path()
		buttons[i].focus_neighbor_top = buttons[i].get_path()
		buttons[i].focus_neighbor_bottom = buttons[i].get_path()
	buttons[0].grab_focus.call_deferred()

func _heading(entry: Variant) -> String:
	if entry == null:
		return "HERO · LEVEL %d" % PlayerStatsService.state.hero_progression.level
	var turret := entry as TurretActor
	return "%s · LEVEL %d" % [turret.display_name().to_upper(), turret.progression.level]

func _card(entry: Variant, form_id: String) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 420
	card.add_theme_stylebox_override("panel", ChamferStyle.make(UiPalette.PANEL_HI, UiPalette.LINE, 8, 16, 12))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)
	var turret := entry as TurretActor
	var title: String
	var description: String
	var comparison := ""
	if turret:
		title = TurretEvolution.form_name(form_id)
		description = TurretEvolution.description(form_id)
		comparison = EvolutionComparison.text(turret, form_id)
		var portrait := TextureRect.new()
		portrait.texture = ShopArt.turret(turret.turret_type, form_id)
		portrait.custom_minimum_size = Vector2(0, 190)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		column.add_child(portrait)
	else:
		var row := HeroForms.row(form_id)
		title = str(row.name)
		description = str(row.description)
	_label(column, title, 28).modulate = UiPalette.TEAL_HI
	_label(column, description, 20)
	if comparison != "":
		_label(column, comparison, 19)
	var button := Button.new()
	ChamferStyle.style_button(button)
	button.text = "EVOLVE"
	button.custom_minimum_size = Vector2(0, 52)
	button.pressed.connect(_pick.bind(entry, form_id))
	column.add_child(button)
	buttons.append(button)
	return card

func _pick(entry: Variant, form_id: String) -> void:
	if not active or world.paused:
		return
	var done := world.evolve_hero(form_id) if entry == null else (entry as TurretActor).evolve(form_id)
	if done:
		world.audio.play_cue("purchase", world.player.position)
	_show_step()

func _label(parent: Node, text: String, size: int) -> Label:
	var result := Label.new()
	result.text = text
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size", size)
	parent.add_child(result)
	return result

func _process(_delta: float) -> void:
	if not active:
		return
	if GameStateMachine.current_state != GameStateMachine.GameState.WAVE_END:
		cancel()
		return
	if is_instance_valid(root):
		root.visible = not world.paused
	if was_paused and not world.paused and not buttons.is_empty():
		buttons[0].grab_focus.call_deferred()
	was_paused = world.paused

func focus_choice() -> void:
	if not buttons.is_empty():
		buttons[0].grab_focus()

func complete() -> void:
	if not active:
		return
	cancel()
	finished.emit()

func _clear_ui() -> void:
	if is_instance_valid(root):
		root.visible = false
		root.queue_free()
	root = null
	buttons.clear()

func cancel() -> void:
	active = false
	queue.clear()
	_clear_ui()

func _exit_tree() -> void:
	cancel()
