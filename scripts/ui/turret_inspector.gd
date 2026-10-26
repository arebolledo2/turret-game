class_name TurretInspector
extends HBoxContainer

## Individual turret inspection. Reads the actor's resolved stats, including its own growth.
var world: ArenaWorld
var selected_id: int = 0
var roster: VBoxContainer
var buttons: Array[Button] = []
var roster_bars: Array[TurretXpBar] = []
var shown_ids: Array[int] = []
var art: TextureRect
var title: Label
var family_badges: AttackFamilyBadges
var xp_label: Label
var xp_bar: TurretXpBar
var detail: RichTextLabel
var detail_key: int = 0
var evolution_choices: VBoxContainer
const PAGE_SIZE := 6
var page := 0
var page_label: Label
var previous_page: Button
var next_page: Button
var roster_art: Array[TextureRect] = []
var stat_values: Array[Label] = []
var milestones: Label
var navigation_exit: Control
var evolution_preview: EvolutionPreview

func _ready() -> void:
	evolution_preview = EvolutionPreview.new()
	add_child(evolution_preview)
	evolution_preview.accepted.connect(_evolve_selected)
	evolution_preview.canceled.connect(_restore_roster_focus)
	add_theme_constant_override("separation", 40)
	var squad := VBoxContainer.new()
	squad.custom_minimum_size.x = 340
	squad.add_theme_constant_override("separation", 10)
	add_child(squad)
	var pager := HBoxContainer.new()
	squad.add_child(pager)
	previous_page = Button.new()
	previous_page.text = "‹"
	previous_page.custom_minimum_size = Vector2(48, 36)
	previous_page.pressed.connect(change_page.bind(-1))
	pager.add_child(previous_page)
	page_label = Label.new()
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_label.size_flags_horizontal = SIZE_EXPAND_FILL
	pager.add_child(page_label)
	next_page = Button.new()
	next_page.text = "›"
	next_page.custom_minimum_size = Vector2(48, 36)
	next_page.pressed.connect(change_page.bind(1))
	pager.add_child(next_page)
	roster = VBoxContainer.new()
	roster.add_theme_constant_override("separation", 8)
	squad.add_child(roster)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 28)
	column.add_child(header)
	art = TextureRect.new()
	art.custom_minimum_size = Vector2(460, 280)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(art)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = SIZE_EXPAND_FILL
	identity.size_flags_vertical = SIZE_SHRINK_CENTER
	identity.add_theme_constant_override("separation", 14)
	header.add_child(identity)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 34)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity.add_child(title)
	family_badges = AttackFamilyBadges.new()
	identity.add_child(family_badges)
	xp_label = Label.new()
	xp_label.add_theme_font_size_override("font_size", 22)
	identity.add_child(xp_label)
	xp_bar = TurretXpBar.new()
	xp_bar.custom_minimum_size.y = 20
	identity.add_child(xp_bar)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	column.add_child(grid)
	for label_text in ["DAMAGE", "REACH", "FIRE RATE", "AREA / CHAIN", "PIERCE", "ENTRENCH"]:
		var tile := PanelContainer.new()
		tile.size_flags_horizontal = SIZE_EXPAND_FILL
		tile.custom_minimum_size.y = 78
		tile.add_theme_stylebox_override("panel", ChamferStyle.make(UiPalette.PANEL_SOLID, Color("28505b"), 8, 14, 8))
		grid.add_child(tile)
		var stack := VBoxContainer.new()
		tile.add_child(stack)
		var caption := Label.new()
		caption.text = label_text
		caption.add_theme_font_size_override("font_size", 20)
		caption.modulate = UiPalette.MUTED
		stack.add_child(caption)
		var value := Label.new()
		value.add_theme_font_size_override("font_size", 36)
		value.modulate = UiPalette.TEAL_HI
		stack.add_child(value)
		stat_values.append(value)
	milestones = Label.new()
	milestones.add_theme_font_size_override("font_size", 22)
	column.add_child(milestones)
	# Detailed resolved data remains available as a tooltip, without a scrolling text wall.
	detail = RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.hide()
	column.add_child(detail)
	evolution_choices = VBoxContainer.new()
	evolution_choices.add_theme_constant_override("separation", 8)
	column.add_child(evolution_choices)

