class_name EvolutionPreview
extends ConfirmationDialog

signal accepted(turret: TurretActor, branch: String)

var candidate: TurretActor
var branch_id: String
var heading: Label
var portrait: TextureRect
var comparison: Label
var description: Label

func _ready() -> void:
	title = "Turret evolution"
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("0b2530")
	panel.border_color = Color("48dcd4")
	panel.set_border_width_all(2)
	panel.content_margin_left = 24
	panel.content_margin_right = 24
	panel.content_margin_top = 18
	panel.content_margin_bottom = 18
	add_theme_stylebox_override("panel", panel)
	for button in [get_ok_button(), get_cancel_button()]:
		button.custom_minimum_size = Vector2(160, 48)
		button.add_theme_font_size_override("font_size", 24)
	get_ok_button().text = "EVOLVE"
	get_cancel_button().text = "BACK"
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.custom_minimum_size = Vector2(640, 0)
	add_child(column)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", Color("48dcd4"))
	column.add_child(heading)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(0, 210)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(portrait)
	description = Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size.x = 640
	description.add_theme_font_size_override("font_size", 23)
	column.add_child(description)
	comparison = Label.new()
	comparison.add_theme_font_size_override("font_size", 23)
	column.add_child(comparison)
	var note := Label.new()
	note.text = "Free evolution. Keeps XP, position and entrenchment.\nYour chosen branch determines later forms."
	note.add_theme_font_size_override("font_size", 20)
	column.add_child(note)
	confirmed.connect(_confirm)

func show_form(turret: TurretActor, branch: String) -> void:
	if not branch in turret.available_evolutions():
		return
	candidate = turret
	branch_id = branch
	var stage := turret.progression.evolution_stage + 1
	title = "%s → %s" % [turret.display_name(), TurretEvolution.form_name(turret.turret_type, branch, stage)]
	heading.text = TurretEvolution.form_name(turret.turret_type, branch, stage)
	portrait.texture = ShopArt.turret(turret.turret_type, branch, stage)
	description.text = TurretEvolution.description(branch, stage)
	var before := TurretStats.new(turret.resolve_attack_stats())
	var after := TurretStats.new(turret.resolve_attack_stats(false, branch, stage))
	var lines := PackedStringArray()
	lines.append("Damage per hit   %.1f → %.1f" % [before.damage, after.damage])
	if turret.turret_type == "melee":
		lines.append("Sweep speed   %.0f → %.0f°/s" % [before.rotation_rate, after.rotation_rate])
	else:
		lines.append("Base firing rate   %.2f → %.2f/s" % [before.fire_rate, after.fire_rate])
	var area := turret.turret_type in ["shock", "flamethrower"]
	lines.append("Reach   %.2f → %.2f m" % [before.range_metres * (before.area_size if area else 1.0), after.range_metres * (after.area_size if area else 1.0)])
	if after.aoe_radius_metres > 0:
		lines.append("Blast radius   %.2f → %.2f m" % [before.aoe_radius_metres, after.aoe_radius_metres])
	if branch == "gunblade":
		var gun := TurretStats.new(turret.resolve_attack_stats(true, branch, stage))
		lines.append("Gun: %.1f damage · %.2f m · %d shot(s) per burst" % [gun.damage, gun.range_metres, stage])
	comparison.text = "\n".join(lines)
	reset_size()
	popup_centered(Vector2i(760, 620))
	get_ok_button().grab_focus.call_deferred()

func _confirm() -> void:
	if is_instance_valid(candidate):
		accepted.emit(candidate, branch_id)

func _input(event: InputEvent) -> void:
	if visible and event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
		get_viewport().set_input_as_handled()
		hide()
		canceled.emit()
