class_name EvolutionPreview
extends ConfirmationDialog

signal accepted(turret: TurretActor, form_id: String)

var candidate: TurretActor
var form_id: String
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
	note.text = "Free evolution. Keeps XP, position and entrenchment.\nLevel 5 grants an upgrade; at level 10 you choose a final form."
	note.add_theme_font_size_override("font_size", 20)
	column.add_child(note)
	confirmed.connect(_confirm)

func show_form(turret: TurretActor, form: String) -> void:
	if not form in turret.available_evolutions():
		return
	candidate = turret
	form_id = form
	title = "%s → %s" % [turret.display_name(), TurretEvolution.form_name(form)]
	heading.text = TurretEvolution.form_name(form)
	portrait.texture = ShopArt.turret(turret.turret_type, form)
	description.text = TurretEvolution.description(form)
	var before := turret.resolve_attack_view()
	var after := turret.resolve_attack_view(false, form)
	var lines := PackedStringArray()
	var utility := TurretRegistry.is_no_attack(turret.turret_type)
	if utility:
		lines.append("Drop every   %.1f → %.1f s     Lands within   %.2f → %.2f m" % [before.cooldown_seconds, after.cooldown_seconds, before.range_metres, after.range_metres])
		lines.append(TurretEvolution.scrap_press_pattern_text(form))
	else:
		lines.append("Damage per hit   %.1f → %.1f" % [before.damage, after.damage])
		if turret.turret_type == "melee":
			lines.append("Sweep speed   %.0f → %.0f°/s" % [before.rotation_rate, after.rotation_rate])
		else:
			lines.append("Base firing rate   %.2f → %.2f/s" % [before.fire_rate, after.fire_rate])
		var area := TurretRegistry.get_fire_mode(turret.turret_type) in [TurretRegistry.FIRE_PULSE, TurretRegistry.FIRE_FLAME]
		lines.append("Reach   %.2f → %.2f m" % [before.range_metres * (before.area_size if area else 1.0), after.range_metres * (after.area_size if area else 1.0)])
	if turret.turret_type == "sniper":
		lines.append("Pierce   %s → %s" % [TurretEvolution.pierce_text(before.pierce), TurretEvolution.pierce_text(after.pierce)])
	if turret.turret_type == "quake":
		lines.append("Knockback   %.2f → %.2f m     Stagger   %.1f s" % [before.knockback_metres, after.knockback_metres, after.stagger_seconds])
		lines.append(TurretEvolution.quake_pattern_text(form))
	if turret.turret_type == "decoy":
		lines.append("Taunt radius   %.2f → %.2f m     Knockback   %.2f → %.2f m" % [before.taunt_metres, after.taunt_metres, before.knockback_metres, after.knockback_metres])
		lines.append(TurretEvolution.decoy_pattern_text(form))
	if after.aoe_radius_metres > 0:
		lines.append("Blast radius   %.2f → %.2f m" % [before.aoe_radius_metres, after.aoe_radius_metres])
	if form == "stormblade":
		var gun := turret.resolve_attack_view(true, form)
		lines.append("Gun: %.1f damage · %.2f m · %d shot(s) per burst" % [gun.damage, gun.range_metres, TurretEvolution.barrel_burst(form)])
	comparison.text = "\n".join(lines)
	reset_size()
	popup_centered(Vector2i(760, 620))
	get_ok_button().grab_focus.call_deferred()

func _confirm() -> void:
	if is_instance_valid(candidate):
		accepted.emit(candidate, form_id)

func _input(event: InputEvent) -> void:
	if visible and event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
		get_viewport().set_input_as_handled()
		hide()
		canceled.emit()