func refresh() -> void:
	page = clampi(page, 0, maxi(0, (world.turrets.size() - 1) / PAGE_SIZE))
	var ids: Array[int] = []
	for turret in world.turrets:
		ids.append(turret.turret_id)
	if ids != shown_ids:
		for button in buttons:
			roster.remove_child(button)
			button.queue_free()
		buttons.clear()
		roster_bars.clear()
		roster_art.clear()
		shown_ids = ids
		for turret in world.turrets:
			var button := Button.new()
			button.custom_minimum_size = Vector2(340, 80)
			button.add_theme_font_size_override("font_size", 22)
			button.toggle_mode = true
			button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
			var id := turret.turret_id
			button.pressed.connect(select.bind(id))
			button.focus_entered.connect(select.bind(id))
			roster.add_child(button)
			buttons.append(button)
			var thumbnail := TextureRect.new()
			thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
			thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			thumbnail.position = Vector2(6, 3)
			thumbnail.size = Vector2(110,  70)
			button.add_child(thumbnail)
			roster_art.append(thumbnail)
			var bar := TurretXpBar.new()
			bar.custom_minimum_size.y = 9
			button.add_child(bar)
			bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			bar.offset_left = 16
			bar.offset_right = -16
			bar.offset_top = -14
			bar.offset_bottom = -5
			roster_bars.append(bar)
	if selected_id not in ids:
		selected_id = ids[0] if not ids.is_empty() else 0
	for i in world.turrets.size():
		var turret := world.turrets[i]
		buttons[i].text = "%s #%d   ·   Lv %d\n" % [turret.display_name(),
			turret.turret_id, turret.progression.level]
		if not turret.available_evolutions().is_empty():
			buttons[i].text += "EVOLUTION READY"
		buttons[i].custom_minimum_size.y = 86
		buttons[i].visible = i / PAGE_SIZE == page
		roster_art[i].texture = ShopArt.turret(turret.turret_type, turret.progression.evolution_form)
		roster_bars[i].show_progress(turret.progression.level, turret.progression.xp)
		buttons[i].set_pressed_no_signal(turret.turret_id == selected_id)
	page_label.text = "SQUAD  %d / %d" % [page + 1, maxi(1, ceili(float(ids.size()) / PAGE_SIZE))]
	previous_page.disabled = page == 0
	next_page.disabled = (page + 1) * PAGE_SIZE >= ids.size()
	_show_selected()
	refresh_navigation()

func select(id: int) -> void:
	for i in world.turrets.size():
		if world.turrets[i].turret_id == id: page = i / PAGE_SIZE
	selected_id = id
	detail_key = 0
	refresh()

