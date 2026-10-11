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
var details_scroll: ScrollContainer

func _ready() -> void:
	add_theme_constant_override("separation", 40)
	var roster_scroll := ScrollContainer.new()
	roster_scroll.custom_minimum_size.x = 360
	roster_scroll.follow_focus = true
	add_child(roster_scroll)
	roster = VBoxContainer.new()
	roster.size_flags_horizontal = SIZE_EXPAND_FILL
	roster.add_theme_constant_override("separation", 12)
	roster_scroll.add_child(roster)
	var scroll := ScrollContainer.new()
	details_scroll = scroll
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 18)
	scroll.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	art = TextureRect.new()
	art.custom_minimum_size = Vector2(260, 180)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(art)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 38)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(title)
	family_badges = AttackFamilyBadges.new()
	column.add_child(family_badges)
	xp_label = Label.new()
	xp_label.add_theme_font_size_override("font_size", 25)
	column.add_child(xp_label)
	xp_bar = TurretXpBar.new()
	xp_bar.custom_minimum_size.y = 34
	column.add_child(xp_bar)
	detail = RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.fit_content = true
	detail.scroll_active = false
	detail.add_theme_font_size_override("normal_font_size", 24)
	column.add_child(detail)
	evolution_choices = VBoxContainer.new()
	evolution_choices.add_theme_constant_override("separation", 12)
	column.add_child(evolution_choices)

func refresh() -> void:
	var ids: Array[int] = []
	for turret in world.turrets:
		ids.append(turret.turret_id)
	if ids != shown_ids:
		for button in buttons:
			roster.remove_child(button)
			button.queue_free()
		buttons.clear()
		roster_bars.clear()
		shown_ids = ids
		for turret in world.turrets:
			var button := Button.new()
			button.custom_minimum_size = Vector2(340, 90)
			button.add_theme_font_size_override("font_size", 24)
			button.toggle_mode = true
			var id := turret.turret_id
			button.pressed.connect(select.bind(id))
			button.focus_entered.connect(select.bind(id))
			roster.add_child(button)
			buttons.append(button)
			var bar := TurretXpBar.new()
			bar.custom_minimum_size.y = 18
			button.add_child(bar)
			bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			bar.offset_left = 16
			bar.offset_right = -16
			bar.offset_top = -28
			bar.offset_bottom = -10
			roster_bars.append(bar)
	if selected_id not in ids:
		selected_id = ids[0] if not ids.is_empty() else 0
	for i in world.turrets.size():
		var turret := world.turrets[i]
		buttons[i].text = "%s #%d   ·   Lv %d\n" % [turret.display_name(),
			turret.turret_id, turret.progression.level]
		roster_bars[i].show_progress(turret.progression.level, turret.progression.xp)
		buttons[i].set_pressed_no_signal(turret.turret_id == selected_id)
	_show_selected()

func select(id: int) -> void:
	if id != selected_id:
		details_scroll.scroll_vertical = 0
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
	art.texture = ShopArt.turret(turret.turret_type)
	if growth.evolution_branch == "gunblade":
		family_badges.show_families(["kinetic", "projectile"])
	else:
		family_badges.show_turret(turret.turret_type)
	title.text = "%s #%d\nLEVEL %d" % [turret.display_name(), selected_id, growth.level]
	xp_label.text = "LEVEL %d  →  LEVEL %d" % [growth.level, growth.level + 1]
	xp_bar.show_progress(growth.level, growth.xp)
	var lines := PackedStringArray()
	lines.append("[color=#8be0c9][b]CURRENT COMBAT STATS[/b][/color]")
	lines.append("Damage  [b]%.1f[/b]     Reach  [b]%.2f m[/b]" % [stats.damage, stats.range_metres * (stats.area_size if TurretRegistry.get_fire_mode(turret.turret_type) in [TurretRegistry.FIRE_PULSE, TurretRegistry.FIRE_FLAME] else 1.0)])
	if turret.turret_type == "melee":
		lines.append("Sweep  %.0f°/s     Rehit interval  %.2f s" % [stats.rotation_rate, stats.rehit_delay])
	else:
		lines.append("Rate  %.2f shots/s     Cooldown  %.2f s" % [stats.fire_rate, stats.cooldown_seconds])
	if stats.projectile_speed_metres > 0:
		lines.append("Projectile speed  %.2f m/s     Pierce  %d" % [stats.projectile_speed_metres, stats.pierce])
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
	if growth.evolution_branch == "gunblade":
		var gun := turret.gun_stats
		lines.append("\n[b]GUN · PROJECTILE[/b]")
		lines.append("Damage %.1f · Reach %.2f m · %.2f shots/s" % [gun.damage, gun.range_metres, gun.fire_rate])
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
			state = TurretEvolution.form_name(turret.turret_type, growth.evolution_branch, i + 1)
		elif growth.level >= milestone:
			state = "Evolution ready" if not turret.available_evolutions().is_empty() else "Form in development — milestone retained"
		lines.append("Level %d  ·  %s" % [milestone, state])
	lines.append("Ordinary stat levels continue beyond level 15.")
	for child in evolution_choices.get_children():
		evolution_choices.remove_child(child)
		child.queue_free()
	for branch in turret.available_evolutions():
		var button := Button.new()
		button.custom_minimum_size.y = 80
		button.text = "EVOLVE · %s\n%s" % [TurretEvolution.form_name(turret.turret_type, branch, growth.evolution_stage + 1), TurretEvolution.description(branch, growth.evolution_stage + 1)]
		button.pressed.connect(_evolve_selected.bind(turret, branch))
		evolution_choices.add_child(button)
		for roster_button in buttons:
			if roster_button.button_pressed:
				roster_button.focus_neighbor_right = roster_button.get_path_to(evolution_choices.get_child(0))
				button.focus_neighbor_left = button.get_path_to(roster_button)
	detail.text = "\n".join(lines)

func _process(delta: float) -> void:
	if not is_visible_in_tree() or not world.shop.is_open():
		return
	for device in Input.get_connected_joypads():
		var axis := Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)
		if absf(axis) > .25:
			details_scroll.scroll_vertical += roundi(axis * 650.0 * delta)

func _evolve_selected(turret: TurretActor, branch: String) -> void:
	if turret.evolve(branch):
		detail_key = 0
		refresh()
		for button in buttons:
			if button.button_pressed:
				button.grab_focus()
				break