func _show_selected() -> void:
	var turret: TurretActor
	for candidate in world.turrets:
		if candidate.turret_id == selected_id:
			turret = candidate
			break
	if not turret:
		title.text = "No turrets deployed"
		family_badges.show_turret("")
		art.texture = null
		xp_label.text = "Buy a turret in Offers to start your squad."
		detail.text = ""
		xp_bar.value = 0
		return
	var growth := turret.progression
	var stats := turret._current_view(0.0)
	var ledger := world.salvage.last_settlement
	var key := [selected_id, growth.snapshot(), stats.values, turret.gun_stats.values, ledger.get("wave", -1)].hash()
	if key == detail_key:
		return
	detail_key = key
	art.texture = ShopArt.turret(turret.turret_type, growth.evolution_form)
	if growth.evolution_form == "stormblade":
		family_badges.show_families(["kinetic", "projectile"])
	else:
		family_badges.show_turret(turret.turret_type)
	title.text = "%s #%d\nLEVEL %d" % [turret.display_name(), selected_id, growth.level]
	xp_label.text = "%d / %d XP   →   LV %d" % [growth.xp, TurretProgression.cost_to_next(growth.level), growth.level + 1]
	xp_bar.show_progress(growth.level, growth.xp)
	stat_values[0].text = "%.1f" % stats.damage
	stat_values[1].text = "%.2f m" % (stats.range_metres * (stats.area_size if TurretRegistry.get_fire_mode(turret.turret_type) in [TurretRegistry.FIRE_PULSE, TurretRegistry.FIRE_FLAME] else 1.0))
	stat_values[2].text = "%.0f°/s" % stats.rotation_rate if turret.turret_type == "melee" else "%.2f /s" % stats.fire_rate
	stat_values[3].text = "%d jumps" % stats.chain_count if stats.chain_count > 0 else "%.2f m" % stats.aoe_radius_metres if stats.aoe_radius_metres > 0 else "—"
	stat_values[4].text = TurretEvolution.pierce_text(stats.pierce) if stats.pierce > 0 else "—"
	stat_values[5].text = "%d stacks" % turret.entrench_stacks_cached
	var steps := PackedStringArray()
	for milestone in TurretProgression.EVOLUTION_LEVELS:
		steps.append("%s LV %d" % ["◆" if growth.level >= milestone else "◇", milestone])
	milestones.text = "EVOLUTION    " + "     ──     ".join(steps)
	milestones.modulate = UiPalette.TEAL_HI
	var lines := PackedStringArray()
	lines.append("[color=#8be0c9][b]CURRENT COMBAT STATS[/b][/color]")
	lines.append("Damage  [b]%.1f[/b]     Reach  [b]%.2f m[/b]" % [stats.damage, stats.range_metres * (stats.area_size if TurretRegistry.get_fire_mode(turret.turret_type) in [TurretRegistry.FIRE_PULSE, TurretRegistry.FIRE_FLAME] else 1.0)])
	if turret.turret_type == "melee":
		lines.append("Sweep  %.0f°/s     Rehit interval  %.2f s" % [stats.rotation_rate, stats.rehit_delay])
	else:
		lines.append("Rate  %.2f shots/s     Cooldown  %.2f s" % [stats.fire_rate, stats.cooldown_seconds])
	if stats.projectile_speed_metres > 0:
		lines.append("Projectile speed  %.2f m/s     Pierce  %d" % [stats.projectile_speed_metres, stats.pierce])
	if turret.turret_type == "sniper":
		lines.append("Instant hit on the toughest enemy in range     Pierce  %s" % TurretEvolution.pierce_text(stats.pierce))
		if growth.evolution_form == "overwatch":
			lines.append("Marks the %d toughest enemies for %.0f s: +%.0f%% damage from every turret" % [TurretEvolution.OVERWATCH_MARK_COUNT, TurretEvolution.OVERWATCH_MARK_SECONDS, StatusEffects3D.MARKED_BONUS * 100.0])
	if turret.turret_type == "quake":
		lines.append("Stagger  %.1f s     %s" % [stats.stagger_seconds, TurretEvolution.quake_pattern_text(growth.evolution_form)])
	if stats.aoe_radius_metres > 0:
		lines.append("Blast radius  %.2f m" % stats.aoe_radius_metres)
	if stats.chain_count > 0:
		lines.append("Chain jumps  %d     Chain reach  %.2f m" % [stats.chain_count, stats.chain_range_metres])
	if stats.slow_intensity > 0:
		lines.append("Slow  %.0f%% for %.2f s" % [stats.slow_intensity * 100, stats.slow_duration])
	if turret.turret_type == "flamethrower":
		lines.append("Flame cone %.0f degrees" % float(stats.values.get("cone_degrees", 36.0)))
		lines.append("Burn %.1f damage/s for %.1f s" % [stats.damage * float(stats.values.get("burn_ratio", 1.6)), float(stats.values.get("burn_duration", 2.0))])
	lines.append("Knockback  %.2f m" % stats.knockback_metres)
	if growth.evolution_form == "stormblade":
		var gun := turret.gun_stats
		lines.append("\n[b]GUN · PROJECTILE[/b]")
		var shots := TurretEvolution.barrel_burst(growth.evolution_form)
		lines.append("Damage %.1f · Reach %.2f m · %.2f bursts/s · %d shots/burst" % [gun.damage, gun.range_metres, gun.fire_rate, shots])
		lines.append("Fires along the rotating barrel. Kinetic bonuses affect the blade only.")
	lines.append("\n[b]PROGRESSION & POSITION[/b]")
	lines.append("XP  %d / %d to next level  ·  %d total earned" % [growth.xp, TurretProgression.cost_to_next(growth.level), growth.total_xp])
	var bonuses := growth.stat_multipliers()
	lines.append("Level bonuses: Damage +%.0f%% · Attack speed +%.0f%% · Range +%.0f%%" % [(bonuses.damage - 1.0) * 100, (bonuses.speed - 1.0) * 100, (bonuses.range - 1.0) * 100])
	lines.append("Entrenchment  %d stacks" % turret.entrench_stacks_cached)
	lines.append("Stats include current items, difficulty and this turret’s active bonuses.")
	if not world.session.state.turret_progression_enabled:
		lines.append("Turret progression is off for this run.")
	var change: Dictionary = ledger.get("changes", {}).get(selected_id, {})
	if not change.is_empty():
		lines.append("\n[b]LAST SALVAGE · WAVE %d[/b]\n+%d XP  ·  Level %d → %d" % [ledger["wave"], change["xp_awarded"], change["before"]["level"], change["after"]["level"]])
	lines.append("\n[b]EVOLUTION MILESTONES[/b]")
	for i in TurretProgression.EVOLUTION_LEVELS.size():
		var milestone: int = TurretProgression.EVOLUTION_LEVELS[i]
		var state := "Not reached"
		if growth.evolution_stage > i:
			# Milestone 0 is the upgrade (still named once a final replaced it); milestone 1 is the chosen final.
			var taken := growth.evolution_form
			if i == 0 and growth.evolution_stage > 1:
				taken = TurretEvolution.options(turret.turret_type, 0)[0]
			state = TurretEvolution.form_name(taken)
		elif growth.level >= milestone:
			state = "Evolution ready" if not turret.available_evolutions().is_empty() else "Form in development — milestone retained"
		lines.append("Level %d  ·  %s" % [milestone, state])
	lines.append("Ordinary stat levels continue beyond level 10.")
	for child in evolution_choices.get_children():
		evolution_choices.remove_child(child)
		child.queue_free()
	for form_id in turret.available_evolutions():
		var button := Button.new()
		button.custom_minimum_size.y = 48
		button.text = "EVOLVE · %s" % TurretEvolution.form_name(form_id)
		button.tooltip_text = TurretEvolution.description(form_id)
		button.pressed.connect(evolution_preview.show_form.bind(turret, form_id))
		evolution_choices.add_child(button)
	detail.text = "\n".join(lines)
	art.tooltip_text = detail.get_parsed_text()

## The selected roster entry owns the path into its current choices. Rebuild on
## selection as well as shop refresh, so removed evolution buttons never retain focus links.
func refresh_navigation() -> void:
	if not is_instance_valid(navigation_exit):
		return
	var selected_button: Button
	for button in buttons:
		button.focus_neighbor_right = button.get_path_to(navigation_exit)
		if button.button_pressed:
			selected_button = button
	if not selected_button:
		return
	var visible_roster := visible_buttons()
	for button in visible_roster:
		button.focus_neighbor_left = button.get_path_to(previous_page if not previous_page.disabled else next_page if not next_page.disabled else button)
	for pager in [previous_page, next_page]:
		pager.focus_neighbor_bottom = pager.get_path_to(visible_roster[0])
		pager.focus_neighbor_right = pager.get_path_to(next_page if pager == previous_page and not next_page.disabled else selected_button)
		pager.focus_neighbor_left = pager.get_path_to(previous_page if pager == next_page and not previous_page.disabled else selected_button)
	var choices := evolution_choices.get_children()
	if choices.is_empty():
		return
	selected_button.focus_neighbor_right = selected_button.get_path_to(choices[0])
	for i in choices.size():
		var button := choices[i] as Button
		button.focus_neighbor_left = button.get_path_to(selected_button)
		button.focus_neighbor_right = button.get_path_to(navigation_exit)
		button.focus_neighbor_top = button.get_path_to(choices[i - 1] if i > 0 else selected_button)
		button.focus_neighbor_bottom = button.get_path_to(choices[i + 1] if i + 1 < choices.size() else navigation_exit)

func visible_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for button in buttons:
		if button.visible: result.append(button)
	return result

func change_page(direction: int) -> void:
	page = clampi(page + direction, 0, maxi(0, (buttons.size() - 1) / PAGE_SIZE))
	if buttons.is_empty(): return
	select(world.turrets[page * PAGE_SIZE].turret_id)
	buttons[page * PAGE_SIZE].grab_focus()

func _evolve_selected(turret: TurretActor, form_id: String) -> void:
	if turret.evolve(form_id):
		detail_key = 0
		refresh()
		for button in buttons:
			if button.button_pressed:
				button.grab_focus()
				break

func _restore_roster_focus() -> void:
	for button in buttons:
		if button.button_pressed:
			button.grab_focus()
			return
